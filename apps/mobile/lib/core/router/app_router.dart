import 'package:go_router/go_router.dart';
import 'package:mobile/screens/auth/views/account_setup_screen.dart';
import 'package:mobile/screens/auth/views/profile_setup_screen.dart';
import 'package:mobile/screens/auth/views/otp_screen.dart';
import 'package:mobile/screens/auth/views/register_onboard.dart';
import 'package:mobile/screens/auth/views/register_screen.dart';
import 'package:mobile/screens/home/views/home_screen.dart';
import 'package:mobile/screens/onboarding/views/onboarding_screen.dart';

final appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(
      path: "/",
      builder: (context, state) {
        return const OnboardingScreen();
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
      path: "/otp",
      builder: (context, state) {
        return const OtpScreen();
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
    GoRoute(path: "/home", builder: (context, state) {
      return const HomeScreen();
    },)
  ],
);
