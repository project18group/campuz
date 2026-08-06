import uuid
from datetime import timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import generics, permissions, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView  # noqa: F401 — re-exported

from .models import Hub, HubMember, Message, UserProfile
from .permissions import IsHubCreatorOrReadOnly
from .serializers import (
    HubSerializer,
    MessageSerializer,
    ProfileSetupSerializer,
    RequestOTPSerializer,
    UserSerializer,
    VerifyOTPSerializer,
    OTP_EXPIRY_MINUTES,
    OTP_RESEND_COOLDOWN_SECONDS,
    _generate_and_save_otp,
    _clear_otp,
)
from .services import sms_service


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _tokens_for_user(user: User) -> dict:
    """Return a fresh access/refresh JWT pair for *user*."""
    refresh = RefreshToken.for_user(user)
    return {"refresh": str(refresh), "access": str(refresh.access_token)}


def _make_uuid_username() -> str:
    """Return a unique internal username the user will never see."""
    return f"u_{uuid.uuid4().hex[:20]}"


# ---------------------------------------------------------------------------
# Phone-auth views
# ---------------------------------------------------------------------------

class RequestOTPView(APIView):
    """
    POST /api/auth/request-otp/

    Body: {"phone_number": "+233..."}

    Generates a 6-digit OTP, persists it on the UserProfile (creating a
    temporary profile/user if one doesn't exist yet so the OTP can be stored
    before the account is formally created), and dispatches it via SMS.

    A 60-second resend cooldown is enforced: if an OTP was generated within
    the last 60 seconds the view returns 429 with the remaining wait time.
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = RequestOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data["phone_number"]

        # -----------------------------------------------------------------
        # Find or create a *pending* profile for this phone number so we
        # have somewhere to store the OTP before the account is confirmed.
        # -----------------------------------------------------------------
        profile = UserProfile.objects.filter(phone_number=phone).first()

        if profile is None:
            # First contact from this number — create a shadow user+profile.
            username = _make_uuid_username()
            # Ensure the generated username is unique (astronomically unlikely
            # to collide, but guard it anyway).
            while User.objects.filter(username=username).exists():
                username = _make_uuid_username()

            user = User.objects.create_user(
                username=username,
                password=None,  # no password — OTP-only auth
            )
            user.set_unusable_password()
            user.save()

            profile = UserProfile.objects.get(user=user)
            profile.phone_number = phone
            profile.save(update_fields=["phone_number"])

        # -----------------------------------------------------------------
        # Resend cooldown check
        # -----------------------------------------------------------------
        if profile.otp_created_at is not None:
            elapsed = (timezone.now() - profile.otp_created_at).total_seconds()
            remaining = OTP_RESEND_COOLDOWN_SECONDS - elapsed
            if remaining > 0:
                return Response(
                    {
                        "error": "Please wait before requesting a new code.",
                        "retry_after_seconds": int(remaining),
                    },
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )

        # -----------------------------------------------------------------
        # Generate OTP and send SMS
        # -----------------------------------------------------------------
        otp = _generate_and_save_otp(profile)
        try:
            sms_service.send_otp(phone, otp)
        except Exception:
            # SMS dispatch failed — the OTP is already persisted so the user
            # can retry; we return 502 so the client can show a useful message.
            return Response(
                {"error": "Failed to send verification code. Please try again."},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response({"message": "OTP sent"}, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    """
    POST /api/auth/verify-otp/

    Body: {"phone_number": "+233...", "otp_code": "123456"}

    Validates the OTP.  On success:
    - Clears otp_code and otp_created_at on the profile.
    - If the profile was freshly created (is_verified=False, no display_name):
        returns is_new_user=true so Flutter routes to Profile Setup.
    - If the account already completed setup:
        returns is_new_user=false so Flutter routes straight to Home.
    - Issues a fresh JWT pair in both cases.
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data["phone_number"]
        otp_code = serializer.validated_data["otp_code"]

        try:
            profile = UserProfile.objects.select_related("user").get(
                phone_number=phone
            )
        except UserProfile.DoesNotExist:
            return Response(
                {"error": "No account found for that phone number."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # -----------------------------------------------------------------
        # OTP validation
        # -----------------------------------------------------------------
        if not profile.otp_code:
            return Response(
                {"error": "No verification code was requested. Please request a new one."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if profile.otp_code != otp_code:
            return Response(
                {"error": "Invalid verification code."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if profile.otp_created_at is None or timezone.now() > profile.otp_created_at + timedelta(
            minutes=OTP_EXPIRY_MINUTES
        ):
            return Response(
                {"error": "Verification code has expired. Please request a new one."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # -----------------------------------------------------------------
        # Success — clear OTP and mark verified
        # -----------------------------------------------------------------
        # Read the flag before clearing so we can return the right value.
        is_new_user = not profile.profile_setup_completed
        _clear_otp(profile)

        return Response(
            {
                "message": "Phone verified successfully.",
                "is_new_user": is_new_user,
                **_tokens_for_user(profile.user),
            },
            status=status.HTTP_200_OK,
        )


# ---------------------------------------------------------------------------
# Profile setup (authenticated — token issued by VerifyOTPView)
# ---------------------------------------------------------------------------

class ProfileSetupView(generics.UpdateAPIView):
    """
    PATCH /api/auth/profile-setup/

    Requires Bearer token.  Sets the user's public username on Django User
    and stores display_name / avatar_url on UserProfile.  Marks
    profile_setup_completed so subsequent sign-ins skip profile setup.
    """

    queryset = UserProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = ProfileSetupSerializer

    def get_object(self):
        return self.request.user.profile

    def perform_update(self, serializer):
        instance = serializer.save()
        instance.profile_setup_completed = True
        instance.save(update_fields=["profile_setup_completed"])


# ---------------------------------------------------------------------------
# Current-user info
# ---------------------------------------------------------------------------

class CurrentUserView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)


# ---------------------------------------------------------------------------
# Hub / Message / User viewsets (unchanged)
# ---------------------------------------------------------------------------

class UserViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = User.objects.all().order_by("-date_joined")
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]


class HubViewSet(viewsets.ModelViewSet):
    queryset = Hub.objects.all().order_by("-created_at")
    serializer_class = HubSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(creator=self.request.user)


class MessageViewSet(viewsets.ModelViewSet):
    queryset = Message.objects.all().order_by("-timestamp")
    serializer_class = MessageSerializer
    permission_classes = [IsHubCreatorOrReadOnly]

    def perform_create(self, serializer):
        hub = serializer.save(creator=self.request.user)
        HubMember.objects.create(hub=hub, user=self.request.user, role="admin")
