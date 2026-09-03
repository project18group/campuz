import os
import logging

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:
    firebase_admin = None
    credentials = None
    messaging = None

from django.conf import settings
from api.models import DeviceToken, AppNotification, Hub

logger = logging.getLogger(__name__)

def get_firebase_app():
    # Only initialize if the credential file exists
    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if not cred_path or not os.path.exists(cred_path):
        return None

    try:
        app = firebase_admin.get_app()
    except ValueError:
        cred = credentials.Certificate(cred_path)
        app = firebase_admin.initialize_app(cred)
    return app

def send_push_notification(user, title: str, body: str, data: dict = None, hub: Hub = None) -> bool:
    """
    Sends a push notification to the given user and saves it to AppNotification.
    Returns True if at least one token successfully received the push.
    """
    # 1. Create the persistent notification in the DB
    AppNotification.objects.create(
        user=user,
        hub=hub,
        title=title,
        body=body,
    )

    # 2. Try to send via FCM
    app = get_firebase_app()
    if not app:
        logger.warning("Firebase app not initialized, skipping push notification.")
        return False

    tokens = list(DeviceToken.objects.filter(user=user).values_list("token", flat=True))
    if not tokens:
        return False
        
    if data is None:
        data = {}
        
    # Ensure all data values are strings for FCM
    str_data = {k: str(v) for k, v in data.items()}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=str_data,
        tokens=tokens,
    )

    try:
        response = messaging.send_multicast(message, app=app)
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    # Token might be invalid/unregistered, can delete it
                    DeviceToken.objects.filter(token=tokens[idx]).delete()
        return response.success_count > 0
    except Exception as e:
        logger.error(f"Error sending FCM multicast: {e}")
        return False
