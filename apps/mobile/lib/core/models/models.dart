class User {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String role; // 'student', 'lecturer', 'admin'
  final bool isOnline;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.role,
    this.isOnline = false,
  });
}

class Hub {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int memberCount;
  final bool isPrivate;

  const Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.memberCount,
    this.isPrivate = false,
  });
}

class Message {
  final String id;
  final String hubId;
  final User sender;
  final String content;
  final DateTime timestamp;
  final bool isThread;

  const Message({
    required this.id,
    required this.hubId,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.isThread = false,
  });
}

class Broadcast {
  final String id;
  final User sender;
  final String title;
  final String content;
  final DateTime timestamp;
  final String priority; // 'low', 'normal', 'high'

  const Broadcast({
    required this.id,
    required this.sender,
    required this.title,
    required this.content,
    required this.timestamp,
    this.priority = 'normal',
  });
}

class Resource {
  final String id;
  final String title;
  final String type; // 'pdf', 'link', 'doc', 'video'
  final String url;
  final String uploadedBy;
  final DateTime uploadDate;

  const Resource({
    required this.id,
    required this.title,
    required this.type,
    required this.url,
    required this.uploadedBy,
    required this.uploadDate,
  });
}

class TaskItem {
  final String id;
  final String title;
  final String courseName;
  final DateTime dueDate;
  final String status; // 'pending', 'submitted', 'graded'
  
  const TaskItem({
    required this.id,
    required this.title,
    required this.courseName,
    required this.dueDate,
    required this.status,
  });
}
