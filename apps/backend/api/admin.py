from django.contrib import admin

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
    Message,
    OtpDeliveryLog,
    Resource,
    TaskItem,
    UserProfile,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "full_name", "phone_number", "is_verified", "can_create_hubs", "profile_setup_completed"]
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
    list_display = ["code", "created_by", "is_active", "is_used", "used_by", "created_at", "expires_at"]
    search_fields = ["code"]
    list_filter = ["is_active", "is_used"]
    readonly_fields = ["used_by", "used_at", "created_at"]


@admin.register(HubInvite)
class HubInviteAdmin(admin.ModelAdmin):
    list_display = ["hub", "code", "created_by", "is_active", "use_count", "max_uses", "created_at", "expires_at"]
    search_fields = ["code", "hub__name", "created_by__username"]
    list_filter = ["is_active", "created_at", "expires_at"]
    readonly_fields = ["created_at", "use_count"]


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
    search_fields = ["file_name", "message__sender__username", "message__conversation__id"]
    readonly_fields = ["created_at"]


admin.site.register(Hub)
admin.site.register(HubMember)
admin.site.register(Message)
admin.site.register(Broadcast)
admin.site.register(Resource)
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
