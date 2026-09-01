import uuid
import logging
from datetime import timedelta

from django.contrib.auth.models import User
from django.db import transaction
from django.db.models import Case, IntegerField, Q, Value, When
from django.utils import timezone
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView  # noqa: F401 — re-exported
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

from .models import (
    DirectConversation,
    DirectMessageAttachment,
    DirectMessage,
    Broadcast,
    Hub,
    HubInvite,
    HubMeeting,
    HubMember,
    HubSection,
    Message,
    MessageAttachment,
    OtpDeliveryLog,
    SMSDelivery,
    Resource,
    TaskItem,
    UserProfile,
    DeviceToken,
    AppNotification,
)
from .permissions import CanCreateHubs, IsHubCreatorOrReadOnly
from .serializers import (
    BroadcastCreateSerializer,
    BroadcastSerializer,
    CampuzUserSerializer,
    DirectConversationSerializer,
    DirectMessageSerializer,
    HubMembershipActionSerializer,
    HubMeetingCreateSerializer,
    HubMeetingSerializer,
    HubInviteSerializer,
    HubMemberSerializer,
    HubSectionSerializer,
    TaskCreateSerializer,
    TaskGradeSerializer,
    TaskSerializer,
    TaskSubmitSerializer,
    HubSerializer,
    MessageSerializer,
    MessageAttachmentSerializer,
    ResourceCreateSerializer,
    ResourceSerializer,
    OTP_RESEND_COOLDOWN_SECONDS,
    ProfileSetupSerializer,
    RequestOTPSerializer,
    UserSerializer,
    VerifyOTPSerializer,
    DeviceTokenSerializer,
    AppNotificationSerializer,
    _clear_otp,
    _mark_otp_requested,
)
from .services import broadcast_sms_service, hub_sms_service, sms_service
from .services.push_service import send_push_notification
from .services.deadline_extractor import extract_deadline


logger = logging.getLogger(__name__)


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


def _request_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _make_invite_code() -> str:
    return uuid.uuid4().hex[:12].upper()


def _normalize_sms_status(raw_status: str | None) -> tuple[str, str]:
    status = (raw_status or "").strip().upper()
    if status in {"DELIVERED", "SUBMITTED", "QUEUED"}:
        return SMSDelivery.STATUS_SENT, status
    if status in {"NOT_DELIVERED", "PROHIBITED", "EXPIRED", "FAILED"}:
        return SMSDelivery.STATUS_FAILED, status
    return SMSDelivery.STATUS_SENT, status or "UNKNOWN"


class HubMessagePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class BroadcastPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50

class TaskPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class DirectMessagePagination(PageNumberPagination):
    page_size = 20


class HubMeetingPagination(PageNumberPagination):
    page_size = 10
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
        full_name = (serializer.validated_data.get("full_name") or "").strip()

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
            if full_name:
                profile.full_name = full_name
                profile.save(update_fields=["phone_number", "full_name"])
            else:
                profile.save(update_fields=["phone_number"])
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
            result = sms_service.send_otp(phone)
            if not isinstance(result, dict):
                result = {
                    "success": True,
                    "provider_message_id": None,
                    "response": {},
                    "error_message": None,
                }
            response_data = result.get("response")
            if not isinstance(response_data, dict):
                response_data = {}
            provider_status = None
            nested = response_data.get("data")
            if isinstance(nested, dict):
                provider_status = (
                    response_data.get("status")
                    or response_data.get("code")
                    or nested.get("status")
                    or None
                )
            provider_message_id = result.get("provider_message_id")
            if provider_message_id is not None:
                provider_message_id = str(provider_message_id)
            OtpDeliveryLog.objects.create(
                profile=profile,
                phone_number=phone,
                status="accepted" if result.get("success") else "failed",
                provider_message_id=provider_message_id,
                provider_status=str(provider_status).strip() if provider_status else None,
                error_message=result.get("error_message"),
                response_data=response_data,
            )
            if not result.get("success"):
                logger.error(
                    "[RequestOTPView] OTP send failed for %s: %s",
                    phone,
                    result.get("error_message") or "Unknown provider error",
                )
                return Response(
                    {"error": "Failed to send verification code. Please try again."},
                    status=status.HTTP_502_BAD_GATEWAY,
                )
            logger.info(
                "[RequestOTPView] OTP accepted for %s (provider_message_id=%s)",
                phone,
                result.get("provider_message_id") or "unknown",
            )
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


