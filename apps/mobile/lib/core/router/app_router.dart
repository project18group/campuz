import 'package:go_router/go_router.dart';
import 'package:mobile/screens/auth/views/register_onboard.dart';
import 'package:mobile/screens/auth/views/register_screen.dart';
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
  ],
);
