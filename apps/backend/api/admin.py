from django.contrib import admin
from django.contrib.auth.models import User

from .models import (
    AdminInvitationCode,
    Broadcast,
    DirectConversation,
    DirectMessageAttachment,
    DirectMessage,
    Hub,
    HubInvite,
    HubMeeting,
    HubMember,
    HubSection,
    Message,
    MessageAttachment,
    OtpDeliveryLog,
    Resource,
    SMSDelivery,
    TaskItem,
    UserProfile,
)

# -----------------------------------------------------------------------------
# Campuz Branding & Metadata
# -----------------------------------------------------------------------------
admin.site.site_header = "Campuz Administration"
admin.site.site_title = "Campuz Admin"
admin.site.index_title = "System Overview"


# -----------------------------------------------------------------------------
# Custom Index View with Live KPI Stat Metrics
# -----------------------------------------------------------------------------
_original_admin_index = admin.site.index


def campuz_admin_index(request, extra_context=None):
    extra_context = extra_context or {}
    try:
        total_users = User.objects.count()
        verified_users = UserProfile.objects.filter(is_verified=True).count()
        active_hubs = Hub.objects.count()
        shared_resources = Resource.objects.count()
        hub_messages = Message.objects.count()
        direct_messages = DirectMessage.objects.count()
        total_messages = hub_messages + direct_messages

        verified_percent = (
            f"{round((verified_users / total_users * 100))}%"
            if total_users > 0
            else "0%"
        )

        extra_context.update(
            {
                "kpi_total_users": total_users,
                "kpi_verified_users": verified_users,
                "kpi_verified_percent": verified_percent,
                "kpi_active_hubs": active_hubs,
                "kpi_shared_resources": shared_resources,
                "kpi_total_messages": total_messages,
            }
        )
    except Exception:
        pass

    return _original_admin_index(request, extra_context=extra_context)


admin.site.index = campuz_admin_index


# -----------------------------------------------------------------------------
# Model Admins
# -----------------------------------------------------------------------------
@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = [
        "user",
        "full_name",
        "phone_number",
        "is_verified",
        "can_create_hubs",
        "profile_setup_completed",
    ]
    search_fields = ["user__username", "full_name", "phone_number", "display_name"]
    list_filter = ["is_verified", "can_create_hubs", "profile_setup_completed"]
    readonly_fields = ["otp_code", "otp_created_at"]


@admin.register(OtpDeliveryLog)
class OtpDeliveryLogAdmin(admin.ModelAdmin):
    list_display = [
        "phone_number",
        "profile",
        "status",
        "provider_status",
        "provider_message_id",
        "created_at",
    ]
    search_fields = [
        "phone_number",
        "profile__user__username",
        "provider_message_id",
        "provider_status",
    ]
    list_filter = ["status", "provider_status", "created_at"]
    readonly_fields = [
        "profile",
        "phone_number",
        "status",
        "provider_message_id",
        "provider_status",
        "error_message",
        "response_data",
        "created_at",
    ]


@admin.register(AdminInvitationCode)
class AdminInvitationCodeAdmin(admin.ModelAdmin):
    list_display = [
        "code",
        "created_by",
        "is_active",
        "is_used",
        "used_by",
        "created_at",
        "expires_at",
    ]
    search_fields = ["code"]
    list_filter = ["is_active", "is_used"]
    readonly_fields = ["used_by", "used_at", "created_at"]


@admin.register(Hub)
class HubAdmin(admin.ModelAdmin):
    list_display = ["name", "creator", "sms_credits", "is_premium", "created_at"]
    search_fields = ["name", "description", "creator__username"]
    list_filter = ["is_premium", "created_at"]


@admin.register(HubMember)
class HubMemberAdmin(admin.ModelAdmin):
    list_display = ["user", "hub", "role", "joined_at", "muted"]
    search_fields = ["user__username", "hub__name"]
    list_filter = ["role", "muted", "joined_at"]


