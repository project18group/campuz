from django.contrib import admin

# Register your models here.

from .models import (
    UserProfile,
    Hub,
    HubMember,
    Message,
    Broadcast,
    Resource,
    TaskItem,
)

admin.site.register(UserProfile)
admin.site.register(Hub)
admin.site.register(HubMember)
admin.site.register(Message)
admin.site.register(Broadcast)
admin.site.register(Resource)
admin.site.register(TaskItem)
