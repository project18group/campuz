from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile, Hub, Message

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['avatar_url']

class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'profile']

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'password', 'email']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password']
        )
        # Profile is created by signal. We just set OTP here for simplicity.
        import random
        otp = str(random.randint(100000, 999999))
        user.profile.otp_code = otp
        user.profile.is_verified = False
        user.profile.save()
        # TODO: Trigger SMS dispatch here with Arkesel API
        print(f"Generated OTP for {user.username}: {otp}")
        return user

class VerifyOTPSerializer(serializers.Serializer):
    username = serializers.CharField()
    otp_code = serializers.CharField(max_length=6)

class ProfileSetupSerializer(serializers.ModelSerializer):
    """Updates avatar only — role is now determined by Hub relationship, not a global field."""
    class Meta:
        model = UserProfile
        fields = ['avatar_url']

class HubSerializer(serializers.ModelSerializer):
    creator = UserSerializer(read_only=True)
    members_count = serializers.SerializerMethodField()

    class Meta:
        model = Hub
        fields = ['id', 'name', 'description', 'cover_image_url', 'creator', 'members', 'members_count', 'created_at']
        read_only_fields = ['creator']

    def get_members_count(self, obj):
        return obj.members.count()

class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)

    class Meta:
        model = Message
        fields = ['id', 'hub', 'sender', 'content', 'timestamp']
        read_only_fields = ['sender']
