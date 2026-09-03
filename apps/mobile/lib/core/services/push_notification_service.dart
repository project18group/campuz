import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'auth_api_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // In a real app, you could show a local notification snackbar here
        }
      });

      // Handle background/terminated state opens
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        _handleRouting(message.data);
      });

      // Initial message (if app opened from terminated state via notification)
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleRouting(initialMessage.data);
      }

      // Sync token with backend
      await _syncToken();

      // Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
      // If the user hasn't added google-services.json yet, this will fail gracefully.
    }
  }

  static Future<void> _syncToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Could not get FCM token: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      // Wait, there is no registerToken endpoint in AuthApiService yet.
      // We will add it shortly.
      await AuthApiService.registerDeviceToken(token: token);
      debugPrint('Token synced with backend: $token');
    } catch (e) {
      debugPrint('Failed to sync token with backend: $e');
    }
  }

  static void _handleRouting(Map<String, dynamic> data) {
    // Navigate based on data payload
    if (data.containsKey('hub_id')) {
      // E.g. GlobalRouter.router.go('/hub/${data['hub_id']}');
    }
  }
}
