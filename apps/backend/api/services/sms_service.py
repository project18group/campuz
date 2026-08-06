"""
Arkesel SMS delivery service.

Usage:
    from api.services.sms_service import send_otp
    send_otp("+233201234567", "847291")

Environment variables:
    ARKESEL_API_KEY     — Arkesel v2 API key
    ARKESEL_SENDER_ID   — Registered sender name / number

When either variable is missing the OTP is printed to the console so
development and CI work without credentials.
"""

import logging
import os

import requests

logger = logging.getLogger(__name__)

_ARKESEL_SEND_URL = "https://sms.arkesel.com/api/v2/sms/send"


def send_otp(phone_number: str, otp_code: str) -> None:
    """Send a one-time password to *phone_number* via Arkesel SMS.

    Falls back to a console log when API credentials are absent so the
    development workflow is unaffected by missing environment variables.
    """
    api_key = os.getenv("ARKESEL_API_KEY", "").strip()
    sender_id = os.getenv("ARKESEL_SENDER_ID", "Campuz").strip()

    message = f"Your Campuz verification code is {otp_code}. It expires in 5 minutes."

    if not api_key:
        # Development / CI fallback — never log OTPs in production.
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. "
            "OTP for %s: %s",
            phone_number,
            otp_code,
        )
        print(f"[DEV] OTP for {phone_number}: {otp_code}")
        return

    payload = {
        "sender": sender_id,
        "message": message,
        "recipients": [phone_number],
    }
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
    }

    try:
        response = requests.post(
            _ARKESEL_SEND_URL,
            json=payload,
            headers=headers,
            timeout=10,
        )
        response.raise_for_status()
        logger.info("[sms_service] OTP dispatched to %s", phone_number)
    except requests.RequestException as exc:
        # Log and re-raise so the view can return an appropriate error to
        # the client without swallowing the root cause.
        logger.error(
            "[sms_service] Failed to send OTP to %s: %s",
            phone_number,
            exc,
        )
        raise
