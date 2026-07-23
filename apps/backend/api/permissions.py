from rest_framework import permissions
from .models import Hub


class IsHubCreatorOrReadOnly(permissions.BasePermission):
    """
    Hub-scoped permission — mirrors how WhatsApp groups work:
    - Anyone can register with a single generic flow.
    - The user who CREATES a Hub becomes its admin (can broadcast messages).
    - Users who JOIN a Hub later are viewers (read-only, can react).
    - Superusers always have full access.
    """

    def has_permission(self, request, view):
        # All authenticated users can read (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            return request.user and request.user.is_authenticated

        # For write operations, check if the user is the creator of the target Hub
        if request.user and request.user.is_authenticated:
            if request.user.is_superuser:
                return True

            hub_id = request.data.get('hub')
            if hub_id:
                try:
                    hub = Hub.objects.get(pk=hub_id)
                    return hub.creator == request.user
                except Hub.DoesNotExist:
                    return False

        return False

