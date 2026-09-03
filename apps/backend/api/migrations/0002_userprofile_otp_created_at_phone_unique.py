# Generated manually — adds otp_created_at to UserProfile and enforces
# a unique constraint on phone_number.

import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="otp_created_at",
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text="Timestamp when the current OTP was generated",
            ),
        ),
        migrations.AlterField(
            model_name="userprofile",
            name="phone_number",
            field=models.CharField(
                blank=True,
                null=True,
                unique=True,
                max_length=20,
                help_text="E.164 number used for OTP delivery",
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="profile_setup_completed",
            field=models.BooleanField(
                default=False,
                help_text="True once the user has chosen a public username via profile setup",
            ),
        ),
    ]
