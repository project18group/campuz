import random
from datetime import timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import serializers

from .models import Hub, HubMember, Message, UserProfile


# ---------------------------------------------------------------------------
# OTP helper
# ---------------------------------------------------------------------------

OTP_EXPIRY_MINUTES = 5
OTP_RESEND_COOLDOWN_SECONDS = 60


def _generate_and_save_otp(profile: UserProfile) -> str:
    """Generate a 6-digit OTP, persist it with a timestamp, and return it."""
    otp = str(random.randint(100000, 999999))
    profile.otp_code = otp
    profile.otp_created_at = timezone.now()
    profile.save(update_fields=["otp_code", "otp_created_at"])
    return otp


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

    def validate_phone_number(self, value):
        value = value.strip()
        if not value.startswith("+"):
            raise serializers.ValidationError(
                "Phone number must be in E.164 format (e.g. +233201234567)."
            )
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
    Updates the public username (on Django User) and profile fields.

    `username` is the one-time public handle; it replaces the UUID that was
    assigned internally at account creation.  Uniqueness is enforced here
    and the field is write-only so it doesn't leak the internal User.username
    in any read response.
    """

    username = serializers.CharField(
        max_length=150,
        write_only=True,
        required=True,
    )

    class Meta:
        model = UserProfile
        fields = ["username", "display_name", "avatar_url"]

    def validate_username(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Username cannot be blank.")
        # Exclude the current user so they can call profile-setup without
        # hitting a false uniqueness collision on their own username.
        user = self.instance.user if self.instance else None
        qs = User.objects.filter(username=value)
        if user:
            qs = qs.exclude(pk=user.pk)
        if qs.exists():
            raise serializers.ValidationError("That username is already taken.")
        return value

    def update(self, instance, validated_data):
        username = validated_data.pop("username", None)
        if username:
            instance.user.username = username
            instance.user.save(update_fields=["username"])
        return super().update(instance, validated_data)


# ---------------------------------------------------------------------------
# Shared / read serializers (unchanged from original)
# ---------------------------------------------------------------------------

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ["avatar_url", "display_name", "phone_number", "is_verified"]


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


class HubSerializer(serializers.ModelSerializer):
    creator = UserSerializer(read_only=True)
    members = HubMemberSerializer(source="hub_members", many=True, read_only=True)
    members_count = serializers.SerializerMethodField()

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
            "created_at",
        ]
        read_only_fields = ["creator", "members"]

    def get_members_count(self, obj):
        return obj.hub_members.count()


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ["id", "hub", "sender", "content", "timestamp"]
        read_only_fields = ["sender"]
