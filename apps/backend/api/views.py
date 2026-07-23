from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth.models import User
from .models import Hub, Message, UserProfile
from .serializers import (
    UserSerializer, HubSerializer, MessageSerializer,
    RegisterSerializer, VerifyOTPSerializer, ProfileSetupSerializer
)
from .permissions import IsHubCreatorOrReadOnly


class UserViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API endpoint that allows users to be viewed.
    """
    queryset = User.objects.all().order_by('-date_joined')
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer

class VerifyOTPView(APIView):
    permission_classes = (permissions.AllowAny,)
    
    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data['username']
            otp_code = serializer.validated_data['otp_code']
            try:
                user = User.objects.get(username=username)
                if user.profile.otp_code == otp_code:
                    user.profile.is_verified = True
                    user.profile.otp_code = None
                    user.profile.save()
                    return Response({"message": "OTP verified successfully"}, status=status.HTTP_200_OK)
                return Response({"error": "Invalid OTP code"}, status=status.HTTP_400_BAD_REQUEST)
            except User.DoesNotExist:
                return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class ProfileSetupView(generics.UpdateAPIView):
    queryset = UserProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = ProfileSetupSerializer

    def get_object(self):
        return self.request.user.profile


class HubViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows hubs to be viewed or edited.
    """
    queryset = Hub.objects.all().order_by('-created_at')
    serializer_class = HubSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(creator=self.request.user)


class MessageViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows messages to be viewed or edited.
    """
    queryset = Message.objects.all().order_by('-timestamp')
    serializer_class = MessageSerializer
    permission_classes = [IsHubCreatorOrReadOnly]

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user)
