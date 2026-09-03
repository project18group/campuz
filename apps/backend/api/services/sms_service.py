"""
Arkesel SMS service.

Usage:
    from api.services.sms_service import send_otp, verify_otp, send_sms
    send_otp("+233201234567")
    is_valid = verify_otp("+233201234567", "847291")
    send_sms("+233201234567", "Hello from Campuz")

Environment variables:
    ARKESEL_API_KEY - Arkesel API key
    ARKESEL_SENDER_ID - Registered sender name / number
    ARKESEL_SMS_CALLBACK_URL - Optional delivery webhook URL for SMS tracking.

When ARKESEL_API_KEY is missing, mock delivery is used for development
and CI without real credentials.
"""

from __future__ import annotations

import logging
import os
import uuid

import requests

logger = logging.getLogger(__name__)

_ARKESEL_OTP_GENERATE_URL = "https://sms.arkesel.com/api/otp/generate"
_ARKESEL_OTP_VERIFY_URL = "https://sms.arkesel.com/api/otp/verify"
_ARKESEL_SMS_SEND_URL = "https://sms.arkesel.com/api/v2/sms/send"
_DEV_MOCK_OTP = "123456"
_DEV_MOCK_SMS_ID = "mock-sms"


def _normalize_phone_number(phone_number: str) -> str:
    """Normalize a phone number for Arkesel's API."""
    return "".join(ch for ch in phone_number.strip() if ch.isdigit())


def send_otp(phone_number: str) -> dict:
    """Generate and send a 6-digit OTP to *phone_number* via Arkesel.

    Returns a structured result so callers can log whether Arkesel accepted the
    request without ever exposing the OTP itself.
    """
    api_key = os.getenv("ARKESEL_API_KEY", "").strip()
    sender_id = os.getenv("ARKESEL_SENDER_ID", "Campuz").strip()
    recipient = phone_number.strip()

    if not api_key:
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. Using mock OTP for %s",
            recipient,
        )
        return {
            "success": True,
            "provider_message_id": f"mock-otp-{uuid.uuid4().hex[:12]}",
            "response": {
                "status": "success",
                "data": {"recipient": recipient},
            },
            "error_message": None,
        }

    number = _normalize_phone_number(recipient)
    payload = {
        "expiry": 5,
        "length": 6,
        "medium": "sms",
        "message": "Your TekChat verification code is %otp_code%. It expires in 5 minutes. Do not share this code.",
        "number": number,
        "sender_id": sender_id,
        "type": "numeric",
    }
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        response = requests.post(
            _ARKESEL_OTP_GENERATE_URL,
            json=payload,
            headers=headers,
            timeout=10,
        )
    except requests.RequestException as exc:
        logger.error("[sms_service] Failed to send OTP to %s: %s", recipient, exc)
        return {
            "success": False,
            "provider_message_id": None,
            "response": {},
            "error_message": str(exc),
        }

    data = _safe_response_json(response)
    provider_message_id = None
    nested = data.get("data")
    if isinstance(nested, dict):
        provider_message_id = nested.get("id") or nested.get("message_id")
    provider_message_id = provider_message_id or data.get("id")
    provider_code = _provider_code(data)

    if 200 <= response.status_code < 300:
        if provider_code == "1000":
            logger.info(
                "[sms_service] OTP request accepted for %s (provider_message_id=%s)",
                recipient,
                provider_message_id or "unknown",
            )
            return {
                "success": True,
                "provider_message_id": provider_message_id,
                "response": data,
                "error_message": None,
            }

        error_message = _extract_sms_error_message(
            data,
            f"Arkesel OTP request returned unexpected provider code {provider_code or 'unknown'}.",
        )
        logger.error(
            "[sms_service] OTP request rejected for %s: %s",
            recipient,
            error_message,
        )
        return {
            "success": False,
            "provider_message_id": provider_message_id,
            "response": data,
            "error_message": error_message,
        }

    error_message = _extract_sms_error_message(
        data,
        f"Arkesel OTP request failed with status {response.status_code}.",
    )
    logger.error("[sms_service] Failed to send OTP to %s: %s", recipient, error_message)
    return {
        "success": False,
        "provider_message_id": provider_message_id,
        "response": data,
        "error_message": error_message,
    }


