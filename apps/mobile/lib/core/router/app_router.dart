import 'package:go_router/go_router.dart';
import 'package:mobile/screens/auth/views/account_setup_screen.dart';
import 'package:mobile/screens/auth/views/profile_setup_screen.dart';
import 'package:mobile/screens/auth/views/otp_screen.dart';
import 'package:mobile/screens/auth/views/startup_screen.dart';
import 'package:mobile/screens/auth/views/register_onboard.dart';
import 'package:mobile/screens/auth/views/register_screen.dart';
import 'package:mobile/screens/auth/views/login_screen.dart';
import 'package:mobile/screens/contacts/views/select_contact_screen.dart';
import 'package:mobile/screens/home/views/home_screen.dart';
import 'package:mobile/screens/hubs/views/create_hub_screen.dart';
import 'package:mobile/screens/hubs/views/hub_chat_screen.dart';
import 'package:mobile/screens/hubs/views/hub_created_screen.dart';
import 'package:mobile/screens/hubs/views/hub_permissions_screen.dart';
import 'package:mobile/screens/hubs/views/join_hub_screen.dart';
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
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const OnboardingScreen();
      },
    ),
    GoRoute(
      path: "/startup",
      builder: (context, state) {
        return const StartupScreen();
      },
    ),
    GoRoute(
      path: "/register-onboard",
      builder: (context, state) {
        return const RegisterOnboard();
      },
    ),
    GoRoute(
      path: "/register",
      builder: (context, state) {
        return const RegisterScreen();
      },
    ),
    GoRoute(
      path: "/login",
      builder: (context, state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: "/otp",
      builder: (context, state) {
        final username = state.uri.queryParameters['username'];
        return OtpScreen(username: username);
      },
    ),
    GoRoute(
      path: "/complete-profile",
      builder: (context, state) {
        return const ProfileSetupScreen();
      },
    ),
    GoRoute(
      path: "/account-setup",
      builder: (context, state) {
        return const AccountSetupScreen();
      },
    ),

    // Shell route for tabs
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: "/home",
          builder: (context, state) {
            return const HomeScreen();
          },
        ),
        GoRoute(
          path: "/ai",
          builder: (context, state) {
            return const AiScreen();
          },
        ),
        GoRoute(
          path: "/profile",
          builder: (context, state) {
            return const ProfileScreen();
          },
        ),
      ],
    ),

    GoRoute(
      path: "/join-hub",
      builder: (context, state) {
        return const JoinHubScreen();
      },
    ),
    GoRoute(
      path: "/select-contact",
      builder: (context, state) {
        return SelectContactScreen();
      },
    ),
    GoRoute(
      path: "/create-hub",
      builder: (context, state) {
        return const CreateHubScreen();
      },
    ),
    GoRoute(
      path: "/hub-permissions",
      builder: (context, state) {
        return const HubPermissionsScreen();
      },
    ),
    GoRoute(
      path: "/hub-created",
      builder: (context, state) {
        return const HubCreatedScreen();
      },
    ),
    GoRoute(
      path: "/hub-chat",
      builder: (context, state) {
        return const HubChatScreen();
      },
    ),
    GoRoute(
      path: "/hub-info",
      builder: (context, state) {
        return const HubInfoScreen();
      },
    ),
    GoRoute(
      path: "/broadcasts",
      builder: (context, state) {
        return const BroadcastFeedScreen();
      },
    ),
    GoRoute(
      path: "/resources",
      builder: (context, state) {
        return const ResourceListScreen();
      },
    ),
    GoRoute(
      path: "/tasks",
      builder: (context, state) {
        return const TaskListScreen();
      },
    ),
    GoRoute(
      path: "/calendar",
      builder: (context, state) {
        return const CalendarScreen();
      },
    ),
  ],
);
