from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver

class UserProfile(models.Model):
    """
    Roles are Hub-scoped, not global.
    - Hub creator => Admin of that Hub (can broadcast messages)
    - Hub member  => Viewer of that Hub (read-only, can react)
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    avatar_url = models.URLField(max_length=500, blank=True, null=True, help_text="URL to the user's web avatar")
    display_name = models.CharField(max_length=50, blank=True, null=True, help_text="Public handle chosen during profile setup")
    phone_number = models.CharField(max_length=20, blank=True, null=True, help_text="E.164 number used for OTP delivery")

    # Auth Verification Fields
    is_verified = models.BooleanField(default=False)
    otp_code = models.CharField(max_length=6, blank=True, null=True)


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


class Hub(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    cover_image_url = models.URLField(max_length=500, blank=True, null=True, help_text="URL to the hub's web cover image")
    creator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_hubs')
    members = models.ManyToManyField(User, related_name='joined_hubs', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Message(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='messages')
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Message by {self.sender.username} in {self.hub.name} at {self.timestamp}"

class Broadcast(models.Model):
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
    ]
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='broadcasts')
    title = models.CharField(max_length=200)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='normal')

    def __str__(self):
        return f"Broadcast: {self.title} by {self.sender.username}"

class Resource(models.Model):
    title = models.CharField(max_length=200)
    resource_type = models.CharField(max_length=50) # 'pdf', 'link', 'doc', 'video'
    url = models.URLField(max_length=1000)
    uploaded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='uploaded_resources')
    upload_date = models.DateTimeField(auto_now_add=True)
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name='resources', null=True, blank=True)

    def __str__(self):
        return self.title

class TaskItem(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('submitted', 'Submitted'),
        ('graded', 'Graded'),
    ]
    title = models.CharField(max_length=200)
    course_name = models.CharField(max_length=100)
    due_date = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    assigned_to = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tasks')

    def __str__(self):
        return f"{self.title} ({self.status})"
