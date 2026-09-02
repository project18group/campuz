from datetime import timedelta
from io import BytesIO
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image
from rest_framework.status import (
    HTTP_200_OK,
    HTTP_201_CREATED,
    HTTP_400_BAD_REQUEST,
    HTTP_403_FORBIDDEN,
    HTTP_404_NOT_FOUND,
    HTTP_429_TOO_MANY_REQUESTS,
)
from rest_framework.test import APITestCase, APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from api.models import (
    AdminInvitationCode,
    Broadcast,
    DirectMessage,
    Hub,
    HubInvite,
    HubMember,
    OtpDeliveryLog,
    Resource,
)


def _auth_client(_, user):
    client = APIClient()
    token = str(RefreshToken.for_user(user).access_token)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return client


def _make_verified_user(
    username: str,
    *,
    display_name: str | None = None,
    phone_number: str | None = None,
    can_create_hubs: bool = False,
):
    user = User.objects.create_user(username=username, password="test-pass-123")
    profile = user.profile
    profile.is_verified = True
    profile.profile_setup_completed = True
    profile.display_name = display_name or username
    profile.full_name = display_name or username
    profile.phone_number = phone_number
    profile.can_create_hubs = can_create_hubs
    profile.save()
    return user


class OTPAndAuthContractTests(APITestCase):
    def test_request_otp_creates_pending_profile_without_leaking_code(self):
        phone = "+233201000001"
        with patch("api.views.sms_service.send_otp") as send_otp:
            response = self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "Jane Doe"},
                format="json",
            )

        self.assertEqual(response.status_code, HTTP_200_OK)
        self.assertEqual(response.data["message"], "OTP sent")
        self.assertNotIn("otp_code", response.data)
        send_otp.assert_called_once_with(phone)

        from api.models import UserProfile

        profile = UserProfile.objects.get(phone_number=phone)
        self.assertFalse(profile.is_verified)
        self.assertIsNotNone(profile.otp_created_at)
        self.assertTrue(
            OtpDeliveryLog.objects.filter(
                profile=profile,
                phone_number=phone,
                status="accepted",
            ).exists()
        )

    def test_request_otp_resend_is_rate_limited(self):
        phone = "+233201000002"
        with patch("api.views.sms_service.send_otp"):
            first = self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "John Doe"},
                format="json",
            )
            second = self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "John Doe"},
                format="json",
            )

        self.assertEqual(first.status_code, HTTP_200_OK)
        self.assertEqual(second.status_code, HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("retry_after_seconds", second.data)

    def test_verify_otp_returns_tokens_and_clears_code(self):
        phone = "+233201000003"
        with patch("api.views.sms_service.send_otp"):
            self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "Jane Doe"},
                format="json",
            )

        with patch("api.views.sms_service.verify_otp", return_value=True):
            response = self.client.post(
                "/api/auth/verify-otp/",
                {"phone_number": phone, "otp_code": "123456"},
                format="json",
            )

        self.assertEqual(response.status_code, HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertTrue(response.data["is_new_user"])

        from api.models import UserProfile

        profile = UserProfile.objects.get(phone_number=phone)
        self.assertTrue(profile.is_verified)
        self.assertIsNone(profile.otp_code)
        self.assertIsNone(profile.otp_created_at)

    def test_profile_setup_redeems_admin_code_once(self):
        phone = "+233201000004"
        admin_code = AdminInvitationCode.objects.create(code="KNUST-CS-2026")

        with patch("api.views.sms_service.send_otp"):
            self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "Admin User"},
                format="json",
            )

        with patch("api.views.sms_service.verify_otp", return_value=True):
            auth_response = self.client.post(
                "/api/auth/verify-otp/",
                {"phone_number": phone, "otp_code": "123456"},
                format="json",
            )

        client = _auth_client(self.client, User.objects.get(profile__phone_number=phone))
        response = client.patch(
            "/api/auth/profile-setup/",
            {"display_name": "Admin User", "admin_code": admin_code.code},
            format="json",
        )

        self.assertEqual(response.status_code, HTTP_200_OK)
        self.assertEqual(response.data["display_name"], "Admin User")
        profile = User.objects.get(profile__phone_number=phone).profile
        self.assertTrue(profile.can_create_hubs)
        admin_code.refresh_from_db()
        self.assertTrue(admin_code.is_used)
        self.assertIsNotNone(auth_response.data["access"])

    def test_profile_setup_uses_default_network_avatar_and_supports_upload_remove(self):
        phone = "+233201000005"

        with patch("api.views.sms_service.send_otp"):
            self.client.post(
                "/api/auth/request-otp/",
                {"phone_number": phone, "full_name": "Avatar User"},
                format="json",
            )

        with patch("api.views.sms_service.verify_otp", return_value=True):
            self.client.post(
                "/api/auth/verify-otp/",
                {"phone_number": phone, "otp_code": "123456"},
                format="json",
            )

        client = _auth_client(self.client, User.objects.get(profile__phone_number=phone))

        default_response = client.patch(
            "/api/auth/profile-setup/",
            {"display_name": "Avatar User"},
            format="json",
        )
        self.assertEqual(default_response.status_code, HTTP_200_OK)
        self.assertIn("api.dicebear.com/10.x/initials/svg", default_response.data["avatar_url"])

        buffer = BytesIO()
        Image.new("RGB", (1, 1), color=(66, 135, 245)).save(buffer, format="PNG")
        upload = SimpleUploadedFile(
            "avatar.png",
            buffer.getvalue(),
            content_type="image/png",
        )
        upload_response = client.patch(
            "/api/auth/profile-setup/",
            {"avatar_file": upload},
            format="multipart",
        )
        self.assertEqual(upload_response.status_code, HTTP_200_OK)
        self.assertIn("/media/avatars/", upload_response.data["avatar_url"])

        remove_response = client.patch(
            "/api/auth/profile-setup/",
            {"remove_avatar": True},
            format="json",
        )
        self.assertEqual(remove_response.status_code, HTTP_200_OK)
        self.assertIn("api.dicebear.com/10.x/initials/svg", remove_response.data["avatar_url"])


