import random

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth.models import User
from .models import (
    UserProfile,
    Hub,
    HubMember,
    Message,
)


def issue_otp(profile):
    """Generate, store and (for now) log a fresh OTP for a profile."""
    otp = str(random.randint(100000, 999999))
    profile.otp_code = otp
    profile.is_verified = False
    profile.save(update_fields=["otp_code", "is_verified"])
    # TODO: Trigger SMS dispatch here with Arkesel API
    print(f"Generated OTP for {profile.user.username}: {otp}")
    return otp


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ["avatar_url", "display_name", "phone_number", "is_verified"]


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name", "profile"]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    full_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    phone_number = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )

    class Meta:
        model = User
        fields = ["username", "password", "email", "full_name", "phone_number"]

    def create(self, validated_data):
        full_name = validated_data.pop("full_name", "").strip()
        phone_number = validated_data.pop("phone_number", "").strip()
        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data.get("email", ""),
            password=validated_data["password"],
        )
        if full_name:
            parts = full_name.split(" ", 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ""
            user.save(update_fields=["first_name", "last_name"])
        # Profile is created by signal in normal flows, but get_or_create keeps
        # registration resilient if the signal fails to load in a deployment.
        profile, _ = UserProfile.objects.get_or_create(user=user)
        if phone_number:
            profile.phone_number = phone_number
            profile.save(update_fields=["phone_number"])
        issue_otp(profile)
        return user


class VerifiedTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Rejects credentials for accounts that have not completed OTP verification."""

    def validate(self, attrs):
        data = super().validate(attrs)
        profile = getattr(self.user, "profile", None)
        if profile is None or not profile.is_verified:
            raise serializers.ValidationError(
                {"error": "Account not verified. Please verify the code sent to you."}
            )
        return data


class VerifyOTPSerializer(serializers.Serializer):
    username = serializers.CharField()
    otp_code = serializers.CharField(max_length=6)


class ResendOTPSerializer(serializers.Serializer):
    username = serializers.CharField()


class ProfileSetupSerializer(serializers.ModelSerializer):
    """Updates the public handle and avatar — role is determined by Hub relationship, not a global field."""

    class Meta:
        model = UserProfile
        fields = ["avatar_url", "display_name"]


# Serializer for the HubMember model
class HubMemberSerializer(serializers.ModelSerializer):

    user = UserSerializer(read_only=True)

    class Meta:
        model = HubMember
        fields = [
            "user",
            "role",
            "joined_at",
            "muted",
        ]


# Serializer for the Hub model responsible for serializing the Hub data along with its members and member count.
class HubSerializer(serializers.ModelSerializer):

    creator = UserSerializer(read_only=True)

    members = HubMemberSerializer(
        source="hub_members",
        many=True,
        read_only=True,
    )

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

        read_only_fields = [
            "creator",
            "members",
        ]

    def get_members_count(self, obj):
        return obj.hub_members.count()


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ["id", "hub", "sender", "content", "timestamp"]
        read_only_fields = ["sender"]
