"""
Hub SMS broadcast worker.

This module fans out a saved hub message to eligible hub members after the
database transaction commits. Normal message creation stays synchronous while
SMS delivery happens in the background.
"""

from __future__ import annotations

import logging
import threading

from django.contrib.auth.models import User
from django.db import close_old_connections, transaction
from django.utils import timezone

from api.models import HubMember, Message, SMSDelivery

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


def _build_sms_message(message: Message) -> str:
    hub_name = (message.hub.name or "Hub").strip() or "Hub"
    sender_name = _display_name(message.sender)
    content = message.content.strip()
    return f"Campuz | {hub_name} | {sender_name}: {content}"


def get_eligible_recipients(message: Message):
    members = (
        HubMember.objects.select_related("user", "user__profile")
        .filter(hub_id=message.hub_id)
        .exclude(user_id=message.sender_id)
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


def count_eligible_recipients(message: Message) -> int:
    return sum(1 for _ in get_eligible_recipients(message))


def queue_hub_sms_broadcast(message_id: int) -> None:
    """Queue SMS delivery for a hub message after the current transaction."""

    def _start_worker() -> None:
        thread = threading.Thread(
            target=_deliver_hub_sms,
            args=(message_id,),
            daemon=True,
        )
        thread.start()

    transaction.on_commit(_start_worker)


def _deliver_hub_sms(message_id: int) -> None:
    close_old_connections()
    try:
        message = (
            Message.objects.select_related("hub", "sender", "sender__profile")
            .filter(pk=message_id)
            .first()
        )
        if message is None:
            logger.warning("[hub_sms_service] Message %s not found", message_id)
            return

        recipients = list(get_eligible_recipients(message))
        if not recipients:
            logger.info(
                "[hub_sms_service] No eligible SMS recipients for message %s",
                message_id,
            )
            return

        sms_body = _build_sms_message(message)
        for recipient, phone_number in recipients:
            delivery = SMSDelivery.objects.create(
                message=message,
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
            "[hub_sms_service] Processed SMS broadcast for message %s to %s recipients",
            message_id,
            len(recipients),
        )
    except Exception as exc:  # pragma: no cover - safety net for worker errors
        logger.exception(
            "[hub_sms_service] Unexpected error while broadcasting message %s: %s",
            message_id,
            exc,
        )
    finally:
        close_old_connections()
