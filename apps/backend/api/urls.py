from django.urls import include, path
from rest_framework import routers
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

router = routers.DefaultRouter()
router.register(r"users", views.UserViewSet)
router.register(r"hubs", views.HubViewSet)
router.register(r"messages", views.MessageViewSet)
router.register(r"broadcasts", views.BroadcastViewSet)
router.register(r"meetings", views.HubMeetingViewSet)
router.register(r"resources", views.ResourceViewSet)
router.register(r"tasks", views.TaskViewSet)
router.register(r"sections", views.HubSectionViewSet, basename="section")

urlpatterns = [
    path("api-auth/", include("rest_framework.urls", namespace="rest_framework")),

    # JWT — refresh only; obtain is handled by verify-otp
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),

    # Phone-OTP authentication
    path("auth/request-otp/", views.RequestOTPView.as_view(), name="request-otp"),
    path("auth/verify-otp/", views.VerifyOTPView.as_view(), name="verify-otp"),

    # Authenticated profile endpoints
    path("auth/me/", views.CurrentUserView.as_view(), name="current-user"),
    path("auth/profile-setup/", views.ProfileSetupView.as_view(), name="profile-setup"),

    # User discovery (contact search)
    path("users/search/", views.UserSearchView.as_view(), name="user-search"),

    # Direct conversations
    path("conversations/direct/", views.DirectConversationView.as_view(), name="direct-conversation"),
    path(
        "conversations/direct/<int:conversation_id>/messages/",
        views.DirectMessageView.as_view(),
        name="direct-message-list",
    ),

    # Hub sections (nested under hubs)
    path(
        "hubs/<int:hub_id>/sections/",
        views.HubSectionViewSet.as_view({"get": "list", "post": "create"}),
        name="hub-section-list",
    ),
    path(
        "hubs/<int:hub_id>/members/",
        views.HubMembershipView.as_view(),
        name="hub-members",
    ),
    path(
        "hubs/<int:hub_id>/invites/",
        views.HubInviteView.as_view(),
        name="hub-invites",
    ),
    path(
        "hubs/<int:hub_id>/messages/",
        views.HubMessageView.as_view(),
        name="hub-messages",
    ),
    path(
        "hubs/<int:hub_id>/resources/",
        views.ResourceViewSet.as_view({"get": "list", "post": "create"}),
        name="hub-resources",
    ),
    path(
        "hubs/<int:hub_id>/tasks/",
        views.TaskViewSet.as_view({"get": "list", "post": "create"}),
        name="hub-tasks",
    ),
    path(
        "hubs/<int:hub_id>/broadcasts/",
        views.HubBroadcastView.as_view(),
        name="hub-broadcasts",
    ),
    path(
        "hubs/<int:hub_id>/meetings/",
        views.HubMeetingViewSet.as_view({"get": "list", "post": "create"}),
        name="hub-meetings",
    ),
    path(
        "webhooks/sms/delivery/",
        views.SMSDeliveryWebhookView.as_view(),
        name="sms-delivery-webhook",
    ),
    path(
        "hub-invites/join/",
        views.HubInviteJoinView.as_view(),
        name="hub-invite-join",
    ),

    path("", include(router.urls)),
]
