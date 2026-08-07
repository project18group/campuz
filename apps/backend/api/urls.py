from django.urls import include, path
from rest_framework import routers
from rest_framework_simplejwt.views import TokenRefreshView

from . import views

router = routers.DefaultRouter()
router.register(r"users", views.UserViewSet)
router.register(r"hubs", views.HubViewSet)
router.register(r"messages", views.MessageViewSet)

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
    path("", include(router.urls)),
]
