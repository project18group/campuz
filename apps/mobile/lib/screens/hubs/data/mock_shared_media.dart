import 'package:flutter/material.dart';

/// Mock data models + seed data for the Shared Media screen (Sprint 14).
/// UI-only — no backend. Another sprint will wire this to real hub data.

class MediaImageItem {
  final String id;
  final String name;
  final String sender;
  final DateTime date;
  final int size; // bytes
  final String? url;
  final List<Color> gradient;

  const MediaImageItem({
    required this.id,
    required this.name,
    required this.sender,
    required this.date,
    required this.size,
    this.url,
    required this.gradient,
  });
}

class MediaDocumentItem {
  final String id;
  final String name;
  final String type; // pdf, docx, pptx, zip
  final String sender;
  final DateTime date;
  final int size; // bytes
  final String? url;

  const MediaDocumentItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sender,
    required this.date,
    required this.size,
    this.url,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MediaLinkItem {
  final String id;
  final String title;
  final String url;
  final String sender;
  final DateTime date;

  const MediaLinkItem({
    required this.id,
    required this.title,
    required this.url,
    required this.sender,
    required this.date,
  });
}

final List<MediaImageItem> mockSharedImages = [
  MediaImageItem(
    id: 'img1',
    name: 'lecture_whiteboard.jpg',
    sender: 'Dr. Mensah',
    date: DateTime(2026, 7, 18, 10, 12),
    size: 2 * 1024 * 1024 + 340 * 1024,
    gradient: const [Color(0xFFA61D37), Color(0xFFD94F70)],
  ),
  MediaImageItem(
    id: 'img2',
    name: 'timetable_sem2.png',
    sender: 'Course Rep',
    date: DateTime(2026, 7, 16, 8, 45),
    size: 890 * 1024,
    gradient: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
  ),
  MediaImageItem(
    id: 'img3',
    name: 'lab_setup_diagram.jpg',
    sender: 'Ama K.',
    date: DateTime(2026, 7, 14, 15, 30),
    size: 1 * 1024 * 1024 + 120 * 1024,
    gradient: const [Color(0xFF059669), Color(0xFF34D399)],
  ),
  MediaImageItem(
    id: 'img4',
    name: 'circuit_sketch.png',
    sender: 'Kofi B.',
    date: DateTime(2026, 7, 12, 19, 5),
    size: 640 * 1024,
    gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  ),
  MediaImageItem(
    id: 'img5',
    name: 'group_photo_fieldtrip.jpg',
    sender: 'Efua A.',
    date: DateTime(2026, 7, 9, 12, 20),
    size: 3 * 1024 * 1024,
    gradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  ),
  MediaImageItem(
    id: 'img6',
    name: 'exam_venue_map.png',
    sender: 'Course Rep',
    date: DateTime(2026, 7, 6, 9, 0),
    size: 420 * 1024,
    gradient: const [Color(0xFF0891B2), Color(0xFF67E8F9)],
  ),
  MediaImageItem(
    id: 'img7',
    name: 'notes_page_14.jpg',
    sender: 'Yaw D.',
    date: DateTime(2026, 7, 3, 21, 40),
    size: 1 * 1024 * 1024 + 760 * 1024,
    gradient: const [Color(0xFFDB2777), Color(0xFFF472B6)],
  ),
  MediaImageItem(
    id: 'img8',
    name: 'project_poster_draft.png',
    sender: 'Adjoa S.',
    date: DateTime(2026, 6, 28, 17, 15),
    size: 2 * 1024 * 1024 + 50 * 1024,
    gradient: const [Color(0xFF4B5563), Color(0xFF9CA3AF)],
  ),
  MediaImageItem(
    id: 'img9',
    name: 'slide_snapshot.jpg',
    sender: 'Dr. Mensah',
    date: DateTime(2026, 6, 24, 11, 55),
    size: 980 * 1024,
    gradient: const [Color(0xFF7D1328), Color(0xFFA61D37)],
  ),
];

final List<MediaDocumentItem> mockSharedDocuments = [
  MediaDocumentItem(
    id: 'doc1',
    name: 'CSC 402 Lecture 8 - Distributed Systems.pdf',
    type: 'pdf',
    sender: 'Dr. Mensah',
    date: DateTime(2026, 7, 19, 9, 30),
    size: 4 * 1024 * 1024 + 210 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc2',
    name: 'Group 4 Project Proposal.docx',
    type: 'docx',
    sender: 'Ama K.',
    date: DateTime(2026, 7, 17, 14, 5),
    size: 350 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc3',
    name: 'Midsem Revision Slides.pptx',
    type: 'pptx',
    sender: 'Course Rep',
    date: DateTime(2026, 7, 15, 18, 45),
    size: 12 * 1024 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc4',
    name: 'Lab Datasets (Week 6).zip',
    type: 'zip',
    sender: 'Kofi B.',
    date: DateTime(2026, 7, 11, 10, 0),
    size: 25 * 1024 * 1024 + 500 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc5',
    name: 'Past Questions 2023-2025.pdf',
    type: 'pdf',
    sender: 'Yaw D.',
    date: DateTime(2026, 7, 8, 20, 30),
    size: 6 * 1024 * 1024 + 800 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc6',
    name: 'Assignment 3 Template.docx',
    type: 'docx',
    sender: 'Dr. Mensah',
    date: DateTime(2026, 7, 5, 8, 15),
    size: 120 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc7',
    name: 'Seminar Presentation Final.pptx',
    type: 'pptx',
    sender: 'Adjoa S.',
    date: DateTime(2026, 6, 30, 16, 20),
    size: 8 * 1024 * 1024 + 340 * 1024,
  ),
  MediaDocumentItem(
    id: 'doc8',
    name: 'Source Code Submission.zip',
    type: 'zip',
    sender: 'Efua A.',
    date: DateTime(2026, 6, 26, 22, 10),
    size: 3 * 1024 * 1024 + 60 * 1024,
  ),
];

final List<MediaLinkItem> mockSharedLinks = [
  MediaLinkItem(
    id: 'link1',
    title: 'MIT OpenCourseWare - Distributed Systems',
    url: 'https://ocw.mit.edu/courses/distributed-systems',
    sender: 'Dr. Mensah',
    date: DateTime(2026, 7, 18, 11, 0),
  ),
  MediaLinkItem(
    id: 'link2',
    title: 'Google Scholar - Consensus Algorithms Survey',
    url: 'https://scholar.google.com/consensus-algorithms',
    sender: 'Ama K.',
    date: DateTime(2026, 7, 15, 13, 25),
  ),
  MediaLinkItem(
    id: 'link3',
    title: 'GitHub - Course Project Starter Repo',
    url: 'https://github.com/campuz/csc402-starter',
    sender: 'Kofi B.',
    date: DateTime(2026, 7, 12, 9, 50),
  ),
  MediaLinkItem(
    id: 'link4',
    title: 'YouTube - Raft Explained Visually',
    url: 'https://youtube.com/watch?v=raft-visual',
    sender: 'Yaw D.',
    date: DateTime(2026, 7, 7, 19, 10),
  ),
  MediaLinkItem(
    id: 'link5',
    title: 'Library Portal - Reserved Reading List',
    url: 'https://library.university.edu/reserves/csc402',
    sender: 'Course Rep',
    date: DateTime(2026, 7, 2, 8, 40),
  ),
  MediaLinkItem(
    id: 'link6',
    title: 'Overleaf - Shared LaTeX Report Template',
    url: 'https://overleaf.com/project/group4-report',
    sender: 'Adjoa S.',
    date: DateTime(2026, 6, 27, 15, 35),
  ),
];
