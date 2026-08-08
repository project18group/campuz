"""
Arkesel OTP service.

Usage:
    from api.services.sms_service import send_otp, verify_otp
    send_otp("+233201234567")
    is_valid = verify_otp("+233201234567", "847291")

Environment variables:
    ARKESEL_API_KEY     — Arkesel API key
    ARKESEL_SENDER_ID   — Registered sender name / number

When ARKESEL_API_KEY is missing, a mock OTP (123456) is used for
development and CI without real credentials.
"""

import logging
import os

import requests

logger = logging.getLogger(__name__)

_ARKESEL_OTP_GENERATE_URL = "https://sms.arkesel.com/api/otp/generate"
_ARKESEL_OTP_VERIFY_URL = "https://sms.arkesel.com/api/otp/verify"
_DEV_MOCK_OTP = "123456"


def send_otp(phone_number: str) -> None:
    """Generate and send a 6-digit OTP to *phone_number* via Arkesel.

    Arkesel generates the OTP, stores it on their side with a 5-minute
    expiry, and dispatches it via SMS.

    Falls back to a mock OTP when API credentials are absent so the
    development workflow is unaffected by missing environment variables.
    """
    api_key = os.getenv("ARKESEL_API_KEY", "").strip()
    sender_id = os.getenv("ARKESEL_SENDER_ID", "TekChat").strip()

    if not api_key:
        # Development / CI fallback — never log OTPs in production.
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. Using mock OTP %s for %s",
            _DEV_MOCK_OTP,
            phone_number,
        )
        print(f"[DEV] Mock OTP for {phone_number}: {_DEV_MOCK_OTP}")
        return

    # Strip leading + if present (Arkesel expects raw digits)
    number = phone_number.lstrip("+")

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
    }

    try:
        response = requests.post(
            _ARKESEL_OTP_GENERATE_URL,
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


def verify_otp(phone_number: str, otp_code: str) -> bool:
    """Verify an OTP code against Arkesel's stored value.

    Returns True if the code is valid and not expired, False otherwise.

    In development mode (no API key), accepts the mock OTP only.
    """
    api_key = os.getenv("ARKESEL_API_KEY", "").strip()

    if not api_key:
        # Development / CI fallback
        is_valid = otp_code == _DEV_MOCK_OTP
        logger.warning(
            "[sms_service] ARKESEL_API_KEY not set. Mock verification for %s: %s",
            phone_number,
            is_valid,
        )
        return is_valid

    # Strip leading + if present
    number = phone_number.lstrip("+")

    payload = {
        "code": otp_code,
        "number": number,
    }
    headers = {
        "api-key": api_key,
        "Content-Type": "application/json",
    }

    try:
        response = requests.post(
            _ARKESEL_OTP_VERIFY_URL,
            json=payload,
            headers=headers,
            timeout=10,
        )
        # Arkesel returns 200 with code "1100" for success
        if response.status_code == 200:
            data = response.json()
            is_valid = data.get("code") == "1100"
            logger.info(
                "[sms_service] OTP verification for %s: %s (response: %s)",
                phone_number,
                is_valid,
                data,
            )
            return is_valid
        else:
            logger.warning(
                "[sms_service] OTP verification failed for %s: HTTP %s",
                phone_number,
                response.status_code,
            )
            return False
    except requests.RequestException as exc:
        logger.error(
            "[sms_service] Failed to verify OTP for %s: %s",
            phone_number,
            exc,
        )
        return False
