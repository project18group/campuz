from django.urls import include, path
from rest_framework import routers
from . import views
from rest_framework_simplejwt.views import TokenRefreshView

router = routers.DefaultRouter()
router.register(r'users', views.UserViewSet)
router.register(r'hubs', views.HubViewSet)
router.register(r'messages', views.MessageViewSet)

# Wire up our API using automatic URL routing.
# Additionally, we include login URLs for the browsable API.
urlpatterns = [
    path('', include(router.urls)),
    path('api-auth/', include('rest_framework.urls', namespace='rest_framework')),
    path('token/', views.VerifiedTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/me/', views.CurrentUserView.as_view(), name='current-user'),
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/verify-otp/', views.VerifyOTPView.as_view(), name='verify-otp'),
    path('auth/resend-otp/', views.ResendOTPView.as_view(), name='resend-otp'),
    path('auth/profile-setup/', views.ProfileSetupView.as_view(), name='profile-setup'),
]
