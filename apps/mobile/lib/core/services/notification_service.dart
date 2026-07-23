import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sprint 15 — Notification architecture (mock, no plugin dependencies).
///
/// This service is a UI-facing facade for in-app notifications. It currently
/// runs entirely on mock data; the real implementation will be backed by the
/// Django server (see the TODO(django) placeholder methods at the bottom)
/// and, later, a push plugin such as firebase_messaging /
/// flutter_local_notifications.

/// A single in-app notification.
@immutable
class AppNotification {
  final String id;

  /// The hub this notification belongs to — used by
  /// [NotificationService.handleNotificationTap] to open the right chat.
  final String hubId;
  final String hubName;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.hubId,
    required this.hubName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      hubId: hubId,
      hubName: hubName,
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Singleton service holding the app's notification state.
///
/// Usage:
/// ```dart
/// final service = NotificationService();
/// service.init();
/// service.onOpenHub = (hubId) => router.push('/hub-chat', extra: hubId);
///
/// ValueListenableBuilder(
///   valueListenable: service.notifications,
///   builder: (context, list, _) => ...,
/// );
/// ```
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  /// Convenience accessor, identical to calling the factory constructor.
  static NotificationService get instance => _instance;

  bool _initialized = false;

  /// Reactive list of notifications, newest first. Listen with a
  /// [ValueListenableBuilder] or `addListener`.
  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>(const []);

  /// Number of unread notifications (derived convenience getter).
  int get unreadCount =>
      notifications.value.where((n) => !n.isRead).length;

  // ---------------------------------------------------------------------
  // Navigation contract
  // ---------------------------------------------------------------------

  /// Navigation callback registered by the app shell.
  ///
  /// The service is intentionally context-free, so it cannot navigate by
  /// itself. At app startup (e.g. in main.dart or the router setup), register
  /// a callback that uses go_router to push the hub chat route:
  ///
  /// ```dart
  /// NotificationService().onOpenHub = (hubId) {
  ///   // go_router pushes "/hub-chat"; hubId identifies which hub to open.
  ///   router.push('/hub-chat', extra: hubId);
  /// };
  /// ```
  void Function(String hubId)? onOpenHub;

  /// Handles a tap on a notification (from an in-app list or, later, a
  /// system tray notification).
  ///
  /// Contract: marks the notification as read, then opens the hub chat for
  /// [AppNotification.hubId] by invoking the registered [onOpenHub] callback.
  /// The app is expected to have registered [onOpenHub] so that go_router
  /// pushes the "/hub-chat" route for the given hub. If no callback is
  /// registered, the tap is a no-op apart from the read-state change.
  void handleNotificationTap(AppNotification n) {
    markAsRead(n.id);
    onOpenHub?.call(n.hubId);
  }

  // ---------------------------------------------------------------------
  // Lifecycle & mock API
  // ---------------------------------------------------------------------

  /// Initializes the service and seeds it with mock notifications.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops. In the real
  /// implementation this is where plugin setup and permission requests will
  /// live.
  void init() {
    if (_initialized) return;
    _initialized = true;
    notifications.value = getMockNotifications();
  }

  /// Returns a fresh list of seeded mock notifications (newest first).
  List<AppNotification> getMockNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        hubId: 'hub-csc402',
        hubName: 'CSC 402 - Distributed Systems',
        title: 'New lecture slides posted',
        body: 'Dr. Mensah shared "Lecture 8 - Consensus Algorithms.pdf".',
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: 'n2',
        hubId: 'hub-group4',
        hubName: 'Group 4 - Final Year Project',
        title: 'Meeting reminder',
        body: 'Project stand-up today at 4:00 PM in the library study room.',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n3',
        hubId: 'hub-csc402',
        hubName: 'CSC 402 - Distributed Systems',
        title: 'Assignment 3 deadline extended',
        body: 'The submission deadline has moved to Friday, 11:59 PM.',
        timestamp: now.subtract(const Duration(hours: 6)),
        isRead: true,
      ),
      AppNotification(
        id: 'n4',
        hubId: 'hub-exams',
        hubName: 'Exams Office Announcements',
        title: 'Mid-semester timetable released',
        body: 'Check the pinned message for your exam venue and time.',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
      AppNotification(
        id: 'n5',
        hubId: 'hub-stat201',
        hubName: 'STAT 201 - Study Group',
        title: 'New past questions uploaded',
        body: 'Yaw shared "Past Questions 2023-2025.pdf" in the hub.',
        timestamp: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }

  /// Adds a mock notification to the top of the list (simulates receiving a
  /// push notification while the app is open).
  void showMockNotification({
    required String hubId,
    required String hubName,
    required String title,
    required String body,
  }) {
    final notification = AppNotification(
      id: 'n${DateTime.now().microsecondsSinceEpoch}',
      hubId: hubId,
      hubName: hubName,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    notifications.value = [notification, ...notifications.value];
  }

  /// Marks the notification with [id] as read.
  void markAsRead(String id) {
    notifications.value = [
      for (final n in notifications.value)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  /// Removes all notifications.
  void clearAll() {
    notifications.value = const [];
  }

  // ---------------------------------------------------------------------
  // Django integration placeholders — NOT implemented yet.
  // ---------------------------------------------------------------------

  /// Registers this device's push token with the Django backend.
  ///
  /// TODO(django): POST the token to /api/devices/register/ with the auth
  /// header, so the server can target this device via FCM/APNs.
  Future<void> registerDeviceToken(String token) async {
    // TODO(django): implement server-side device token registration.
  }

  /// Pulls the notification history from the Django backend and replaces the
  /// local mock list.
  ///
  /// TODO(django): GET /api/notifications/ and map the JSON payload into
  /// [AppNotification] objects, then publish them to [notifications].
  Future<void> fetchNotificationsFromServer() async {
    // TODO(django): implement server fetch + local merge.
  }

  /// Pushes local read/unread state back to the Django backend.
  ///
  /// TODO(django): PATCH /api/notifications/read-status/ with the ids of
  /// locally read notifications so state stays consistent across devices.
  Future<void> syncReadStatus() async {
    // TODO(django): implement read-status sync.
  }
}
