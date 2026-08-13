from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone


class UserProfile(models.Model):
    """
    Roles are Hub-scoped, not global.
    - Hub creator => Admin of that Hub (can broadcast messages)
    - Hub member  => Viewer of that Hub (read-only, can react)
    """

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    full_name = models.CharField(
        max_length=150,
        blank=True,
        null=True,
        help_text="Full name provided during registration",
    )
    avatar_url = models.URLField(
        max_length=500, blank=True, null=True, help_text="URL to the user's web avatar"
    )
    display_name = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Public handle chosen during profile setup",
    )
    phone_number = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        unique=True,
        help_text="E.164 number used for OTP delivery",
    )

    # Auth Verification Fields
    is_verified = models.BooleanField(default=False)
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_created_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when the current OTP was generated",
    )
    profile_setup_completed = models.BooleanField(
        default=False,
        help_text="True once the user has chosen a public username via profile setup",
    )

    # Admin Privileges
    can_create_hubs = models.BooleanField(
        default=False,
        help_text="True when the user has redeemed a valid admin invitation code",
    )

    def __str__(self):
        return self.user.username


# Automatically create a UserProfile when a User is created
@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    instance.profile.save()


# Hub model representing a community within the application
class Hub(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    cover_image_url = models.URLField(
        max_length=500,
        blank=True,
        null=True,
    )

    creator = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="created_hubs",
    )

    members = models.ManyToManyField(
        User,
        through="HubMember",
        related_name="joined_hubs",
        # blank=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


# Hub members are managed through the HubMember model, which allows for role-based access control within each hub.
class HubMember(models.Model):

    ROLE_CHOICES = [
        ("admin", "Admin"),
        ("member", "Member"),
    ]

    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="hub_members",
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="hub_memberships",
    )

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default="member",
    )

    joined_at = models.DateTimeField(auto_now_add=True)

    muted = models.BooleanField(default=False)

    class Meta:
        unique_together = ("hub", "user")

    def __str__(self):
        return f"{self.user.username} ({self.role}) - {self.hub.name}"


class HubInvite(models.Model):
    """
    A hub-scoped invitation code used to generate shareable join links and QR
    codes for existing Campuz users or future signups.
    """

    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="invites",
    )
    code = models.CharField(max_length=64, unique=True)
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_hub_invites",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    max_uses = models.PositiveIntegerField(null=True, blank=True)
    use_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(fields=["hub", "is_active"]),
            models.Index(fields=["code"]),
        ]

    def __str__(self):
        return f"{self.hub.name} invite ({self.code})"

    @property
    def is_expired(self) -> bool:
        return bool(self.expires_at and self.expires_at <= timezone.now())

    @property
    def is_consumed(self) -> bool:
        return self.max_uses is not None and self.use_count >= self.max_uses


class Message(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name="messages")
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return (
            f"Message by {self.sender.username} in {self.hub.name} at {self.timestamp}"
        )


class SMSDelivery(models.Model):
    STATUS_PENDING = "pending"
    STATUS_SENT = "sent"
    STATUS_FAILED = "failed"

    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_SENT, "Sent"),
        (STATUS_FAILED, "Failed"),
    ]

    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name="sms_deliveries",
        null=True,
        blank=True,
    )
    broadcast = models.ForeignKey(
        "Broadcast",
        on_delete=models.CASCADE,
        related_name="sms_deliveries",
        null=True,
        blank=True,
    )
    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sms_deliveries",
    )
    phone_number = models.CharField(max_length=20)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )
    provider_message_id = models.CharField(
        max_length=255,
        blank=True,
        null=True,
    )
    provider_status = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Raw delivery status from Arkesel webhook (e.g. DELIVERED).",
    )
    sent_at = models.DateTimeField(null=True, blank=True)
    provider_status_at = models.DateTimeField(null=True, blank=True)
    error_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    (models.Q(message__isnull=False) & models.Q(broadcast__isnull=True))
                    | (models.Q(message__isnull=True) & models.Q(broadcast__isnull=False))
                ),
                name="smsdelivery_exactly_one_target",
            )
        ]
        indexes = [
            models.Index(fields=["message", "status"]),
            models.Index(fields=["broadcast", "status"]),
            models.Index(fields=["recipient", "status"]),
        ]

    def __str__(self):
        target = self.message_id or self.broadcast_id
        return f"{target} -> {self.recipient_id} ({self.status})"


