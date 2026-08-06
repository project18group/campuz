from rest_framework import permissions
from .models import Hub


from rest_framework import permissions
from .models import HubMember


# Custom permission class to check if the user is the creator of the hub or has admin role in the hub.
class IsHubCreatorOrReadOnly(permissions.BasePermission):

    def has_permission(self, request, view):

        if not request.user or not request.user.is_authenticated:
            return False

        if request.method in permissions.SAFE_METHODS:
            return True

        if request.user.is_superuser:
            return True

        hub_id = request.data.get("hub")

        if not hub_id:
            return False

        return HubMember.objects.filter(
            hub_id=hub_id,
            user=request.user,
            role="admin",
        ).exists()
