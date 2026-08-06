from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth.models import User

from .models import (
    Hub,
    HubMember,
    Message,
    UserProfile,
)

from .serializers import (
    UserSerializer,
    HubSerializer,
    MessageSerializer,
    RegisterSerializer,
    VerifyOTPSerializer,
    ProfileSetupSerializer,
    ResendOTPSerializer,
    VerifiedTokenObtainPairSerializer,
    issue_otp,
)
from .permissions import IsHubCreatorOrReadOnly


def tokens_for_user(user):
    """Build a fresh access/refresh pair matching the /token/ response shape."""
    refresh = RefreshToken.for_user(user)
    return {"refresh": str(refresh), "access": str(refresh.access_token)}


class VerifiedTokenObtainPairView(TokenObtainPairView):
    serializer_class = VerifiedTokenObtainPairSerializer


class UserViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API endpoint that allows users to be viewed.
    """

    queryset = User.objects.all().order_by("-date_joined")
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer


class CurrentUserView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data["username"]
            otp_code = serializer.validated_data["otp_code"]
            try:
                user = User.objects.get(username=username)
                if user.profile.otp_code and user.profile.otp_code == otp_code:
                    user.profile.is_verified = True
                    user.profile.otp_code = None
                    user.profile.save(update_fields=["is_verified", "otp_code"])
                    # Sign the user in here so profile setup — which requires
                    # authentication — can run straight after verification.
                    return Response(
                        {
                            "message": "OTP verified successfully",
                            **tokens_for_user(user),
                        },
                        status=status.HTTP_200_OK,
                    )
                return Response(
                    {"error": "Invalid OTP code"}, status=status.HTTP_400_BAD_REQUEST
                )
            except User.DoesNotExist:
                return Response(
                    {"error": "User not found"}, status=status.HTTP_404_NOT_FOUND
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ResendOTPView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = ResendOTPSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data["username"]
            try:
                user = User.objects.get(username=username)
                issue_otp(user.profile)
                return Response(
                    {"message": "OTP resent successfully"}, status=status.HTTP_200_OK
                )
            except User.DoesNotExist:
                return Response(
                    {"error": "User not found"}, status=status.HTTP_404_NOT_FOUND
                )
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

    queryset = Hub.objects.all().order_by("-created_at")
    serializer_class = HubSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(creator=self.request.user)


class MessageViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows messages to be viewed or edited.
    """

    queryset = Message.objects.all().order_by("-timestamp")
    serializer_class = MessageSerializer
    permission_classes = [IsHubCreatorOrReadOnly]

    # Override the perform_create method to automatically set the creator of the message to the currently authenticated user.
    def perform_create(self, serializer):

        hub = serializer.save(
            creator=self.request.user,
        )

        HubMember.objects.create(
            hub=hub,
            user=self.request.user,
            role="admin",
        )