class Broadcast(models.Model):
    PRIORITY_CHOICES = [
        ("low", "Low"),
        ("normal", "Normal"),
        ("high", "High"),
    ]
    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="broadcasts",
    )
    sender = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="broadcasts"
    )
    title = models.CharField(max_length=200)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    priority = models.CharField(
        max_length=10, choices=PRIORITY_CHOICES, default="normal"
    )

    def __str__(self):
        return f"Broadcast: {self.title} by {self.sender.username}"


class Resource(models.Model):
    RESOURCE_TYPE_CHOICES = [
        ("pdf", "PDF"),
        ("document", "Document"),
        ("video", "Video"),
        ("link", "Link"),
        ("other", "Other"),
    ]

    title = models.CharField(max_length=200)
    resource_type = models.CharField(
        max_length=50,
        choices=RESOURCE_TYPE_CHOICES,
        default="other",
    )
    url = models.URLField(max_length=1000)
    uploaded_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name="uploaded_resources"
    )
    upload_date = models.DateTimeField(auto_now_add=True)
    hub = models.ForeignKey(
        Hub, on_delete=models.CASCADE, related_name="resources", null=True, blank=True
    )

    def __str__(self):
        return self.title


class HubMeeting(models.Model):
    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="meetings",
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True, null=True)
    meeting_url = models.URLField(max_length=1000)
    scheduled_for = models.DateTimeField()
    created_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="created_hub_meetings",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["scheduled_for", "id"]
        indexes = [
            models.Index(fields=["hub", "scheduled_for"]),
            models.Index(fields=["hub", "created_at"]),
        ]

    def __str__(self):
        return f"{self.title} - {self.hub.name}"


class TaskItem(models.Model):
    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("submitted", "Submitted"),
        ("graded", "Graded"),
    ]
    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="tasks",
        null=True,
        blank=True,
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True, null=True)
    course_name = models.CharField(max_length=100)
    due_date = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    assigned_to = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="tasks",
    )
    submission_text = models.TextField(blank=True, null=True)
    submission_link = models.URLField(max_length=1000, blank=True, null=True)
    submitted_at = models.DateTimeField(null=True, blank=True)
    graded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="graded_tasks",
    )
    graded_at = models.DateTimeField(null=True, blank=True)
    grade = models.CharField(max_length=50, blank=True, null=True)
    feedback = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} ({self.status})"


class HubSection(models.Model):
    """
    Sections within a Hub organize content by category.

    Each Hub can have multiple sections (e.g., General, Announcements, Resources,
    Meetings, Tasks). Sections define what content types are available in that area
    of the Hub and control ordering/visibility.
    """

    SECTION_TYPE_CHOICES = [
        ("general", "General"),
        ("announcements", "Announcements"),
        ("resources", "Resources"),
        ("meetings", "Meetings"),
        ("tasks", "Tasks"),
    ]

    hub = models.ForeignKey(
        Hub,
        on_delete=models.CASCADE,
        related_name="sections",
        help_text="The Hub this section belongs to",
    )

    section_type = models.CharField(
        max_length=20,
        choices=SECTION_TYPE_CHOICES,
        help_text="Type of content this section contains",
    )

    title = models.CharField(
        max_length=100,
        help_text="Display name for this section (e.g., 'Class Updates', 'Assignments')",
    )

    description = models.TextField(
        blank=True,
        null=True,
        help_text="Optional description explaining what this section is for",
    )

    order = models.PositiveIntegerField(
        default=0,
        help_text="Display order (lower numbers appear first)",
    )

    is_enabled = models.BooleanField(
        default=True,
        help_text="Whether this section is visible to Hub members",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["hub", "section_type"],
                name="unique_hub_section_type",
            ),
        ]
        ordering = ["hub", "order", "id"]
        indexes = [
            models.Index(fields=["hub", "is_enabled"]),
            models.Index(fields=["hub", "order"]),
        ]

    def __str__(self):
        return f"{self.hub.name} → {self.title} ({self.get_section_type_display()})"


