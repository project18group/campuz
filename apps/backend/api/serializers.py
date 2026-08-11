import os
import uuid
from urllib.parse import quote_plus

from django.db import transaction

from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from .models import (
    AdminInvitationCode,
    DirectConversation,
    DirectMessageAttachment,
    DirectMessage,
    Broadcast,
    Hub,
    HubInvite,
    HubMeeting,
    HubMember,
    HubSection,
    Message,
    Resource,
    TaskItem,
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
    avatar_file = serializers.ImageField(required=False, write_only=True)
    remove_avatar = serializers.BooleanField(required=False, write_only=True, default=False)

    class Meta:
        model = UserProfile
        fields = ["display_name", "avatar_url", "avatar_file", "remove_avatar", "admin_code"]

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

    def _default_avatar_url(self, instance: UserProfile) -> str:
        seed = (
            instance.display_name
            or instance.full_name
            or instance.user.username
            or f"user-{instance.user_id}"
        ).strip()
        return (
            "https://api.dicebear.com/10.x/initials/svg"
            f"?seed={quote_plus(seed)}"
        )

    @transaction.atomic
    def update(self, instance, validated_data):
        admin_code = validated_data.pop("admin_code", None)
        avatar_file = validated_data.pop("avatar_file", None)
        remove_avatar = validated_data.pop("remove_avatar", False)

        instance = super().update(instance, validated_data)

        if remove_avatar:
            instance.avatar_url = self._default_avatar_url(instance)
            instance.save(update_fields=["avatar_url"])

        if avatar_file is not None:
            ext = os.path.splitext(getattr(avatar_file, "name", "") or "")[1].lower()
            if ext not in {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".heic", ".heif"}:
                ext = ".png"
            filename = f"avatars/{instance.user_id}-{uuid.uuid4().hex}{ext}"
            saved_path = default_storage.save(filename, ContentFile(avatar_file.read()))
            avatar_url = default_storage.url(saved_path)
            request = self.context.get("request")
            if request is not None:
                avatar_url = request.build_absolute_uri(avatar_url)
            instance.avatar_url = avatar_url
            instance.save(update_fields=["avatar_url"])
        elif not (instance.avatar_url or "").strip():
            instance.avatar_url = self._default_avatar_url(instance)
            instance.save(update_fields=["avatar_url"])

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
    attachments = serializers.SerializerMethodField()
    attachment_count = serializers.SerializerMethodField()
    has_attachments = serializers.SerializerMethodField()

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
            "attachments",
            "attachment_count",
            "has_attachments",
        ]
        read_only_fields = [
            "sender_id",
            "sender_name",
            "is_mine",
            "timestamp",
            "is_read",
            "attachments",
            "attachment_count",
            "has_attachments",
        ]

    def get_sender_name(self, obj):
        return obj.sender.profile.display_name or obj.sender.profile.full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and obj.sender_id == request.user.id)

    def get_attachments(self, obj):
        request = self.context.get("request")
        return DirectMessageAttachmentSerializer(
            obj.attachments.all(),
            many=True,
            context={"request": request},
        ).data

    def get_attachment_count(self, obj):
        return obj.attachments.count()

    def get_has_attachments(self, obj):
        return obj.attachments.exists()


class DirectMessageAttachmentSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()
    extension = serializers.SerializerMethodField()
    is_image = serializers.SerializerMethodField()

    class Meta:
        model = DirectMessageAttachment
        fields = [
            "id",
            "file_name",
            "mime_type",
            "size_bytes",
            "url",
            "extension",
            "is_image",
            "created_at",
        ]
        read_only_fields = fields

    def get_url(self, obj):
        request = self.context.get("request")
        if not obj.file:
            return None
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url

    def get_extension(self, obj):
        name = obj.file_name or ""
        if "." not in name:
            return ""
        return name.rsplit(".", 1)[-1].lower()

    def get_is_image(self, obj):
        mime_type = (obj.mime_type or "").lower()
        if mime_type.startswith("image/"):
            return True
        return self.get_extension(obj) in {"jpg", "jpeg", "png", "gif", "webp", "bmp", "heic"}


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
    is_admin = serializers.SerializerMethodField()
    is_self = serializers.SerializerMethodField()

    class Meta:
        model = HubMember
        fields = ["user", "role", "joined_at", "muted", "is_admin", "is_self"]

    def get_is_admin(self, obj):
        return obj.role == "admin"

    def get_is_self(self, obj):
        request = self.context.get("request")
        return bool(request and obj.user_id == request.user.id)


class HubMembershipActionSerializer(serializers.Serializer):
    ACTION_CHOICES = [
        ("add", "Add member"),
        ("promote", "Promote to admin"),
        ("demote", "Demote to member"),
        ("remove", "Remove member"),
        ("leave", "Leave hub"),
    ]

    action = serializers.ChoiceField(choices=ACTION_CHOICES)
    user_id = serializers.IntegerField(required=False, min_value=1)
    user_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        required=False,
        allow_empty=False,
    )


