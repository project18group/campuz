"""
Migration 0003
==============
- UserProfile.full_name        (captured at OTP request time)
- UserProfile.can_create_hubs  (set when an AdminInvitationCode is redeemed)
- AdminInvitationCode model     (manually-issued, one-time hub-admin codes)
- DirectConversation model      (1:1 conversations between registered users)
- DirectMessage model           (messages within a DirectConversation)
"""

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0002_userprofile_otp_created_at_phone_unique"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # ------------------------------------------------------------------ #
        # UserProfile additions                                                #
        # ------------------------------------------------------------------ #
        migrations.AddField(
            model_name="userprofile",
            name="full_name",
            field=models.CharField(
                blank=True,
                null=True,
                max_length=150,
                help_text="Full name provided during registration",
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="can_create_hubs",
            field=models.BooleanField(
                default=False,
                help_text="True when the user has redeemed a valid admin invitation code",
            ),
        ),
        # ------------------------------------------------------------------ #
        # AdminInvitationCode                                                  #
        # ------------------------------------------------------------------ #
        migrations.CreateModel(
            name="AdminInvitationCode",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ("code", models.CharField(max_length=50, unique=True,
                                          help_text="Unique invitation code (e.g., KNUST-CS-2026)")),
                (
                    "created_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="created_invitation_codes",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                ("is_used", models.BooleanField(default=False)),
                (
                    "used_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="redeemed_invitation_codes",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("used_at", models.DateTimeField(blank=True, null=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True,
                                                    help_text="Optional expiration timestamp")),
                ("is_active", models.BooleanField(default=True,
                                                   help_text="Deactivated codes cannot be redeemed")),
            ],
            options={
                "verbose_name": "Admin Invitation Code",
                "verbose_name_plural": "Admin Invitation Codes",
            },
        ),
        # ------------------------------------------------------------------ #
        # DirectConversation                                                   #
        # ------------------------------------------------------------------ #
        migrations.CreateModel(
            name="DirectConversation",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                (
                    "user_1",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="direct_conversations_as_user1",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "user_2",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="direct_conversations_as_user2",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ["-updated_at"]},
        ),
        migrations.AddConstraint(
            model_name="directconversation",
            constraint=models.UniqueConstraint(
                fields=["user_1", "user_2"],
                name="unique_direct_conversation",
            ),
        ),
        # ------------------------------------------------------------------ #
        # DirectMessage                                                        #
        # ------------------------------------------------------------------ #
        migrations.CreateModel(
            name="DirectMessage",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                (
                    "conversation",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="messages",
                        to="api.directconversation",
                    ),
                ),
                (
                    "sender",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="sent_direct_messages",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                ("content", models.TextField()),
                ("timestamp", models.DateTimeField(auto_now_add=True)),
                ("is_read", models.BooleanField(default=False)),
            ],
            options={"ordering": ["timestamp"]},
        ),
    ]