@admin.register(HubInvite)
class HubInviteAdmin(admin.ModelAdmin):
    list_display = [
        "hub",
        "code",
        "created_by",
        "is_active",
        "use_count",
        "max_uses",
        "created_at",
        "expires_at",
    ]
    search_fields = ["code", "hub__name", "created_by__username"]
    list_filter = ["is_active", "created_at", "expires_at"]
    readonly_fields = ["created_at", "use_count"]


@admin.register(HubSection)
class HubSectionAdmin(admin.ModelAdmin):
    list_display = ["title", "hub", "section_type", "order", "is_enabled"]
    search_fields = ["title", "hub__name"]
    list_filter = ["section_type", "is_enabled"]


@admin.register(DirectConversation)
class DirectConversationAdmin(admin.ModelAdmin):
    list_display = ["id", "user_1", "user_2", "created_at", "updated_at"]
    search_fields = ["user_1__username", "user_2__username"]
    readonly_fields = ["created_at", "updated_at"]


@admin.register(DirectMessage)
class DirectMessageAdmin(admin.ModelAdmin):
    list_display = ["sender", "conversation", "content", "timestamp", "is_read"]
    list_filter = ["is_read"]
    search_fields = ["sender__username", "content"]
    readonly_fields = ["timestamp"]


@admin.register(DirectMessageAttachment)
class DirectMessageAttachmentAdmin(admin.ModelAdmin):
    list_display = ["file_name", "message", "mime_type", "size_bytes", "created_at"]
    search_fields = [
        "file_name",
        "message__sender__username",
        "message__conversation__id",
    ]
    readonly_fields = ["created_at"]


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ["sender", "hub", "content_preview", "timestamp"]
    list_filter = ["hub", "timestamp"]
    search_fields = ["sender__username", "content", "hub__name"]

    @admin.display(description="Content Preview")
    def content_preview(self, obj):
        if not obj.content:
            return ""
        return obj.content[:60] + "..." if len(obj.content) > 60 else obj.content


@admin.register(MessageAttachment)
class MessageAttachmentAdmin(admin.ModelAdmin):
    list_display = ["file_name", "message", "mime_type", "size_bytes", "created_at"]
    search_fields = ["file_name", "message__sender__username"]
    readonly_fields = ["created_at"]


@admin.register(Broadcast)
class BroadcastAdmin(admin.ModelAdmin):
    list_display = ["title", "hub", "sender", "priority", "timestamp"]
    list_filter = ["priority", "hub", "timestamp"]
    search_fields = ["title", "content", "hub__name", "sender__username"]


@admin.register(Resource)
class ResourceAdmin(admin.ModelAdmin):
    list_display = ["title", "resource_type", "hub", "uploaded_by", "upload_date"]
    list_filter = ["resource_type", "upload_date", "hub"]
    search_fields = ["title", "hub__name", "uploaded_by__username"]


@admin.register(HubMeeting)
class HubMeetingAdmin(admin.ModelAdmin):
    list_display = [
        "title",
        "hub",
        "scheduled_for",
        "created_by",
        "created_at",
        "updated_at",
    ]
    search_fields = [
        "title",
        "description",
        "hub__name",
        "created_by__username",
    ]
    list_filter = ["hub", "created_at", "scheduled_for"]
    readonly_fields = ["created_at", "updated_at"]


@admin.register(TaskItem)
class TaskItemAdmin(admin.ModelAdmin):
    list_display = ["title", "hub", "assigned_to", "status", "due_date", "grade"]
    search_fields = [
        "title",
        "course_name",
        "hub__name",
        "assigned_to__username",
        "assigned_to__profile__display_name",
    ]
    list_filter = ["hub", "status", "due_date"]


@admin.register(SMSDelivery)
class SMSDeliveryAdmin(admin.ModelAdmin):
    list_display = [
        "recipient",
        "phone_number",
        "status",
        "provider_status",
        "sent_at",
        "created_at",
    ]
    list_filter = ["status", "provider_status", "created_at"]
    search_fields = ["recipient__username", "phone_number", "provider_message_id"]
    readonly_fields = ["created_at", "updated_at", "provider_status_at"]
