"""
SMS fan-out for hub broadcasts.
"""

from __future__ import annotations

import logging
import threading

from django.contrib.auth.models import User
from django.db import close_old_connections, transaction
from django.utils import timezone

from api.models import Broadcast, HubMember, SMSDelivery

from .sms_service import send_sms

logger = logging.getLogger(__name__)


def _display_name(user: User) -> str:
    profile = getattr(user, "profile", None)
    if profile is None:
        return user.username
    display_name = (profile.display_name or "").strip()
    if display_name:
        return display_name
    full_name = (profile.full_name or "").strip()
    return full_name or user.username


def _build_sms_message(broadcast: Broadcast) -> str:
    hub_name = (broadcast.hub.name or "Hub").strip() or "Hub"
    sender_name = _display_name(broadcast.sender)
    title = broadcast.title.strip()
    content = broadcast.content.strip()
    return f"Campuz | {hub_name} | {title} - {content} ({sender_name})"


def get_eligible_recipients(hub_id: int, sender_id: int):
    members = (
        HubMember.objects.select_related("user", "user__profile")
        .filter(hub_id=hub_id)
        .exclude(user_id=sender_id)
        .order_by("user_id")
    )
    for membership in members:
        profile = getattr(membership.user, "profile", None)
        if profile is None:
            continue
        phone_number = (profile.phone_number or "").strip()
        if not phone_number or not profile.is_verified:
            continue
        yield membership.user, phone_number


def count_eligible_recipients(hub_id: int, sender_id: int) -> int:
    return sum(1 for _ in get_eligible_recipients(hub_id, sender_id))


def queue_broadcast_sms_delivery(broadcast_id: int) -> None:
    def _start_worker() -> None:
        thread = threading.Thread(
            target=_deliver_broadcast_sms,
            args=(broadcast_id,),
            daemon=True,
        )
        thread.start()

    transaction.on_commit(_start_worker)


def _deliver_broadcast_sms(broadcast_id: int) -> None:
    close_old_connections()
    try:
        broadcast = (
            Broadcast.objects.select_related("hub", "sender", "sender__profile")
            .filter(pk=broadcast_id)
            .first()
        )
        if broadcast is None:
            logger.warning("[broadcast_sms_service] Broadcast %s not found", broadcast_id)
            return

        recipients = list(get_eligible_recipients(broadcast.hub_id, broadcast.sender_id))
        if not recipients:
            logger.info(
                "[broadcast_sms_service] No eligible SMS recipients for broadcast %s",
                broadcast_id,
            )
            return

        sms_body = _build_sms_message(broadcast)
        for recipient, phone_number in recipients:
            delivery = SMSDelivery.objects.create(
                broadcast=broadcast,
                recipient=recipient,
                phone_number=phone_number,
                status=SMSDelivery.STATUS_PENDING,
            )
            result = send_sms(phone_number=phone_number, message=sms_body)
            if result.get("success"):
                delivery.status = SMSDelivery.STATUS_SENT
                delivery.provider_message_id = result.get("provider_message_id")
                delivery.provider_status = "REQUEST_ACCEPTED"
                delivery.sent_at = timezone.now()
                delivery.error_message = None
                delivery.save(
                    update_fields=[
                        "status",
                        "provider_message_id",
                        "provider_status",
                        "sent_at",
                        "error_message",
                        "updated_at",
                    ]
                )
            else:
                delivery.status = SMSDelivery.STATUS_FAILED
                delivery.provider_message_id = result.get("provider_message_id")
                delivery.provider_status = "FAILED_TO_SEND"
                delivery.error_message = result.get("error_message") or "SMS delivery failed."
                delivery.save(
                    update_fields=[
                        "status",
                        "provider_message_id",
                        "provider_status",
                        "error_message",
                        "updated_at",
                    ]
                )

        logger.info(
            "[broadcast_sms_service] Processed SMS broadcast %s to %s recipients",
            broadcast_id,
            len(recipients),
        )
    except Exception as exc:  # pragma: no cover
        logger.exception(
            "[broadcast_sms_service] Unexpected error while broadcasting %s: %s",
            broadcast_id,
            exc,
        )
    finally:
        close_old_connections()