class SyncContactsView(APIView):
    """
    POST /api/users/sync-contacts/
    Body: {"phone_numbers": ["+1234567890", ...]}

    Returns registered Campuz users (excluding the requester) whose
    phone numbers match the provided list.
    """

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        phone_numbers = request.data.get("phone_numbers", [])
        if not isinstance(phone_numbers, list):
            return Response(
                {"error": "phone_numbers must be a list of strings."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Normalize phone numbers - removing spaces, dashes, parentheses
        # In a real app we'd use phonenumbers library, but we'll do basic cleaning for now.
        cleaned_numbers = []
        for num in phone_numbers:
            clean_num = ''.join(c for c in num if c.isdigit() or c == '+')
            if clean_num:
                cleaned_numbers.append(clean_num)

        qs = (
            User.objects.exclude(pk=self.request.user.pk)
            .filter(
                profile__is_verified=True,
                profile__profile_setup_completed=True,
                profile__phone_number__in=cleaned_numbers
            )
            .select_related("profile")
        )

        serializer = CampuzUserSerializer(qs, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


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
        ).select_related("user_1__profile", "user_2__profile").order_by("-updated_at")
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
    pagination_class = DirectMessagePagination

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
        messages = conversation.messages.select_related("sender__profile").order_by(
            "-timestamp", "-id"
        ).prefetch_related("attachments")
        messages.exclude(sender=request.user).filter(is_read=False).update(is_read=True)
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(messages, request, view=self)
        serializer = DirectMessageSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    @transaction.atomic
    def post(self, request, conversation_id):
        conversation = self._conversation(request, conversation_id)
        if conversation is None:
            return Response(
                {"error": "Conversation not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        content = str(request.data.get("content", "")).strip()
        attachments = request.FILES.getlist("attachments")
        if not content and not attachments:
            return Response(
                {"error": "Message content or an attachment is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        message = DirectMessage.objects.create(
            conversation=conversation,
            sender=request.user,
            content=content,
        )
        for upload in attachments:
            DirectMessageAttachment.objects.create(
                message=message,
                file=upload,
                file_name=getattr(upload, "name", "attachment"),
                mime_type=getattr(upload, "content_type", None),
                size_bytes=getattr(upload, "size", None),
            )
        conversation.updated_at = timezone.now()
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
        
        default_sections = [
            ("General Chat", "general", "General discussion and chat", 1),
            ("Announcements", "announcements", "Important updates from admins", 2),
            ("Resources", "resources", "Shared files and links", 3),
            ("Tasks", "tasks", "Assignments and to-dos", 4),
            ("Live Sessions", "meetings", "Upcoming meetings and classes", 5),
        ]
        sections_to_create = []
        for title, sec_type, desc, order in default_sections:
            sections_to_create.append(
                HubSection(
                    hub=hub,
                    title=title,
                    section_type=sec_type,
                    description=desc,
                    order=order,
                    is_enabled=True,
                )
            )
        HubSection.objects.bulk_create(sections_to_create)


class BroadcastViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Broadcast.objects.all()
    serializer_class = BroadcastSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = (
            Broadcast.objects.select_related(
                "hub",
                "sender",
                "sender__profile",
            ).prefetch_related("sms_deliveries")
            .annotate(
                priority_rank=Case(
                    When(priority="high", then=Value(0)),
                    When(priority="normal", then=Value(1)),
                    When(priority="low", then=Value(2)),
                    default=Value(3),
                    output_field=IntegerField(),
                )
            )
            .order_by("priority_rank", "-timestamp", "-id")
        )
        if self.request.user.is_superuser:
            return qs
        return qs.filter(hub__hub_members__user=self.request.user).distinct()


class HubMeetingViewSet(viewsets.ModelViewSet):
    queryset = HubMeeting.objects.all()
    serializer_class = HubMeetingSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = HubMeetingPagination

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.select_related("creator", "creator__profile").filter(pk=hub_id).first()

    def _ensure_admin(self, hub_id: int) -> bool:
        if self.request.user.is_superuser:
            return True
        return _is_hub_admin(self.request.user, hub_id)

    def _ensure_member(self, hub_id: int) -> bool:
        if self.request.user.is_superuser:
            return True
        return _is_hub_member(self.request.user, hub_id)

    def _requested_hub_id(self) -> int | None:
        raw_hub_id = (
            self.kwargs.get("hub_id")
            or self.request.query_params.get("hub")
            or self.request.query_params.get("hub_id")
        )
        if raw_hub_id in (None, ""):
            return None
        try:
            return int(raw_hub_id)
        except (TypeError, ValueError):
            return None

    def get_queryset(self):
        qs = (
            HubMeeting.objects.select_related(
                "hub",
                "hub__creator",
                "hub__creator__profile",
                "created_by",
                "created_by__profile",
            )
            .filter(scheduled_for__gte=timezone.now())
            .order_by("scheduled_for", "-created_at", "-id")
        )

        hub_id = self._requested_hub_id()
        if hub_id is not None:
            if not self._ensure_member(hub_id):
                return qs.none()
            return qs.filter(hub_id=hub_id)

        if self.request.user.is_superuser:
            return qs

        return qs.filter(hub__hub_members__user=self.request.user).distinct()

    def list(self, request, *args, **kwargs):
        hub_id = self._requested_hub_id()
        if hub_id is not None and not self._ensure_member(hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        queryset = self.get_queryset()
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(queryset, request, view=self)
        serializer = self.get_serializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_member(instance.hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        return super().retrieve(request, *args, **kwargs)

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        hub_id = kwargs.get("hub_id") or request.data.get("hub")
        if not hub_id:
            return Response(
                {"error": "hub_id is required in the URL."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            hub_id = int(hub_id)
        except (TypeError, ValueError):
            return Response(
                {"error": "hub_id must be a valid integer."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not self._ensure_member(hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        if not self._ensure_admin(hub_id):
            return Response(
                {"error": "Only Hub admins can create meetings."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = HubMeetingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        meeting = HubMeeting.objects.create(
            hub=hub,
            created_by=request.user,
            title=serializer.validated_data["title"],
            description=serializer.validated_data.get("description", ""),
            meeting_url=serializer.validated_data["meeting_url"],
            scheduled_for=serializer.validated_data["scheduled_for"],
        )
        return Response(
            HubMeetingSerializer(meeting, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update meetings."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    @transaction.atomic
    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update meetings."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().partial_update(request, *args, **kwargs)

    @transaction.atomic
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can delete meetings."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)


class ResourceViewSet(viewsets.ModelViewSet):
    queryset = Resource.objects.all()
    serializer_class = ResourceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = (
            Resource.objects.select_related(
                "hub",
                "hub__creator",
                "hub__creator__profile",
                "uploaded_by",
                "uploaded_by__profile",
            )
            .order_by("-upload_date", "-id")
        )

        if self.request.user.is_superuser:
            return self._apply_filters(qs)

        qs = qs.filter(hub__hub_members__user=self.request.user).distinct()
        return self._apply_filters(qs)

    def _apply_filters(self, qs):
        hub_id = self.kwargs.get("hub_id")
        if hub_id:
            qs = qs.filter(hub_id=hub_id)
        query = self.request.query_params.get("q", "").strip()
        resource_type = self.request.query_params.get("type", "").strip().lower()
        if query:
            qs = qs.filter(
                Q(title__icontains=query)
                | Q(url__icontains=query)
                | Q(resource_type__icontains=query)
            )
        if resource_type and resource_type != "all":
            qs = qs.filter(resource_type=resource_type)
        return qs

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.select_related("creator", "creator__profile").filter(pk=hub_id).first()

    def _ensure_membership(self, hub_id: int):
        if self.request.user.is_superuser:
            return True
        return _is_hub_member(self.request.user, hub_id)

    def _ensure_admin(self, hub_id: int):
        if self.request.user.is_superuser:
            return True
        return _is_hub_admin(self.request.user, hub_id)

    def list(self, request, *args, **kwargs):
        hub_id = kwargs.get("hub_id")
        if hub_id and not self._ensure_membership(int(hub_id)):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        return super().list(request, *args, **kwargs)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_membership(instance.hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        return super().retrieve(request, *args, **kwargs)

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        hub_id = kwargs.get("hub_id") or request.data.get("hub")
        if not hub_id:
            return Response(
                {"error": "hub_id is required in the URL."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        hub = self._hub_or_404(int(hub_id))
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        if not self._ensure_admin(int(hub_id)):
            return Response(
                {"error": "Only Hub admins can upload resources."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = ResourceCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        file_obj = serializer.validated_data.get("file") or request.FILES.get("file")
        url_val = (serializer.validated_data.get("url") or "").strip()

        resource = Resource.objects.create(
            hub=hub,
            uploaded_by=request.user,
            title=serializer.validated_data.get("title", ""),
            url=url_val,
            resource_type=serializer.validated_data.get("resource_type", "other"),
            file=file_obj,
        )
        if file_obj and not url_val:
            resource.url = resource.file.url if resource.file else ""
            resource.save(update_fields=["url"])
        read_serializer = ResourceSerializer(resource, context={"request": request})
        return Response(read_serializer.data, status=status.HTTP_201_CREATED)

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update resources."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    @transaction.atomic
    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update resources."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().partial_update(request, *args, **kwargs)

    @transaction.atomic
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can delete resources."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)


class TaskViewSet(viewsets.ModelViewSet):
    queryset = TaskItem.objects.all()
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = TaskPagination

    def get_queryset(self):
        qs = (
            TaskItem.objects.select_related(
                "hub",
                "hub__creator",
                "hub__creator__profile",
                "assigned_to",
                "assigned_to__profile",
                "graded_by",
                "graded_by__profile",
            )
            .order_by("due_date", "-updated_at", "-id")
        )
        hub_id = self.kwargs.get("hub_id")
        if hub_id:
            hub_id_int = int(hub_id)
            if not _is_hub_member(self.request.user, hub_id_int):
                return qs.none()
            if not _is_hub_admin(self.request.user, hub_id_int):
                return qs.filter(hub_id=hub_id_int, assigned_to=self.request.user)
            qs = qs.filter(hub_id=hub_id_int)
        status_filter = self.request.query_params.get("status", "").strip().lower()
        if status_filter and status_filter != "all":
            qs = qs.filter(status=status_filter)
        mine = self.request.query_params.get("mine", "").strip().lower()
        if mine in {"1", "true", "yes", "on"}:
            qs = qs.filter(assigned_to=self.request.user)
        elif not self.request.user.is_superuser and not hub_id:
            qs = qs.filter(assigned_to=self.request.user)
        return qs

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.select_related("creator", "creator__profile").filter(pk=hub_id).first()

    def _ensure_membership(self, hub_id: int) -> bool:
        if self.request.user.is_superuser:
            return True
        return _is_hub_member(self.request.user, hub_id)

    def _ensure_admin(self, hub_id: int) -> bool:
        if self.request.user.is_superuser:
            return True
        return _is_hub_admin(self.request.user, hub_id)

    def list(self, request, *args, **kwargs):
        hub_id = kwargs.get("hub_id")
        if hub_id and not self._ensure_membership(int(hub_id)):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        qs = self.get_queryset()
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(qs, request, view=self)
        serializer = self.get_serializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.hub_id and not self._ensure_membership(instance.hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        if not request.user.is_superuser:
            membership = (
                instance.hub.hub_members.filter(user=request.user).first()
                if instance.hub_id
                else None
            )
            if membership is None and instance.assigned_to_id != request.user.id:
                return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        return super().retrieve(request, *args, **kwargs)

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        hub_id = kwargs.get("hub_id") or request.data.get("hub")
        if not hub_id:
            return Response(
                {"error": "hub_id is required in the URL."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        hub = self._hub_or_404(int(hub_id))
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        if not self._ensure_admin(int(hub_id)):
            return Response(
                {"error": "Only Hub admins can create tasks."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = TaskCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            assignee = User.objects.select_related("profile").get(
                pk=serializer.validated_data["assigned_to_id"]
            )
        except User.DoesNotExist:
            return Response(
                {"error": "Assigned user not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not _is_hub_member(assignee, int(hub_id)):
            return Response(
                {"error": "Assigned user is not a member of this hub."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        task = TaskItem.objects.create(
            hub=hub,
            title=serializer.validated_data["title"],
            description=serializer.validated_data.get("description", ""),
            course_name=serializer.validated_data["course_name"],
            due_date=serializer.validated_data["due_date"],
            status="pending",
            assigned_to=assignee,
        )
        return Response(
            TaskSerializer(task, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update tasks."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    @transaction.atomic
    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can update tasks."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().partial_update(request, *args, **kwargs)

    @transaction.atomic
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if not self._ensure_admin(instance.hub_id):
            return Response(
                {"error": "Only Hub admins can delete tasks."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def submit(self, request, pk=None):
        task = self.get_object()
        if task.assigned_to_id != request.user.id and not request.user.is_superuser:
            return Response(
                {"error": "You can only submit tasks assigned to you."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = TaskSubmitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        task.submission_text = serializer.validated_data.get("submission_text", "")
        task.submission_link = serializer.validated_data.get("submission_link", "")
        task.status = "submitted"
        task.submitted_at = timezone.now()
        task.save(
            update_fields=[
                "submission_text",
                "submission_link",
                "status",
                "submitted_at",
                "updated_at",
            ]
        )
        return Response(
            TaskSerializer(task, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def grade(self, request, pk=None):
        task = self.get_object()
        if not self._ensure_admin(task.hub_id):
            return Response(
                {"error": "Only Hub admins can grade tasks."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = TaskGradeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        task.grade = serializer.validated_data["grade"]
        task.feedback = serializer.validated_data.get("feedback", "")
        task.status = "graded"
        task.graded_by = request.user
        task.graded_at = timezone.now()
        task.save(
            update_fields=[
                "grade",
                "feedback",
                "status",
                "graded_by",
                "graded_at",
                "updated_at",
            ]
        )
        return Response(
            TaskSerializer(task, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )


class HubBroadcastView(APIView):
    """
    Hub-scoped announcements / broadcasts.

    GET /api/hubs/<hub_id>/broadcasts/
    POST /api/hubs/<hub_id>/broadcasts/
    """

    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = BroadcastPagination

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.select_related("creator", "creator__profile").filter(pk=hub_id).first()

    def get(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        if not _is_hub_member(request.user, hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)

        qs = (
            Broadcast.objects.select_related(
                "hub",
                "sender",
                "sender__profile",
            ).prefetch_related("sms_deliveries")
            .filter(hub_id=hub_id)
            .annotate(
                priority_rank=Case(
                    When(priority="high", then=Value(0)),
                    When(priority="normal", then=Value(1)),
                    When(priority="low", then=Value(2)),
                    default=Value(3),
                    output_field=IntegerField(),
                )
            )
            .order_by("priority_rank", "-timestamp", "-id")
        )
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(qs, request, view=self)
        serializer = BroadcastSerializer(page, many=True, context={"request": request})
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
                {"error": "Only Hub admins can create broadcasts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = BroadcastCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        attachment = request.FILES.get("attachment")
        send_as_sms = bool(serializer.validated_data.get("send_as_sms"))
        if send_as_sms and attachment:
            return Response(
                {"error": "SMS delivery is only available for text-only broadcasts."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        broadcast = Broadcast.objects.create(
            hub=hub,
            sender=request.user,
            title=serializer.validated_data["title"],
            content=serializer.validated_data["content"],
            priority=serializer.validated_data["priority"],
            attachment=attachment,
        )
        eligible_sms_recipients = 0
        if send_as_sms:
            eligible_sms_recipients = broadcast_sms_service.count_eligible_recipients(
                broadcast
            )
            broadcast_sms_service.queue_broadcast_sms_delivery(broadcast.id)

        # 1. Extract deadline intelligently
        deadline = extract_deadline(broadcast.content)
        if deadline:
            try:
                TaskItem.objects.create(
                    hub=hub,
                    title=broadcast.title,
                    description=broadcast.content,
                    course_name="Broadcast Task",
                    due_date=deadline,
                    assigned_to=request.user,
                )
            except Exception as e:
                logger.error(f"Failed to create extracted task: {e}")

        # 2. Push Notifications
        for member in hub.members.exclude(id=request.user.id):
            send_push_notification(
                user=member,
                hub=hub,
                title=f"Broadcast: {broadcast.title}",
                body=broadcast.content[:100],
                data={"hub_id": str(hub.id), "type": "broadcast"}
            )

        response = BroadcastSerializer(broadcast, context={"request": request}).data
        response.update(
            {
                "send_as_sms": send_as_sms,
                "sms_delivery_queued": send_as_sms,
                "sms_tracking_enabled": bool(send_as_sms and eligible_sms_recipients > 0),
                "sms_eligible_recipients": eligible_sms_recipients,
                "extracted_deadline": deadline.isoformat() if deadline else None,
            }
        )
        return Response(response, status=status.HTTP_201_CREATED)


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
            if action != "add" and user_id is None:
                return Response(
                    {"error": "user_id is required for this action."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            target_user_id = user_id

        if action == "add":
            requested_ids = serializer.validated_data.get("user_ids") or (
                [target_user_id] if target_user_id is not None else []
            )
            if not requested_ids:
                return Response(
                    {"error": "At least one user_id is required for this action."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            users = (
                User.objects.select_related("profile")
                .filter(pk__in=requested_ids, profile__is_verified=True, profile__profile_setup_completed=True)
            )
            found_ids = {user.id for user in users}
            missing_ids = [user_id for user_id in requested_ids if user_id not in found_ids]
            if missing_ids:
                return Response(
                    {"error": "One or more users could not be added.", "missing_user_ids": missing_ids},
                    status=status.HTTP_404_NOT_FOUND,
                )

            for user in users:
                HubMember.objects.get_or_create(hub=hub, user=user, defaults={"role": "member"})

            members = (
                HubMember.objects.select_related("user", "user__profile")
                .filter(hub_id=hub_id)
                .order_by("-role", "user__profile__full_name", "user__profile__display_name", "user_id")
            )
            return Response(
                {
                    "message": "Members added successfully.",
                    "hub": HubSerializer(hub, context={"request": request}).data,
                    "members": HubMemberSerializer(
                        members, many=True, context={"request": request}
                    ).data,
                },
                status=status.HTTP_200_OK,
            )

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


class HubInviteView(APIView):
    """
    GET /api/hubs/<hub_id>/invites/
    POST /api/hubs/<hub_id>/invites/

    Hub admins can create or fetch a shareable invite link/QR payload.
    """

    permission_classes = (permissions.IsAuthenticated,)

    def _hub_or_404(self, hub_id: int) -> Hub | None:
        return Hub.objects.filter(pk=hub_id).first()

    def _require_admin(self, request, hub_id: int):
        if not _is_hub_admin(request.user, hub_id):
            return Response(
                {"error": "Only Hub admins can manage invitations."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return None

    def _current_invite(self, hub: Hub, request):
        invite = (
            HubInvite.objects.filter(
                hub=hub,
                is_active=True,
            )
            .order_by("-created_at", "-id")
            .first()
        )
        if invite is not None and not invite.is_expired and not invite.is_consumed:
            return invite
        return HubInvite.objects.create(
            hub=hub,
            code=_make_invite_code(),
            created_by=request.user,
            expires_at=timezone.now() + timedelta(days=30),
            is_active=True,
        )

    def get(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        if not _is_hub_member(request.user, hub_id):
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        invite = self._current_invite(hub, request)
        serializer = HubInviteSerializer(invite, context={"request": request})
        return Response(
            {
                "hub": HubSerializer(hub, context={"request": request}).data,
                "invite": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    @transaction.atomic
    def post(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        error = self._require_admin(request, hub_id)
        if error is not None:
            return error

        invite = HubInvite.objects.create(
            hub=hub,
            code=_make_invite_code(),
            created_by=request.user,
            expires_at=timezone.now() + timedelta(days=30),
            is_active=True,
        )
        serializer = HubInviteSerializer(invite, context={"request": request})
        return Response(
            {
                "message": "Invite created successfully.",
                "hub": HubSerializer(hub, context={"request": request}).data,
                "invite": serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )

    def delete(self, request, hub_id):
        hub = self._hub_or_404(hub_id)
        if hub is None:
            return Response({"error": "Hub not found."}, status=status.HTTP_404_NOT_FOUND)
        error = self._require_admin(request, hub_id)
        if error is not None:
            return error

        invites = HubInvite.objects.filter(hub=hub, is_active=True)
        count = invites.update(is_active=False)
        return Response(
            {"message": f"Revoked {count} active invite(s)."},
            status=status.HTTP_200_OK,
        )


class HubInviteJoinView(APIView):
    """
    POST /api/hub-invites/join/

    Body: {"code": "ABC123..."}
    """

    permission_classes = (permissions.IsAuthenticated,)

    @transaction.atomic
    def post(self, request):
        code = str(request.data.get("code", "")).strip().upper()
        if not code:
            return Response({"error": "Invite code is required."}, status=status.HTTP_400_BAD_REQUEST)

        invite = (
            HubInvite.objects.select_related("hub")
            .filter(code=code, is_active=True)
            .first()
        )
        if invite is None:
            return Response({"error": "This invite code is invalid."}, status=status.HTTP_404_NOT_FOUND)
        if invite.is_expired:
            return Response({"error": "This invite code has expired."}, status=status.HTTP_400_BAD_REQUEST)
        if invite.is_consumed:
            return Response({"error": "This invite code has already been used."}, status=status.HTTP_400_BAD_REQUEST)

        membership, created = HubMember.objects.get_or_create(
            hub=invite.hub,
            user=request.user,
            defaults={"role": "member"},
        )
        if not created and membership.role not in {"admin", "member"}:
            membership.role = "member"
            membership.save(update_fields=["role"])

        if created:
            invite.use_count += 1
            invite.save(update_fields=["use_count"])

        return Response(
            {
                "message": "You joined the hub successfully.",
                "hub": HubSerializer(invite.hub, context={"request": request}).data,
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
        parent_id = request.data.get("parent_id")
        parent = None
        if parent_id:
            try:
                parent = Message.objects.get(id=parent_id, hub=hub)
            except Message.DoesNotExist:
                pass
                
        attachments = request.FILES.getlist("attachments")
        send_as_sms = _request_bool(request.data.get("send_as_sms"))
        if send_as_sms and attachments:
            return Response(
                {"error": "SMS delivery is only available for text-only hub messages."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not content and not attachments:
            return Response(
                {"error": "Message content or an attachment is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        message = Message.objects.create(hub=hub, sender=request.user, content=content, parent=parent)
        for upload in attachments:
            MessageAttachment.objects.create(
                message=message,
                file=upload,
                file_name=getattr(upload, "name", "attachment"),
                mime_type=getattr(upload, "content_type", None),
                size_bytes=getattr(upload, "size", None),
            )
        eligible_sms_recipients = 0
        if send_as_sms:
            eligible_sms_recipients = hub_sms_service.count_eligible_recipients(message)
            hub_sms_service.queue_hub_sms_broadcast(message.id)
            
        # 1. Extract deadline intelligently
        deadline = extract_deadline(content)
        if deadline:
            try:
                TaskItem.objects.create(
                    hub=hub,
                    title=content[:50] + "..." if len(content) > 50 else content,
                    description=content,
                    course_name="Extracted Task",
                    due_date=deadline,
                    assigned_to=request.user,
                )
            except Exception as e:
                logger.error(f"Failed to create extracted task: {e}")

        # 2. Push Notifications
        sender_name = request.user.profile.display_name or request.user.profile.full_name or "Someone"
        for member in hub.members.exclude(id=request.user.id):
            send_push_notification(
                user=member,
                hub=hub,
                title=f"New message in {hub.name}",
                body=f"{sender_name}: {content[:100]}",
                data={"hub_id": str(hub.id), "type": "message"}
            )

        response_data = MessageSerializer(message, context={"request": request}).data
        response_data.update({
            "send_as_sms": send_as_sms,
            "sms_delivery_queued": send_as_sms,
            "sms_tracking_enabled": bool(send_as_sms and eligible_sms_recipients > 0),
            "eligible_sms_recipients": eligible_sms_recipients,
            "sms_eligible_recipients": eligible_sms_recipients,
            "extracted_deadline": deadline.isoformat() if deadline else None,
        })
        
        # Broadcast message to WebSocket group
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"hub_{hub_id}",
            {
                "type": "chat_message",
                "message": MessageSerializer(message, context={"request": request}).data
            }
        )
        
        return Response(response_data, status=status.HTTP_201_CREATED)


class SMSDeliveryWebhookView(APIView):
    """
    Arkesel sends sms_id and status in the query string. The endpoint must stay
    open so the provider can reach it.
    """

    permission_classes = (permissions.AllowAny,)

    def _payload_value(self, request, key: str) -> str:
        if request.method.upper() == "POST":
            value = request.data.get(key)
        else:
            value = request.query_params.get(key)
        return str(value or "").strip()

    @transaction.atomic
    def get(self, request):
        return self._handle(request)

    @transaction.atomic
    def post(self, request):
        return self._handle(request)

    def _handle(self, request):
        sms_id = self._payload_value(request, "sms_id")
        raw_status = self._payload_value(request, "status")

        if not sms_id:
            return Response(
                {"received": False, "error": "sms_id is required."},
                status=status.HTTP_200_OK,
            )

        if not raw_status:
            return Response(
                {"received": False, "error": "status is required."},
                status=status.HTTP_200_OK,
            )

        delivery = SMSDelivery.objects.select_for_update().filter(
            provider_message_id=sms_id
        ).first()
        if delivery is None:
            logger.warning(
                "[SMSDeliveryWebhookView] Unknown sms_id received: %s (%s)",
                sms_id,
                raw_status,
            )
            return Response({"received": True, "ignored": True}, status=status.HTTP_200_OK)

        normalized_status, provider_status = _normalize_sms_status(raw_status)
        delivery.provider_status = provider_status
        delivery.provider_status_at = timezone.now()
        delivery.provider_message_id = delivery.provider_message_id or sms_id

        if normalized_status == SMSDelivery.STATUS_FAILED:
            delivery.status = SMSDelivery.STATUS_FAILED
        elif delivery.status != SMSDelivery.STATUS_FAILED:
            delivery.status = SMSDelivery.STATUS_SENT

        update_fields = [
            "provider_status",
            "provider_status_at",
            "provider_message_id",
            "status",
            "updated_at",
        ]
        delivery.save(update_fields=update_fields)

        return Response(
            {
                "received": True,
                "message_id": delivery.message_id,
                "recipient_id": delivery.recipient_id,
                "local_status": delivery.status,
                "provider_status": delivery.provider_status,
            },
            status=status.HTTP_200_OK,
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


class DeviceTokenRegisterView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response({"error": "Token is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        DeviceToken.objects.update_or_create(
            user=request.user, token=token
        )
        return Response({"message": "Device token registered successfully."}, status=status.HTTP_200_OK)


class NotificationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = AppNotificationSerializer

    def get_queryset(self):
        return AppNotification.objects.filter(user=self.request.user).order_by("-created_at")


class NotificationReadStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request):
        notification_ids = request.data.get("notification_ids", [])
        if not notification_ids:
            return Response({"error": "notification_ids is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        AppNotification.objects.filter(
            id__in=notification_ids, user=request.user
        ).update(is_read=True)
        return Response({"message": "Notifications marked as read."}, status=status.HTTP_200_OK)


import hmac
import hashlib
import requests
from django.conf import settings
from rest_framework.permissions import AllowAny

class HubSmsTopUpInitializeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, hub_id):
        hub = self._hub_or_404(hub_id) if hasattr(self, '_hub_or_404') else Hub.objects.filter(id=hub_id).first()
        if not hub:
            return Response({"error": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)
        
        if not _is_hub_admin(request.user, hub_id):
            return Response({"error": "Only Hub admins can purchase SMS credits."}, status=status.HTTP_403_FORBIDDEN)
        
        bundle = request.data.get("bundle")
        bundles = {
            "100": 5,
            "500": 25,
            "1000": 50
        }
        
        if str(bundle) not in bundles:
            return Response({"error": "Invalid bundle selected."}, status=status.HTTP_400_BAD_REQUEST)
        
        amount_ghs = bundles[str(bundle)]
        amount_kobo = amount_ghs * 100
        
        headers = {
            "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
            "Content-Type": "application/json"
        }
        reference = f"topup_{hub_id}_{uuid.uuid4().hex[:10]}"
        data = {
            "email": request.user.email or "user@campuz.com",
            "amount": amount_kobo,
            "reference": reference,
            "callback_url": "https://campuz-api.onrender.com/payment/callback/",
            "metadata": {
                "hub_id": hub_id,
                "bundle_size": int(bundle),
                "user_id": request.user.id
            }
        }
        
        resp = requests.post("https://api.paystack.co/transaction/initialize", json=data, headers=headers)
        if resp.status_code == 200:
            return Response(resp.json()["data"], status=status.HTTP_200_OK)
        else:
            logger.error(f"Paystack initialize failed: {resp.text}")
            return Response({"error": "Payment initialization failed."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class HubSmsTopUpVerifyView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, hub_id):
        hub = Hub.objects.filter(id=hub_id).first()
        if not hub:
            return Response({"error": "Hub not found"}, status=status.HTTP_404_NOT_FOUND)
        if not _is_hub_admin(request.user, hub_id):
            return Response({"error": "Only admins can verify top-ups."}, status=status.HTTP_403_FORBIDDEN)
            
        reference = request.data.get("reference")
        if not reference:
            return Response({"error": "Reference is required."}, status=status.HTTP_400_BAD_REQUEST)
            
        headers = {
            "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
        }
        resp = requests.get(f"https://api.paystack.co/transaction/verify/{reference}", headers=headers)
        if resp.status_code == 200:
            try:
                data = resp.json().get("data", {})
                if data.get("status") == "success":
                    metadata = data.get("metadata", {})
                    if isinstance(metadata, str):
                        import json
                        try:
                            metadata = json.loads(metadata)
                        except json.JSONDecodeError:
                            metadata = {}
                    
                    bundle_size = metadata.get("bundle_size")
                    if bundle_size:
                        from .models import SmsCreditTransaction
                        if not SmsCreditTransaction.objects.filter(reference=reference).exists():
                            # Protect against None sms_credits
                            current_credits = hub.sms_credits if hub.sms_credits is not None else 50
                            hub.sms_credits = current_credits + int(bundle_size)
                            hub.save(update_fields=["sms_credits"])
                            SmsCreditTransaction.objects.create(
                                hub=hub,
                                transaction_type="credit",
                                amount=int(bundle_size),
                                reference=reference,
                                description=f"Paystack topup of {bundle_size} SMS credits"
                            )
                    return Response({"status": "success", "sms_credits": hub.sms_credits}, status=status.HTTP_200_OK)
                return Response({"status": "failed_or_pending"}, status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                import logging
                logging.getLogger(__name__).error(f"Error in verify_topup: {str(e)}")
                return Response({"error": f"Server error: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            return Response({"error": f"Paystack verification failed. Status: {resp.status_code}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class PaystackWebhookView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        secret = settings.PAYSTACK_SECRET_KEY
        signature = request.headers.get("x-paystack-signature")
        if not signature:
            return Response(status=status.HTTP_400_BAD_REQUEST)
            
        hash = hmac.new(secret.encode("utf-8"), request.body, hashlib.sha512).hexdigest()
        if hash != signature:
            return Response(status=status.HTTP_400_BAD_REQUEST)
            
        payload = request.data
        if payload.get("event") == "charge.success":
            data = payload.get("data", {})
            metadata = data.get("metadata", {})
            hub_id = metadata.get("hub_id")
            bundle_size = metadata.get("bundle_size")
            reference = data.get("reference")
            
            if hub_id and bundle_size:
                hub = Hub.objects.filter(id=hub_id).first()
                if hub:
                    from .models import SmsCreditTransaction
                    if not SmsCreditTransaction.objects.filter(reference=reference).exists():
                        hub.sms_credits += int(bundle_size)
                        hub.save(update_fields=["sms_credits"])
                        SmsCreditTransaction.objects.create(
                            hub=hub,
                            transaction_type="credit",
                            amount=int(bundle_size),
                            reference=reference,
                            description=f"Paystack topup of {bundle_size} SMS credits"
                        )
        return Response(status=status.HTTP_200_OK)

class AnalyticsView(APIView):
    """
    Returns real-time analytics for the current user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        hubs = Hub.objects.filter(members__user=user)
        total_hubs = hubs.count()
        total_messages = Message.objects.filter(sender=user).count()
        
        # Total members across all hubs the user is part of (excluding duplicates)
        total_peers = User.objects.filter(hubmember__hub__in=hubs).distinct().count()

        return Response({
            "total_hubs_joined": total_hubs,
            "total_messages_sent": total_messages,
            "total_peers_reached": total_peers,
            "active_now": 1, # Minimal placeholder
        })
