import uuid

from django.contrib.auth.models import User
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, status, viewsets
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView  # noqa: F401 — re-exported

from .models import DirectConversation, DirectMessage, Hub, HubMember, HubSection, Message, UserProfile
from .permissions import CanCreateHubs, IsHubCreatorOrReadOnly
from .serializers import (
    CampuzUserSerializer,
    DirectConversationSerializer,
    DirectMessageSerializer,
    HubMembershipActionSerializer,
    HubMemberSerializer,
    HubSectionSerializer,
    HubSerializer,
    MessageSerializer,
    OTP_RESEND_COOLDOWN_SECONDS,
    ProfileSetupSerializer,
    RequestOTPSerializer,
    UserSerializer,
    VerifyOTPSerializer,
    _clear_otp,
    _mark_otp_requested,
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


def _is_hub_member(user: User, hub_id: int) -> bool:
    if user.is_superuser:
        return True
    return HubMember.objects.filter(hub_id=hub_id, user=user).exists()


def _is_hub_admin(user: User, hub_id: int) -> bool:
    if user.is_superuser:
        return True
    return HubMember.objects.filter(hub_id=hub_id, user=user, role="admin").exists()


def _admin_count(hub_id: int) -> int:
    return HubMember.objects.filter(hub_id=hub_id, role="admin").count()


class HubMessagePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


# ---------------------------------------------------------------------------
# Phone-auth views
# ---------------------------------------------------------------------------

class RequestOTPView(APIView):
    """
    POST /api/auth/request-otp/

    Body: {"phone_number": "+233...", "full_name": "Jane Doe"}

    Triggers Arkesel OTP generation and SMS delivery. A 60-second resend
    cooldown is enforced.
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = RequestOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data["phone_number"]
        full_name = serializer.validated_data["full_name"]

        # Find or create a pending profile for this phone number.
        profile = UserProfile.objects.filter(phone_number=phone).first()

        if profile is None:
            username = _make_uuid_username()
            while User.objects.filter(username=username).exists():
                username = _make_uuid_username()

            user = User.objects.create_user(username=username, password=None)
            user.set_unusable_password()
            user.save()

            profile = UserProfile.objects.get(user=user)
            profile.phone_number = phone
            profile.full_name = full_name
            profile.save(update_fields=["phone_number", "full_name"])
        else:
            # Update full_name in case it changed (e.g. re-registering).
            if full_name and profile.full_name != full_name:
                profile.full_name = full_name
                profile.save(update_fields=["full_name"])

        # Resend cooldown check
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

        _mark_otp_requested(profile)
        try:
            sms_service.send_otp(phone)
        except Exception:
            return Response(
                {"error": "Failed to send verification code. Please try again."},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response({"message": "OTP sent"}, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    """
    POST /api/auth/verify-otp/

    Body: {"phone_number": "+233...", "otp_code": "123456"}

    Verifies OTP against Arkesel's stored value. On success: clears OTP,
    issues JWT pair, returns is_new_user flag.
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

        if profile.otp_created_at is None:
            return Response(
                {"error": "No verification code was requested. Please request a new one."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_valid = sms_service.verify_otp(phone, otp_code)
        if not is_valid:
            return Response(
                {"error": "Invalid or expired verification code."},
                status=status.HTTP_400_BAD_REQUEST,
            )

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

    Requires Bearer token. Sets display_name and optional avatar_url.
    Optionally redeems an AdminInvitationCode to grant can_create_hubs.
    Marks profile_setup_completed on success.
    """

    queryset = UserProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = ProfileSetupSerializer

    def get_object(self):
        return self.request.user.profile

    def perform_update(self, serializer):
        instance = serializer.save()
        if not instance.profile_setup_completed:
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
# User discovery (contact search)
# ---------------------------------------------------------------------------

class UserSearchView(generics.ListAPIView):
    """
    GET /api/users/search/?q=<query>

    Returns registered Campuz users (excluding the requester) whose
    full_name, display_name, or phone_number match the query.
    When no query is provided, returns all verified users (paginated).

    Only authenticated users may access this endpoint.
    """

    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = CampuzUserSerializer

    def get_queryset(self):
        query = self.request.query_params.get("q", "").strip()
        qs = (
            User.objects.exclude(pk=self.request.user.pk)
            .filter(
                profile__is_verified=True,
                profile__profile_setup_completed=True,
            )
            .select_related("profile")
            .order_by("profile__full_name", "profile__display_name")
        )
        if query:
            qs = qs.filter(
                Q(profile__full_name__icontains=query)
                | Q(profile__display_name__icontains=query)
                | Q(profile__phone_number__icontains=query)
            )
        return qs


# ---------------------------------------------------------------------------
# Direct conversations
# ---------------------------------------------------------------------------

class DirectConversationView(APIView):
    """
    POST /api/conversations/direct/
    Body: {"user_id": <int>}

    Returns an existing DirectConversation between the requester and
    user_id, or creates one.  Always returns 200 + conversation data.
    The `created` flag indicates whether a new conversation was made.

    GET /api/conversations/direct/
    Lists all direct conversations for the current user.
    """

    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        me = request.user
        conversations = DirectConversation.objects.filter(
            Q(user_1=me) | Q(user_2=me)
        ).select_related("user_1__profile", "user_2__profile").prefetch_related("messages")
        serializer = DirectConversationSerializer(
            conversations, many=True, context={"request": request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        other_id = request.data.get("user_id")
        if not other_id:
            return Response(
                {"error": "user_id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            other_user = User.objects.select_related("profile").get(
                pk=other_id,
                profile__is_verified=True,
                profile__profile_setup_completed=True,
            )
        except User.DoesNotExist:
            return Response(
                {"error": "User not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if other_user == request.user:
            return Response(
                {"error": "You cannot start a conversation with yourself."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        me = request.user
        # Enforce deterministic ordering to maintain the unique constraint.
        user_1, user_2 = (me, other_user) if me.pk < other_user.pk else (other_user, me)

        conversation, created = DirectConversation.objects.get_or_create(
            user_1=user_1,
            user_2=user_2,
        )

        serializer = DirectConversationSerializer(
            conversation, context={"request": request}
        )
        return Response(
            {"created": created, **serializer.data},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class DirectMessageView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def _conversation(self, request, conversation_id):
        return DirectConversation.objects.filter(
            Q(user_1=request.user) | Q(user_2=request.user),
            pk=conversation_id,
        ).first()

    def get(self, request, conversation_id):
        conversation = self._conversation(request, conversation_id)
        if conversation is None:
            return Response(
                {"error": "Conversation not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        messages = conversation.messages.select_related("sender__profile")
        messages.exclude(sender=request.user).filter(is_read=False).update(is_read=True)
        return Response(
            DirectMessageSerializer(
                messages,
                many=True,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    @transaction.atomic
    def post(self, request, conversation_id):
        conversation = self._conversation(request, conversation_id)
        if conversation is None:
            return Response(
                {"error": "Conversation not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        content = str(request.data.get("content", "")).strip()
        if not content:
            return Response(
                {"error": "Message content is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        message = DirectMessage.objects.create(
            conversation=conversation,
            sender=request.user,
            content=content,
        )
        conversation.save(update_fields=["updated_at"])
        return Response(
            DirectMessageSerializer(
                message,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


# ---------------------------------------------------------------------------
# Hub / Message / User viewsets
# ---------------------------------------------------------------------------

class UserViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = User.objects.all().order_by("-date_joined")
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]


class HubViewSet(viewsets.ModelViewSet):
    queryset = Hub.objects.all()
    serializer_class = HubSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = (
            Hub.objects.select_related("creator", "creator__profile")
            .prefetch_related("hub_members__user__profile", "sections")
            .order_by("-created_at")
        )
        if self.request.user.is_superuser:
            return qs
        return qs.filter(hub_members__user=self.request.user).distinct()

    def get_permissions(self):
        if self.action == "create":
            return [permissions.IsAuthenticated(), CanCreateHubs()]
        return super().get_permissions()

    @transaction.atomic
    def perform_create(self, serializer):
        hub = serializer.save(creator=self.request.user)
        HubMember.objects.get_or_create(
            hub=hub,
            user=self.request.user,
            defaults={"role": "admin"},
        )


class HubSectionViewSet(viewsets.ModelViewSet):
    """
    Manage sections within a Hub.

    List/Create: /api/hubs/<hub_id>/sections/
    Retrieve/Update/Delete: /api/sections/<id>/

    Only Hub admins can create/update/delete sections.
    All Hub members can view sections.
    """

    serializer_class = HubSectionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        hub_id = self.kwargs.get("hub_id")
        if hub_id:
            if not _is_hub_member(self.request.user, int(hub_id)):
                return HubSection.objects.none()
            return HubSection.objects.filter(hub_id=hub_id).select_related("hub")
        return (
            HubSection.objects.select_related("hub")
            .filter(hub__hub_members__user=self.request.user)
            .distinct()
        )

    def _is_hub_admin(self, hub_id: int) -> bool:
        """Check if the requesting user is an admin of the hub."""
        return _is_hub_admin(self.request.user, hub_id)

    def create(self, request, *args, **kwargs):
        hub_id = self.kwargs.get("hub_id")
        if not hub_id:
            return Response(
                {"error": "hub_id is required in the URL."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not self._is_hub_admin(hub_id):
            return Response(
                {"error": "Only Hub admins can create sections."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(hub_id=hub_id)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._is_hub_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update sections."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._is_hub_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update sections."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().partial_update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._is_hub_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can delete sections."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)


class HubMembershipView(APIView):
    """
    Manage hub membership and admin roles.

    GET /api/hubs/<hub_id>/members/
    POST /api/hubs/<hub_id>/members/  body: {"action": "...", "user_id": 1}
    """

    permission_classes = (permissions.IsAuthenticated,)

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.filter(pk=hub_id).first()

    def _member_or_404(self, hub_id: int, user_id: int) -> HubMember | None:
        return HubMember.objects.select_related("user", "user__profile").filter(
            hub_id=hub_id,
            user_id=user_id,
        ).first()

    def get(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _is_hub_member(request.user, hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        members = (
            HubMember.objects.select_related("user", "user__profile")
            .filter(hub_id=hub_id)
            .order_by("-role", "user__profile__full_name", "user__profile__display_name", "user_id")
        )
        serializer = HubMemberSerializer(members, many=True, context={"request": request})
        return Response(
            {
                "hub": HubSerializer(hub, context={"request": request}).data,
                "members": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    @transaction.atomic
    def post(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = HubMembershipActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        action = serializer.validated_data["action"]
        user_id = serializer.validated_data.get("user_id")

        if action == "leave":
            target_user_id = request.user.id
        else:
            if not _is_hub_admin(request.user, hub_id):
                return Response(
                    {"error": "Only Hub admins can manage members."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if user_id is None:
                return Response(
                    {"error": "user_id is required for this action."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            target_user_id = user_id

        membership = self._member_or_404(hub_id, target_user_id)
        if membership is None:
            return Response(
                {"error": "Hub member not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if action in {"demote", "remove", "leave"} and membership.role == "admin":
            if _admin_count(hub_id) <= 1:
                return Response(
                    {"error": "A hub must always have at least one admin."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        if action == "promote":
            if membership.role == "admin":
                return Response(
                    {"error": "This member is already an admin."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            membership.role = "admin"
            membership.save(update_fields=["role"])
        elif action == "demote":
            if membership.role != "admin":
                return Response(
                    {"error": "This member is already a normal member."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            membership.role = "member"
            membership.save(update_fields=["role"])
        elif action == "remove":
            membership.delete()
        elif action == "leave":
            membership.delete()
        else:
            return Response(
                {"error": "Unsupported membership action."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        members = (
            HubMember.objects.select_related("user", "user__profile")
            .filter(hub_id=hub_id)
            .order_by("-role", "user__profile__full_name", "user__profile__display_name", "user_id")
        )
        return Response(
            {
                "message": "Membership updated successfully.",
                "hub": HubSerializer(hub, context={"request": request}).data,
                "members": HubMemberSerializer(
                    members, many=True, context={"request": request}
                ).data,
            },
            status=status.HTTP_200_OK,
        )


class HubMessageView(APIView):
    """
    Hub-scoped discussion messages.

    GET /api/hubs/<hub_id>/messages/?page=1
    POST /api/hubs/<hub_id>/messages/

    Only hub members may read. Only hub admins may post.
    """

    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = HubMessagePagination

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.select_related("creator", "creator__profile").filter(pk=hub_id).first()

    def get(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _is_hub_member(request.user, hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        qs = (
            Message.objects.select_related("hub", "sender", "sender__profile")
            .filter(hub_id=hub_id)
            .order_by("-timestamp", "-id")
        )
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(qs, request, view=self)
        serializer = MessageSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    @transaction.atomic
    def post(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _is_hub_member(request.user, hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _is_hub_admin(request.user, hub_id):
            return Response(
                {"error": "Only Hub admins can send hub messages."},
                status=status.HTTP_403_FORBIDDEN,
            )

        content = str(request.data.get("content", "")).strip()
        if not content:
            return Response(
                {"error": "Message content is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        message = Message.objects.create(hub=hub, sender=request.user, content=content)
        return Response(
            MessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class MessageViewSet(viewsets.ModelViewSet):
    queryset = Message.objects.all()
    serializer_class = MessageSerializer
    permission_classes = [IsHubCreatorOrReadOnly]

    def get_queryset(self):
        qs = Message.objects.select_related("hub", "sender", "sender__profile").order_by(
            "-timestamp"
        )
        if self.request.user.is_superuser:
            return qs
        return qs.filter(hub__hub_members__user=self.request.user).distinct()

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user)
