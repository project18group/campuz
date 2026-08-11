import 'package:go_router/go_router.dart';
import 'package:mobile/screens/auth/views/phone_screen.dart';
import 'package:mobile/screens/auth/views/profile_setup_screen.dart';
import 'package:mobile/screens/auth/views/otp_screen.dart';
import 'package:mobile/screens/auth/views/startup_screen.dart';
import 'package:mobile/screens/contacts/views/direct_chat_screen.dart';
import 'package:mobile/screens/contacts/views/select_contact_screen.dart';
import 'package:mobile/screens/home/views/home_screen.dart';
import 'package:mobile/screens/hub/views/hub_detail_screen.dart';
import 'package:mobile/screens/hubs/views/create_hub_screen.dart';
import 'package:mobile/screens/hubs/views/hub_chat_screen.dart';
import 'package:mobile/screens/hubs/views/hub_created_screen.dart';
import 'package:mobile/screens/hubs/views/hub_permissions_screen.dart';
import 'package:mobile/screens/hubs/views/join_hub_screen.dart';
import 'package:mobile/screens/hubs/views/scan_qr_screen.dart';
import 'package:mobile/screens/onboarding/views/onboarding_screen.dart';
import 'package:mobile/screens/hubs/views/hub_info_screen.dart';
import 'package:mobile/screens/ai/views/ai_screen.dart';
import 'package:mobile/screens/profile/views/profile_screen.dart';
import 'package:mobile/screens/broadcasts/views/broadcast_feed_screen.dart';
import 'package:mobile/screens/resources/views/resource_list_screen.dart';
import 'package:mobile/screens/tasks/views/task_list_screen.dart';
import 'package:mobile/screens/calendar/views/calendar_screen.dart';
import 'package:mobile/shared/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: "/startup",
  routes: [
    // -----------------------------------------------------------------------
    // Startup splash — checks for a stored session, then routes to /phone or
    // /home accordingly.
    // -----------------------------------------------------------------------
    GoRoute(
      path: "/startup",
      builder: (context, state) => const StartupScreen(),
    ),

    // -----------------------------------------------------------------------
    // Onboarding (welcome / marketing screen)
    // -----------------------------------------------------------------------
    GoRoute(path: "/", builder: (context, state) => const OnboardingScreen()),

    // -----------------------------------------------------------------------
    // Phone-OTP authentication flow
    // -----------------------------------------------------------------------
    GoRoute(path: "/phone", builder: (context, state) => const PhoneScreen()),
    GoRoute(
      path: "/otp",
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'];
        final fullName = state.uri.queryParameters['fullName'];
        return OtpScreen(phone: phone, fullName: fullName);
      },
    ),
    GoRoute(
      path: "/complete-profile",
      builder: (context, state) => const ProfileSetupScreen(),
    ),

    // -----------------------------------------------------------------------
    // Main app shell with bottom navigation tabs
    // -----------------------------------------------------------------------
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: "/home", builder: (context, state) => const HomeScreen()),
        GoRoute(path: "/ai", builder: (context, state) => const AiScreen()),
        GoRoute(
          path: "/profile",
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // -----------------------------------------------------------------------
    // Hub routes
    // -----------------------------------------------------------------------
    GoRoute(
      path: "/hub/:hubId",
      builder: (context, state) {
        final hubId = int.parse(state.pathParameters['hubId']!);
        final hub = state.extra as Map<String, dynamic>?;
        return HubDetailScreen(hub: hub ?? {'id': hubId});
      },
    ),
    GoRoute(
      path: "/join-hub",
      builder: (context, state) => const JoinHubScreen(),
    ),
    GoRoute(
      path: "/scan-qr",
      builder: (context, state) => const ScanQrScreen(),
    ),
    GoRoute(
      path: "/select-contact",
      builder: (context, state) => const SelectContactScreen(),
    ),
    GoRoute(
      path: "/direct-chat/:conversationId",
      builder: (context, state) {
        final id = int.parse(state.pathParameters['conversationId']!);
        final conversation = state.extra as Map<String, dynamic>?;
        return DirectChatScreen(conversationId: id, conversation: conversation);
      },
    ),
    GoRoute(
      path: "/create-hub",
      builder: (context, state) => const CreateHubScreen(),
    ),
    GoRoute(
      path: "/hub-permissions",
      builder: (context, state) {
        final hubDraft = state.extra as Map<String, String>?;
        return HubPermissionsScreen(hubDraft: hubDraft);
      },
    ),
    GoRoute(
      path: "/hub-created",
      builder: (context, state) {
        final hub = state.extra as Map<String, dynamic>?;
        return HubCreatedScreen(hub: hub);
      },
    ),
    GoRoute(
      path: "/hub-chat",
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          return HubChatScreen(hub: extra);
        }
        if (extra is int) {
          return HubChatScreen(hubId: extra);
        }
        if (extra is String) {
          final hubId = int.tryParse(extra);
          return HubChatScreen(hubId: hubId);
        }
        return const HubChatScreen();
      },
    ),
    GoRoute(
      path: "/hub-info",
      builder: (context, state) {
        final hub = state.extra as Map<String, dynamic>?;
        return HubInfoScreen(hub: hub);
      },
    ),

    // -----------------------------------------------------------------------
    // Other feature routes (unchanged)
    // -----------------------------------------------------------------------
    GoRoute(
      path: "/broadcasts",
      builder: (context, state) => const BroadcastFeedScreen(),
    ),
    GoRoute(
      path: "/resources",
      builder: (context, state) => const ResourceListScreen(),
    ),
    GoRoute(
      path: "/tasks",
      builder: (context, state) => const TaskListScreen(),
    ),
    GoRoute(
      path: "/calendar",
      builder: (context, state) => const CalendarScreen(),
    ),
  ],
);
