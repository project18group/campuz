import '../models/models.dart';

class MockData {
  static bool isNewUser = true; // Used to simulate empty states for fresh signups
  
  static const User currentUser = User(
    id: 'u1',
    name: 'Jane Doe',
    email: 'jane.doe@student.edu',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
    role: 'student',
    isOnline: true,
  );

  static const User lecturerSmith = User(
    id: 'u2',
    name: 'Dr. John Smith',
    email: 'j.smith@faculty.edu',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704e',
    role: 'lecturer',
    isOnline: false,
  );

  static final List<Hub> hubs = [
    const Hub(
      id: 'h1',
      name: 'Computer Science 101',
      description: 'Introductory course for CS majors.',
      imageUrl: 'https://picsum.photos/seed/cs101/200/200',
      memberCount: 120,
    ),
    const Hub(
      id: 'h2',
      name: 'Campus Tech Club',
      description: 'Discussing the latest in tech and development.',
      imageUrl: 'https://picsum.photos/seed/tech/200/200',
      memberCount: 45,
    ),
  ];

  static final List<Message> messages = [
    Message(
      id: 'm1',
      hubId: 'h1',
      sender: lecturerSmith,
      content: 'Welcome to CS 101! Make sure to read the syllabus.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Message(
      id: 'm2',
      hubId: 'h1',
      sender: currentUser,
      content: 'Thanks, Dr. Smith! Looking forward to it.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  static final List<Broadcast> broadcasts = [
    Broadcast(
      id: 'b1',
      sender: lecturerSmith,
      title: 'Class Cancelled',
      content: 'Due to unexpected circumstances, tomorrow\'s lecture is cancelled.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      priority: 'high',
    ),
  ];

  static final List<Resource> resources = [
    Resource(
      id: 'r1',
      title: 'CS101 Syllabus',
      type: 'pdf',
      url: 'https://example.com/syllabus.pdf',
      uploadedBy: 'Dr. John Smith',
      uploadDate: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Resource(
      id: 'r2',
      title: 'Intro to Python Video',
      type: 'video',
      url: 'https://example.com/python.mp4',
      uploadedBy: 'Dr. John Smith',
      uploadDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final List<TaskItem> tasks = [
    TaskItem(
      id: 't1',
      title: 'Assignment 1: Hello World',
      courseName: 'Computer Science 101',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      status: 'pending',
    ),
    TaskItem(
      id: 't2',
      title: 'Reading Reflection',
      courseName: 'Software Engineering',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      status: 'submitted',
    ),
  ];
}