class AdminInvitationCode(models.Model):
    """
    One-time invitation codes issued by system admins to grant hub creation
    privileges. Each code is unique, single-use, and optionally has an expiry.
    """

    code = models.CharField(
        max_length=50,
        unique=True,
        help_text="Unique invitation code (e.g., KNUST-CS-2026)",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_invitation_codes",
        help_text="Admin who created this code",
    )
    is_used = models.BooleanField(default=False)
    used_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="redeemed_invitation_codes",
        help_text="User who redeemed this code",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Optional expiration timestamp",
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Deactivated codes cannot be redeemed",
    )

    def __str__(self):
        return f"{self.code} ({'used' if self.is_used else 'active'})"

    class Meta:
        verbose_name = "Admin Invitation Code"
        verbose_name_plural = "Admin Invitation Codes"


class DirectConversation(models.Model):
    """
    A 1:1 conversation between two users. Ordered users ensure uniqueness.
    """

    user_1 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="direct_conversations_as_user1",
    )
    user_2 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="direct_conversations_as_user2",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("user_1", "user_2"),
                name="unique_direct_conversation",
            ),
            models.CheckConstraint(
                condition=~models.Q(user_1=models.F("user_2")),
                name="direct_conversation_distinct_users",
            ),
        ]
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Conversation: {self.user_1.username} ↔ {self.user_2.username}"


class DirectMessage(models.Model):
    """
    Messages within a DirectConversation.
    """

    conversation = models.ForeignKey(
        DirectConversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_direct_messages",
    )
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ["timestamp"]

    def __str__(self):
        return f"{self.sender.username} -> {self.content[:30]}"
class DirectMessageAttachment(models.Model):
    """
    A file attached to a direct message.
    """

    message = models.ForeignKey(
        DirectMessage,
        on_delete=models.CASCADE,
        related_name="attachments",
    )
    file = models.FileField(upload_to="direct_messages/%Y/%m/%d/")
    file_name = models.CharField(max_length=255)
    mime_type = models.CharField(max_length=100, blank=True, null=True)
    size_bytes = models.PositiveBigIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return self.file_name


class AdminInvitationCode(models.Model):
    """
    One-time invitation codes issued by system admins to grant hub creation
    privileges. Each code is unique, single-use, and optionally has an expiry.
    """

    code = models.CharField(
        max_length=50,
        unique=True,
        help_text="Unique invitation code (e.g., KNUST-CS-2026)",
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_invitation_codes",
        help_text="Admin who created this code",
    )
    is_used = models.BooleanField(default=False)
    used_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="redeemed_invitation_codes",
        help_text="User who redeemed this code",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Optional expiration timestamp",
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Deactivated codes cannot be redeemed",
    )

    def __str__(self):
        return f"{self.code} ({'used' if self.is_used else 'active'})"

    class Meta:
        verbose_name = "Admin Invitation Code"
        verbose_name_plural = "Admin Invitation Codes"


class DirectConversation(models.Model):
    """
    A 1:1 conversation between two users. Ordered users ensure uniqueness.
    """

    user_1 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="direct_conversations_as_user1",
    )
    user_2 = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="direct_conversations_as_user2",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("user_1", "user_2"),
                name="unique_direct_conversation",
            ),
            models.CheckConstraint(
                condition=~models.Q(user_1=models.F("user_2")),
                name="direct_conversation_distinct_users",
            ),
        ]
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Conversation: {self.user_1.username} ↔ {self.user_2.username}"


class DirectMessage(models.Model):
    """
    Messages within a DirectConversation.
    """

    conversation = models.ForeignKey(
        DirectConversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_direct_messages",
    )
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ["timestamp"]

    def __str__(self):
        return f"{self.sender.username} -> {self.content[:30]}"


class DirectMessageAttachment(models.Model):
    """
    A file attached to a direct message.
    """

    message = models.ForeignKey(
        DirectMessage,
        on_delete=models.CASCADE,
        related_name="attachments",
    )
    file = models.FileField(upload_to="direct_messages/%Y/%m/%d/")
    file_name = models.CharField(max_length=255)
    mime_type = models.CharField(max_length=100, blank=True, null=True)
    size_bytes = models.PositiveBigIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self):
        return self.file_name


class DeviceToken(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="device_tokens")
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} - {self.token[:10]}..."


class AppNotification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="notifications", null=True, blank=True)
    title = models.CharField(max_length=255)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.title}"