class HubInviteSerializer(serializers.ModelSerializer):
    invite_url = serializers.SerializerMethodField()
    qr_data = serializers.SerializerMethodField()
    is_expired = serializers.BooleanField(read_only=True)
    is_consumed = serializers.BooleanField(read_only=True)

    class Meta:
        model = HubInvite
        fields = [
            "id",
            "hub",
            "code",
            "invite_url",
            "qr_data",
            "created_at",
            "expires_at",
            "is_active",
            "max_uses",
            "use_count",
            "is_expired",
            "is_consumed",
        ]
        read_only_fields = fields

    def _invite_url(self, obj):
        base = getattr(settings, "CAMPUZ_INVITE_BASE_URL", "").strip()
        if not base:
            base = "https://campuz.app/join"
        return f"{base}?code={obj.code}"

    def get_invite_url(self, obj):
        return self._invite_url(obj)

    def get_qr_data(self, obj):
        return self._invite_url(obj)


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
    current_user_role = serializers.SerializerMethodField()
    can_manage_members = serializers.SerializerMethodField()

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
            "current_user_role",
            "can_manage_members",
            "created_at",
        ]
        read_only_fields = ["creator", "members", "sections"]

    def get_members_count(self, obj):
        return obj.hub_members.count()

    def _current_membership(self, obj):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return None
        return obj.hub_members.filter(user=request.user).first()

    def get_current_user_role(self, obj):
        membership = self._current_membership(obj)
        request = self.context.get("request")
        if membership is not None:
            return membership.role
        if request and request.user.is_authenticated and obj.creator_id == request.user.id:
            return "admin"
        return None

    def get_can_manage_members(self, obj):
        membership = self._current_membership(obj)
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        return bool(membership and membership.role == "admin")


class BroadcastCreateSerializer(serializers.Serializer):
    PRIORITY_CHOICES = [
        ("low", "Low"),
        ("normal", "Normal"),
        ("high", "High"),
    ]

    title = serializers.CharField(max_length=200)
    content = serializers.CharField()
    priority = serializers.ChoiceField(choices=PRIORITY_CHOICES, default="normal")
    send_as_sms = serializers.BooleanField(required=False, default=False)

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Title cannot be blank.")
        return value

    def validate_content(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Content cannot be blank.")
        return value


class BroadcastSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)
    sender_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    sms_delivery_count = serializers.SerializerMethodField()
    sms_sent_count = serializers.SerializerMethodField()
    sms_failed_count = serializers.SerializerMethodField()

    class Meta:
        model = Broadcast
        fields = [
            "id",
            "hub",
            "sender",
            "sender_name",
            "is_mine",
            "title",
            "content",
            "priority",
            "timestamp",
            "sms_delivery_count",
            "sms_sent_count",
            "sms_failed_count",
        ]
        read_only_fields = [
            "hub",
            "sender",
            "sender_name",
            "is_mine",
            "timestamp",
            "sms_delivery_count",
            "sms_sent_count",
            "sms_failed_count",
        ]

    def get_sender_name(self, obj):
        profile = getattr(obj.sender, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and obj.sender_id == request.user.id)

    def get_sms_delivery_count(self, obj):
        return obj.sms_deliveries.count()

    def get_sms_sent_count(self, obj):
        return obj.sms_deliveries.filter(status="sent").count()

    def get_sms_failed_count(self, obj):
        return obj.sms_deliveries.filter(status="failed").count()


class HubMeetingCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=200)
    description = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    meeting_url = serializers.URLField(max_length=1000)
    scheduled_for = serializers.DateTimeField()

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Title cannot be blank.")
        return value

    def validate_description(self, value):
        if value is None:
            return ""
        return value.strip()


class HubMeetingSerializer(serializers.ModelSerializer):
    created_by = UserSerializer(read_only=True)
    created_by_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    can_manage = serializers.SerializerMethodField()
    is_upcoming = serializers.SerializerMethodField()

    class Meta:
        model = HubMeeting
        fields = [
            "id",
            "hub",
            "created_by",
            "created_by_name",
            "is_mine",
            "can_manage",
            "title",
            "description",
            "meeting_url",
            "scheduled_for",
            "created_at",
            "updated_at",
            "is_upcoming",
        ]
        read_only_fields = [
            "hub",
            "created_by",
            "created_by_name",
            "is_mine",
            "can_manage",
            "created_at",
            "updated_at",
            "is_upcoming",
        ]

    def get_created_by_name(self, obj):
        profile = getattr(obj.created_by, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and obj.created_by_id == request.user.id)

    def get_can_manage(self, obj):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        membership = obj.hub.hub_members.filter(user=request.user).first()
        return bool(membership and membership.role == "admin")

    def get_is_upcoming(self, obj):
        return obj.scheduled_for >= timezone.now()


class ResourceCreateSerializer(serializers.Serializer):
    RESOURCE_TYPE_CHOICES = [
        ("pdf", "PDF"),
        ("document", "Document"),
        ("video", "Video"),
        ("link", "Link"),
        ("other", "Other"),
    ]

    title = serializers.CharField(max_length=200)
    url = serializers.URLField(max_length=1000)
    resource_type = serializers.ChoiceField(
        choices=RESOURCE_TYPE_CHOICES,
        default="other",
    )

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Title cannot be blank.")
        return value