class HubContractTests(APITestCase):
    def setUp(self):
        self.creator = _make_verified_user(
            "creator",
            display_name="Creator",
            phone_number="+233201111111",
            can_create_hubs=True,
        )
        self.member = _make_verified_user(
            "member",
            display_name="Member",
            phone_number="+233201111112",
        )
        self.other = _make_verified_user(
            "other",
            display_name="Other",
            phone_number="+233201111113",
        )
        self.creator_client = _auth_client(self.client, self.creator)

    def _create_hub(self):
        response = self.creator_client.post(
            "/api/hubs/",
            {"name": "CSC 301", "description": "Software Engineering"},
            format="json",
        )
        self.assertEqual(response.status_code, HTTP_201_CREATED)
        return Hub.objects.get(pk=response.data["id"])

    def test_hub_creator_becomes_admin(self):
        hub = self._create_hub()
        membership = HubMember.objects.get(hub=hub, user=self.creator)
        self.assertEqual(membership.role, "admin")
        self.assertEqual(hub.creator, self.creator)

    def test_multiple_admins_and_last_admin_protection(self):
        hub = self._create_hub()
        HubMember.objects.create(hub=hub, user=self.member, role="member")

        promote_response = self.creator_client.post(
            f"/api/hubs/{hub.id}/members/",
            {"action": "promote", "user_id": self.member.id},
            format="json",
        )
        self.assertEqual(promote_response.status_code, HTTP_200_OK)
        self.assertEqual(
            HubMember.objects.get(hub=hub, user=self.member).role,
            "admin",
        )

        leave_response = self.creator_client.post(
            f"/api/hubs/{hub.id}/members/",
            {"action": "leave"},
            format="json",
        )
        self.assertEqual(leave_response.status_code, HTTP_200_OK)
        self.assertFalse(HubMember.objects.filter(hub=hub, user=self.creator).exists())

        member_client = _auth_client(self.client, self.member)
        block_response = member_client.post(
            f"/api/hubs/{hub.id}/members/",
            {"action": "leave"},
            format="json",
        )
        self.assertEqual(block_response.status_code, HTTP_400_BAD_REQUEST)
        self.assertIn("at least one admin", block_response.data["error"])

    def test_member_cannot_manage_protected_features(self):
        hub = self._create_hub()
        HubMember.objects.create(hub=hub, user=self.member, role="member")
        member_client = _auth_client(self.client, self.member)

        cases = [
            (
                f"/api/hubs/{hub.id}/broadcasts/",
                {"title": "Update", "content": "Hello", "priority": "normal"},
            ),
            (
                f"/api/hubs/{hub.id}/resources/",
                {"title": "Slides", "url": "https://example.com", "resource_type": "link"},
            ),
            (
                f"/api/hubs/{hub.id}/tasks/",
                {
                    "title": "Assignment",
                    "course_name": "CSC 301",
                    "due_date": timezone.now().isoformat(),
                    "assigned_to_id": self.member.id,
                },
            ),
            (
                f"/api/hubs/{hub.id}/messages/",
                {"content": "Hello hub"},
            ),
        ]

        for path, payload in cases:
            with self.subTest(path=path):
                response = member_client.post(path, payload, format="json")
                self.assertIn(response.status_code, {HTTP_403_FORBIDDEN, HTTP_404_NOT_FOUND})

    def test_hub_message_sms_toggle_returns_tracking_flags(self):
        hub = self._create_hub()
        HubMember.objects.create(hub=hub, user=self.member, role="member")

        with patch("api.views.hub_sms_service.count_eligible_recipients", return_value=2), patch(
            "api.views.hub_sms_service.queue_hub_sms_broadcast"
        ) as queue_sms:
            response = self.creator_client.post(
                f"/api/hubs/{hub.id}/messages/",
                {"content": "Tomorrow lecture starts at 8:00 AM.", "send_as_sms": True},
                format="json",
            )

        self.assertEqual(response.status_code, HTTP_201_CREATED)
        self.assertTrue(response.data["sms_delivery_queued"])
        self.assertTrue(response.data["sms_tracking_enabled"])
        self.assertEqual(response.data["sms_eligible_recipients"], 2)
        queue_sms.assert_called_once()

    def test_resources_and_meetings_are_backend_driven(self):
        hub = self._create_hub()

        resource_response = self.creator_client.post(
            f"/api/hubs/{hub.id}/resources/",
            {
                "title": "Lecture Notes",
                "url": "https://example.com/notes.pdf",
                "resource_type": "pdf",
            },
            format="json",
        )
        self.assertEqual(resource_response.status_code, HTTP_201_CREATED)

        meeting_response = self.creator_client.post(
            "/api/meetings/",
            {
                "hub": hub.id,
                "title": "Weekly Lecture",
                "description": "Database systems session",
                "meeting_url": "https://zoom.us/j/123456789",
                "scheduled_for": (timezone.now() + timedelta(days=1)).isoformat(),
            },
            format="json",
        )
        self.assertEqual(meeting_response.status_code, HTTP_201_CREATED)

        resource_list = self.creator_client.get(f"/api/hubs/{hub.id}/resources/")
        self.assertEqual(resource_list.status_code, HTTP_200_OK)
        self.assertEqual(len(resource_list.data), 1)

        meeting_list = self.creator_client.get(f"/api/meetings/?hub={hub.id}")
        self.assertEqual(meeting_list.status_code, HTTP_200_OK)
        self.assertEqual(len(meeting_list.data["results"]), 1)

    def test_resource_file_upload_round_trip(self):
        hub = self._create_hub()
        upload = SimpleUploadedFile(
            "lecture-notes.pdf",
            b"%PDF-1.4 test upload",
            content_type="application/pdf",
        )

        response = self.creator_client.post(
            f"/api/hubs/{hub.id}/resources/",
            {
                "title": "Lecture Notes",
                "resource_type": "pdf",
                "file": upload,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, HTTP_201_CREATED)
        self.assertTrue(response.data["file"])
        self.assertEqual(response.data["title"], "Lecture Notes")
        self.assertEqual(response.data["resource_type"], "pdf")

    def test_broadcast_attachment_blocks_sms_only_path(self):
        hub = self._create_hub()
        upload = SimpleUploadedFile(
            "announcement.pdf",
            b"%PDF-1.4 broadcast upload",
            content_type="application/pdf",
        )

        response = self.creator_client.post(
            f"/api/hubs/{hub.id}/broadcasts/",
            {
                "title": "Lecture Update",
                "content": "Slides are attached.",
                "priority": "normal",
                "send_as_sms": True,
                "attachment": upload,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, HTTP_400_BAD_REQUEST)
        self.assertIn("text-only broadcasts", response.data["error"])

    def test_invites_can_be_created_and_joined(self):
        hub = self._create_hub()
        invite_response = self.creator_client.post(f"/api/hubs/{hub.id}/invites/")
        self.assertEqual(invite_response.status_code, HTTP_201_CREATED)
        invite_code = invite_response.data["invite"]["code"]
        self.assertTrue(HubInvite.objects.filter(code=invite_code, hub=hub).exists())

        member_client = _auth_client(self.client, self.member)
        join_response = member_client.post(
            "/api/hub-invites/join/",
            {"code": invite_code},
            format="json",
        )
        self.assertEqual(join_response.status_code, HTTP_200_OK)
        self.assertTrue(HubMember.objects.filter(hub=hub, user=self.member).exists())

    def test_admin_can_add_multiple_members(self):
        hub = self._create_hub()
        HubMember.objects.create(hub=hub, user=self.member, role="member")
        HubMember.objects.create(hub=hub, user=self.other, role="member")

        add_response = self.creator_client.post(
            f"/api/hubs/{hub.id}/members/",
            {"action": "add", "user_ids": [self.member.id, self.other.id]},
            format="json",
        )
        self.assertEqual(add_response.status_code, HTTP_200_OK)
        self.assertTrue(HubMember.objects.filter(hub=hub, user=self.member).exists())
        self.assertTrue(HubMember.objects.filter(hub=hub, user=self.other).exists())


class DirectMessageContractTests(APITestCase):
    def setUp(self):
        self.user_a = _make_verified_user(
            "user-a",
            display_name="User A",
            phone_number="+233201222221",
        )
        self.user_b = _make_verified_user(
            "user-b",
            display_name="User B",
            phone_number="+233201222222",
        )
        self.user_c = _make_verified_user(
            "user-c",
            display_name="User C",
            phone_number="+233201222223",
        )

    def test_direct_conversation_and_message_security(self):
        client_a = _auth_client(self.client, self.user_a)
        client_b = _auth_client(self.client, self.user_b)
        client_c = _auth_client(self.client, self.user_c)

        conversation_response = client_a.post(
            "/api/conversations/direct/",
            {"user_id": self.user_b.id},
            format="json",
        )
        self.assertIn(conversation_response.status_code, {HTTP_200_OK, HTTP_201_CREATED})
        conversation_id = conversation_response.data["id"]

        send_response = client_a.post(
            f"/api/conversations/direct/{conversation_id}/messages/",
            {"content": "Hello from A"},
            format="json",
        )
        self.assertEqual(send_response.status_code, HTTP_201_CREATED)
        self.assertEqual(send_response.data["content"], "Hello from A")
        self.assertFalse(send_response.data["is_read"])

        list_response = client_b.get(f"/api/conversations/direct/{conversation_id}/messages/")
        self.assertEqual(list_response.status_code, HTTP_200_OK)
        self.assertEqual(len(list_response.data["results"]), 1)

        message = DirectMessage.objects.get(pk=send_response.data["id"])
        message.refresh_from_db()
        self.assertTrue(message.is_read)

        outsider_response = client_c.get(f"/api/conversations/direct/{conversation_id}/messages/")
        self.assertEqual(outsider_response.status_code, HTTP_404_NOT_FOUND)

    def test_direct_message_attachment_upload_round_trip(self):
        client_a = _auth_client(self.client, self.user_a)

        conversation_response = client_a.post(
            "/api/conversations/direct/",
            {"user_id": self.user_b.id},
            format="json",
        )
        conversation_id = conversation_response.data["id"]

        upload = SimpleUploadedFile(
            "notes.pdf",
            b"%PDF-1.4 test",
            content_type="application/pdf",
        )
        message_response = client_a.post(
            f"/api/conversations/direct/{conversation_id}/messages/",
            {"content": "See attached", "attachments": upload},
            format="multipart",
        )

        self.assertEqual(message_response.status_code, HTTP_201_CREATED)
        self.assertTrue(message_response.data["has_attachments"])
        self.assertEqual(message_response.data["attachment_count"], 1)
        self.assertEqual(message_response.data["attachments"][0]["file_name"], "notes.pdf")

        list_response = client_a.get(f"/api/conversations/direct/{conversation_id}/messages/")
        self.assertEqual(list_response.status_code, HTTP_200_OK)
        self.assertEqual(list_response.data["results"][0]["attachments"][0]["file_name"], "notes.pdf")


class TokenRefreshTests(APITestCase):
    def test_token_refresh_returns_401_when_user_does_not_exist(self):
        # Create a user, generate a refresh token, and then delete the user
        user = _make_verified_user("ephemeral_user", phone_number="+233201999999")
        refresh = RefreshToken.for_user(user)
        refresh_str = str(refresh)
        user.delete()

        # Attempt to refresh the token for the deleted user
        response = self.client.post(
            "/api/token/refresh/",
            {"refresh": refresh_str},
            format="json",
        )
        # Should return 401 Unauthorized (or 401 with no_active_account / token_not_valid), NOT 500 Internal Server Error
        self.assertEqual(response.status_code, 401)

