import 'package:flutter/material.dart';
import 'package:mobile/screens/home/models/hub.dart';

/// Mock joined hubs used to demo the populated Home list.
/// Return an empty list from [buildMockHubs] to demo the empty state.
List<Hub> buildMockHubs() => [
      const Hub(
        id: "campus-announcements",
        name: "Campus Announcements",
        initials: "CA",
        avatarColor: Color(0xFFA61D37),
        latestMessage: "Registrar: Second semester exams start 4th August.",
        timestamp: "10:42 AM",
        unreadCount: 3,
        isPinned: true,
      ),
      const Hub(
        id: "cs2029",
        name: "Computer Science 2029",
        initials: "CS",
        avatarColor: Color(0xFF2563EB),
        latestMessage: "Class Rep: Programming II lecture moved to LT4.",
        timestamp: "11:15 AM",
        unreadCount: 2,
      ),
      const Hub(
        id: "swe301",
        name: "SWE 301 — Software Engineering",
        initials: "SE",
        avatarColor: Color(0xFF7C3AED),
        latestMessage: "Dr. Mensah: Sprint review presentations on Friday.",
        timestamp: "9:03 AM",
        unreadCount: 5,
        isPinned: true,
      ),
      const Hub(
        id: "mth301",
        name: "MTH 301 — Linear Algebra",
        initials: "LA",
        avatarColor: Color(0xFF0D9488),
        latestMessage: "Class Rep: Assignment 2 PDF uploaded, due Monday.",
        timestamp: "Yesterday",
      ),
      const Hub(
        id: "csc305",
        name: "CSC 305 — Operating Systems",
        initials: "OS",
        avatarColor: Color(0xFFEA580C),
        latestMessage: "TA Kofi: Lab 4 on process scheduling is now open.",
        timestamp: "Yesterday",
        unreadCount: 1,
        isMuted: true,
      ),
      const Hub(
        id: "gst201",
        name: "GST 201 — Entrepreneurship",
        initials: "EN",
        avatarColor: Color(0xFFCA8A04),
        latestMessage: "Class Rep: Group lists for the pitch project posted.",
        timestamp: "Sunday",
      ),
      const Hub(
        id: "acses",
        name: "ACSES Study Group",
        initials: "SG",
        avatarColor: Color(0xFF16A34A),
        latestMessage: "Ama: Sharing my Data Structures revision notes.",
        timestamp: "Saturday",
        isMuted: true,
      ),
    ];
