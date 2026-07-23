import 'package:flutter/material.dart';

/// A joined Academic Hub shown on the Home screen chat list.
class Hub {
  final String id;
  final String name;
  final String initials;
  final Color avatarColor;
  final String latestMessage;
  final String timestamp;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;

  const Hub({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.latestMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
  });

  bool get hasUnread => unreadCount > 0;

  Hub copyWith({
    String? id,
    String? name,
    String? initials,
    Color? avatarColor,
    String? latestMessage,
    String? timestamp,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
  }) {
    return Hub(
      id: id ?? this.id,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      avatarColor: avatarColor ?? this.avatarColor,
      latestMessage: latestMessage ?? this.latestMessage,
      timestamp: timestamp ?? this.timestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