class ResourceSerializer(serializers.ModelSerializer):
    uploaded_by = UserSerializer(read_only=True)
    uploaded_by_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    can_manage = serializers.SerializerMethodField()

    class Meta:
        model = Resource
        fields = [
            "id",
            "hub",
            "title",
            "resource_type",
            "url",
            "uploaded_by",
            "uploaded_by_name",
            "is_mine",
            "can_manage",
            "upload_date",
        ]
        read_only_fields = [
            "hub",
            "uploaded_by",
            "uploaded_by_name",
            "is_mine",
            "can_manage",
            "upload_date",
        ]

    def get_uploaded_by_name(self, obj):
        profile = getattr(obj.uploaded_by, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and obj.uploaded_by_id == request.user.id)

    def get_can_manage(self, obj):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        membership = obj.hub.hub_members.filter(user=request.user).first()
        return bool(membership and membership.role == "admin")


class TaskCreateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=200)
    description = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    course_name = serializers.CharField(max_length=100)
    due_date = serializers.DateTimeField()
    assigned_to_id = serializers.IntegerField(min_value=1)

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Title cannot be blank.")
        return value

    def validate_course_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Course name cannot be blank.")
        return value

    def validate_description(self, value):
        if value is None:
            return ""
        return value.strip()


class TaskSubmitSerializer(serializers.Serializer):
    submission_text = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    submission_link = serializers.URLField(required=False, allow_blank=True, allow_null=True)

    def validate_submission_text(self, value):
        if value is None:
            return ""
        return value.strip()

    def validate_submission_link(self, value):
        if value is None:
            return ""
        return value.strip()


class TaskGradeSerializer(serializers.Serializer):
    grade = serializers.CharField(max_length=50)
    feedback = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    def validate_grade(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Grade cannot be blank.")
        return value

    def validate_feedback(self, value):
        if value is None:
            return ""
        return value.strip()


class TaskSerializer(serializers.ModelSerializer):
    assigned_to = UserSerializer(read_only=True)
    assigned_to_name = serializers.SerializerMethodField()
    graded_by_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    can_manage = serializers.SerializerMethodField()
    can_submit = serializers.SerializerMethodField()
    can_grade = serializers.SerializerMethodField()
    is_overdue = serializers.SerializerMethodField()
    is_submitted = serializers.SerializerMethodField()

    class Meta:
        model = TaskItem
        fields = [
            "id",
            "hub",
            "title",
            "description",
            "course_name",
            "due_date",
            "status",
            "assigned_to",
            "assigned_to_name",
            "submission_text",
            "submission_link",
            "submitted_at",
            "graded_by_name",
            "graded_at",
            "grade",
            "feedback",
            "is_mine",
            "can_manage",
            "can_submit",
            "can_grade",
            "is_overdue",
            "is_submitted",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "hub",
            "assigned_to",
            "assigned_to_name",
            "graded_by_name",
            "is_mine",
            "can_manage",
            "can_submit",
            "can_grade",
            "is_overdue",
            "is_submitted",
            "created_at",
            "updated_at",
        ]

    def get_assigned_to_name(self, obj):
        profile = getattr(obj.assigned_to, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def get_graded_by_name(self, obj):
        if obj.graded_by is None:
            return None
        profile = getattr(obj.graded_by, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def _request_user(self):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return None
        return request.user

    def _is_admin(self, obj):
        user = self._request_user()
        if user is None:
            return False
        if user.is_superuser:
            return True
        if obj.hub_id is None:
            return False
        membership = obj.hub.hub_members.filter(user=user).first()
        return bool(membership and membership.role == "admin")

    def get_is_mine(self, obj):
        user = self._request_user()
        return bool(user and obj.assigned_to_id == user.id)

    def get_can_manage(self, obj):
        return self._is_admin(obj)

    def get_can_submit(self, obj):
        user = self._request_user()
        return bool(user and obj.assigned_to_id == user.id and obj.status in {"pending", "submitted"})

    def get_can_grade(self, obj):
        return self._is_admin(obj)

    def get_is_overdue(self, obj):
        return obj.status == "pending" and obj.due_date < timezone.now()

    def get_is_submitted(self, obj):
        return obj.status in {"submitted", "graded"}


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)
    sender_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            "id",
            "hub",
            "sender",
            "sender_name",
            "is_mine",
            "content",
            "timestamp",
        ]
        read_only_fields = ["sender", "sender_name", "is_mine"]

    def get_sender_name(self, obj):
        profile = getattr(obj.sender, "profile", None)
        if profile is None:
            return "Campuz user"
        display_name = (profile.display_name or "").strip()
        if display_name:
            return display_name
        full_name = (profile.full_name or "").strip()
        return full_name or "Campuz user"

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and obj.sender_id == request.user.id)
