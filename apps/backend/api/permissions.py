from rest_framework import permissions
from .models import HubMember


class IsHubCreatorOrReadOnly(permissions.BasePermission):
    """
    Hub-scoped write permission.
    Safe methods (GET, HEAD, OPTIONS) are allowed for any authenticated user.
    Write methods require the user to be an admin member of the target hub.
    """

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


class CanCreateHubs(permissions.BasePermission):
    """
    Global permission that grants access only to users who have redeemed
    a valid admin invitation code (profile.can_create_hubs == True).

    Superusers always pass.
    """

    message = "You need Hub Admin privileges to perform this action."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.user.is_superuser:
            return True

        try:
            return request.user.profile.can_create_hubs
        except AttributeError:
            return False
