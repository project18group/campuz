from django.db import transaction

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import serializers

from .models import (
    AdminInvitationCode,
    DirectConversation,
    DirectMessage,
    Hub,
    HubMember,
    HubSection,
    Message,
    UserProfile,
)


# ---------------------------------------------------------------------------
# OTP helpers
# ---------------------------------------------------------------------------

OTP_RESEND_COOLDOWN_SECONDS = 60


def _mark_otp_requested(profile: UserProfile) -> None:
    """Mark timestamp when OTP was requested for cooldown enforcement."""
    profile.otp_created_at = timezone.now()
    profile.save(update_fields=["otp_created_at"])


def _clear_otp(profile: UserProfile) -> None:
    """Wipe OTP fields after a successful verification."""
    profile.otp_code = None
    profile.otp_created_at = None
    profile.is_verified = True
    profile.save(update_fields=["otp_code", "otp_created_at", "is_verified"])


# ---------------------------------------------------------------------------
# Phone-auth serializers
# ---------------------------------------------------------------------------

class RequestOTPSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=20)
    full_name = serializers.CharField(max_length=150)

    def validate_phone_number(self, value):
        value = value.strip()
        if not value.startswith("+"):
            raise serializers.ValidationError(
                "Phone number must be in E.164 format (e.g. +233201234567)."
            )
        return value

    def validate_full_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Full name cannot be blank.")
        return value


class VerifyOTPSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=20)
    otp_code = serializers.CharField(min_length=6, max_length=6)

    def validate_phone_number(self, value):
        return value.strip()


# ---------------------------------------------------------------------------
# Profile setup — called once after first OTP sign-in
# ---------------------------------------------------------------------------

class ProfileSetupSerializer(serializers.ModelSerializer):
    """
    Stores display_name and optional avatar_url on UserProfile.
    Optionally redeems an AdminInvitationCode to grant can_create_hubs.
    """

    admin_code = serializers.CharField(
        max_length=50,
        required=False,
        allow_blank=True,
        write_only=True,
        help_text="Optional admin invitation code (e.g., KNUST-CS-2026)",
    )

    class Meta:
        model = UserProfile
        fields = ["display_name", "avatar_url", "admin_code"]

    def validate_display_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Display name cannot be blank.")
        return value

    def validate_admin_code(self, value):
        if not value or not value.strip():
            return None
        code = value.strip().upper()
        try:
            invite = AdminInvitationCode.objects.get(
                code=code,
                is_active=True,
                is_used=False,
            )
        except AdminInvitationCode.DoesNotExist:
            raise serializers.ValidationError(
                "This invitation code is invalid or has already been used."
            )
        if invite.expires_at and timezone.now() > invite.expires_at:
            raise serializers.ValidationError("This invitation code has expired.")
        return code

    @transaction.atomic
    def update(self, instance, validated_data):
        admin_code = validated_data.pop("admin_code", None)
        instance = super().update(instance, validated_data)
        if admin_code:
            invite = (
                AdminInvitationCode.objects.select_for_update()
                .filter(code=admin_code, is_active=True, is_used=False)
                .first()
            )
            if invite is None:
                raise serializers.ValidationError(
                    {"admin_code": "This invitation code is no longer available."}
                )
            if invite.expires_at and timezone.now() > invite.expires_at:
                raise serializers.ValidationError(
                    {"admin_code": "This invitation code has expired."}
                )
            invite.is_used = True
            invite.used_by = instance.user
            invite.used_at = timezone.now()
            invite.save(update_fields=["is_used", "used_by", "used_at"])
            instance.can_create_hubs = True
            instance.save(update_fields=["can_create_hubs"])
        return instance


# ---------------------------------------------------------------------------
# User listing / search
# ---------------------------------------------------------------------------

class CampuzUserSerializer(serializers.ModelSerializer):
    """
    Minimal read-only representation of a registered Campuz user for
    the contact-discovery and direct-conversation features.
    """

    display_name = serializers.CharField(source="profile.display_name", read_only=True)
    full_name = serializers.CharField(source="profile.full_name", read_only=True)
    phone_number = serializers.CharField(source="profile.phone_number", read_only=True)
    avatar_url = serializers.URLField(source="profile.avatar_url", read_only=True)
    is_verified = serializers.BooleanField(source="profile.is_verified", read_only=True)
    can_create_hubs = serializers.BooleanField(
        source="profile.can_create_hubs", read_only=True
    )

    class Meta:
        model = User
        fields = [
            "id",
            "full_name",
            "display_name",
            "phone_number",
            "avatar_url",
            "is_verified",
            "can_create_hubs",
        ]


# ---------------------------------------------------------------------------
# Direct conversations
# ---------------------------------------------------------------------------

class DirectMessageSerializer(serializers.ModelSerializer):
    sender_id = serializers.IntegerField(source="sender.id", read_only=True)
    sender_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = DirectMessage
        fields = [
            "id",
            "sender_id",
            "sender_name",
            "is_mine",
            "content",
            "timestamp",
            "is_read",
        ]
        read_only_fields = [
            "sender_id",
            "sender_name",
            "is_mine",
            "timestamp",
            "is_read",
        ]

    def get_sender_name(self, obj):
        return obj.sender.profile.display_name or obj.sender.profile.full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and obj.sender_id == request.user.id)


class DirectConversationSerializer(serializers.ModelSerializer):
    """
    Returns the conversation with the *other* participant's info from the
    requesting user's perspective. Attach `request` in the serializer context
    so `_other_user` works correctly.
    """

    other_user = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = DirectConversation
        fields = [
            "id",
            "other_user",
            "last_message",
            "unread_count",
            "created_at",
            "updated_at",
        ]

    def _other_user(self, obj):
        request = self.context.get("request")
        if request is None:
            return None
        me = request.user
        return obj.user_2 if obj.user_1_id == me.id else obj.user_1

    def get_other_user(self, obj):
        other = self._other_user(obj)
        if other is None:
            return None
        return CampuzUserSerializer(other).data

    def get_last_message(self, obj):
        msg = obj.messages.order_by("-timestamp").first()
        return DirectMessageSerializer(msg).data if msg else None

    def get_unread_count(self, obj):
        request = self.context.get("request")
        if request is None:
            return 0
        return obj.messages.filter(is_read=False).exclude(sender=request.user).count()


# ---------------------------------------------------------------------------
# Shared / read serializers (unchanged from original)
# ---------------------------------------------------------------------------

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            "full_name",
            "avatar_url",
            "display_name",
            "phone_number",
            "is_verified",
            "can_create_hubs",
        ]


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name", "profile"]


class HubMemberSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = HubMember
        fields = ["user", "role", "joined_at", "muted"]


class HubSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = HubSection
        fields = [
            "id",
            "section_type",
            "title",
            "description",
            "order",
            "is_enabled",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class HubSerializer(serializers.ModelSerializer):
    creator = UserSerializer(read_only=True)
    members = HubMemberSerializer(source="hub_members", many=True, read_only=True)
    members_count = serializers.SerializerMethodField()
    sections = HubSectionSerializer(many=True, read_only=True)

    class Meta:
        model = Hub
        fields = [
            "id",
            "name",
            "description",
            "cover_image_url",
            "creator",
            "members",
            "members_count",
            "sections",
            "created_at",
        ]
        read_only_fields = ["creator", "members", "sections"]

    def get_members_count(self, obj):
        return obj.hub_members.count()


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ["id", "hub", "sender", "content", "timestamp"]
        read_only_fields = ["sender"]