def verify_otp(phone_number: str, otp_code: str) -> bool:
    """Verify an OTP code against Arkesel's stored value."""
    api_key = os.getenv("ARKESEL_API_KEY", "").strip()

    if not api_key:
        is_valid = otp_code == _DEV_MOCK_OTP
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. Mock verification for %s: %s",
            phone_number,
            is_valid,
        )
        return is_valid

    number = _normalize_phone_number(phone_number)
    payload = {
        "code": otp_code,
        "number": number,
    }
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        response = requests.post(
            _ARKESEL_OTP_VERIFY_URL,
            json=payload,
            headers=headers,
            timeout=10,
        )
        if response.status_code == 200:
            data = response.json()
            is_valid = _provider_code(data) == "1100"
            logger.info(
                "[sms_service] OTP verification for %s: %s",
                phone_number,
                is_valid,
            )
            return is_valid
        logger.warning(
            "[sms_service] OTP verification failed for %s: HTTP %s",
            phone_number,
            response.status_code,
        )
        return False
    except requests.RequestException as exc:
        logger.error("[sms_service] Failed to verify OTP for %s: %s", phone_number, exc)
        return False


def _safe_response_json(response: requests.Response) -> dict:
    try:
        data = response.json()
        if isinstance(data, dict):
            return data
    except ValueError:
        pass
    return {"message": response.text}


def _extract_sms_error_message(data: dict, fallback: str) -> str:
    for key in ("error", "message", "detail"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    nested = data.get("data")
    if isinstance(nested, dict):
        for key in ("error", "message", "detail"):
            value = nested.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return fallback


def _provider_code(data: dict) -> str:
    """Extract Arkesel's provider code from the top-level or nested payload."""
    for key in ("code", "status"):
        value = data.get(key)
        if value is not None:
            text = str(value).strip()
            if text:
                return text

    nested = data.get("data")
    if isinstance(nested, dict):
        for key in ("code", "status"):
            value = nested.get(key)
            if value is not None:
                text = str(value).strip()
                if text:
                    return text

    return ""


def send_sms(
    phone_number: str,
    message: str,
    sender_id: str | None = None,
) -> dict:
    """Send a single SMS message via Arkesel.

    Returns a dictionary with:
        success: bool
        provider_message_id: str | None
        response: dict
        error_message: str | None
    """

    api_key = os.getenv("ARKESEL_API_KEY", "").strip()
    sender = (sender_id or os.getenv("ARKESEL_SENDER_ID", "Campuz")).strip()
    callback_url = os.getenv("ARKESEL_SMS_CALLBACK_URL", "").strip()
    recipient = phone_number.strip()
    content = message.strip()

    if not content:
        return {
            "success": False,
            "provider_message_id": None,
            "response": {},
            "error_message": "SMS content cannot be blank.",
        }

    if not api_key:
        mock_id = f"{_DEV_MOCK_SMS_ID}-{uuid.uuid4().hex[:12]}"
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. Mock SMS queued for %s",
            recipient,
        )
        return {
            "success": True,
            "provider_message_id": mock_id,
            "response": {
                "status": "success",
                "data": {"id": mock_id, "recipients": [recipient]},
            },
            "error_message": None,
        }

    payload = {
        "sender": sender,
        "message": content,
        "recipients": [recipient],
    }
    if callback_url:
        payload["callback_url"] = callback_url
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        response = requests.post(
            _ARKESEL_SMS_SEND_URL,
            json=payload,
            headers=headers,
            timeout=15,
        )
    except requests.RequestException as exc:
        logger.error("[sms_service] Failed to send SMS to %s: %s", recipient, exc)
        return {
            "success": False,
            "provider_message_id": None,
            "response": {},
            "error_message": str(exc),
        }

    data = _safe_response_json(response)
    provider_message_id = None
    nested = data.get("data")
    if isinstance(nested, dict):
        provider_message_id = nested.get("id") or nested.get("message_id")
    provider_message_id = provider_message_id or data.get("id")

    if 200 <= response.status_code < 300:
        status_value = str(data.get("status", "")).lower()
        code_value = str(data.get("code", "")).lower()
        success = status_value in {"success", "ok"} or code_value in {"success", "ok"}
        if not success and provider_message_id:
            success = True
        if success:
            logger.info("[sms_service] SMS dispatched to %s", recipient)
            return {
                "success": True,
                "provider_message_id": provider_message_id,
                "response": data,
                "error_message": None,
            }

    error_message = _extract_sms_error_message(
        data,
        f"Arkesel SMS request failed with status {response.status_code}.",
    )
    logger.error("[sms_service] SMS send failed for %s: %s", recipient, error_message)
    return {
        "success": False,
        "provider_message_id": provider_message_id,
        "response": data,
        "error_message": error_message,
    }
