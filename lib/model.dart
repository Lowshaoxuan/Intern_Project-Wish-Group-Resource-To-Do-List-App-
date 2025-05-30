import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

var uuid = const Uuid();

/// Represents a user of the system.
class AppUser {
  final String userId;
  final String email;
  String username;
  String phoneNumber;
  // New attribute: List of user IDs who are subordinates of this user
  List<String> subordinate;
  // New attribute: URL for the user's avatar/profile picture
  final String? avatarUrl; // Added avatarUrl attribute

  AppUser({
    required this.userId,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.subordinate, // Include in constructor
    this.avatarUrl, // Include in constructor
  });

  factory AppUser.create({
    required String email,
    required String username,
    required String phoneNumber,
    List<String>? subordinate, // Optional in create, defaults to empty list
    String? avatarUrl, // Optional in create
  }) {
    return AppUser(
      userId: uuid.v4(),
      email: email,
      username: username,
      phoneNumber: phoneNumber,
      subordinate: subordinate ?? [], // Initialize with empty list if null
      avatarUrl: avatarUrl, // Pass to constructor
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'subordinate': subordinate, // Include in toMap
      'avatarUrl': avatarUrl, // Include in toMap
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'],
      email: map['email'],
      username: map['username'],
      phoneNumber: map['phoneNumber'],
      subordinate: List<String>.from(map['subordinate'] ?? []), // Parse subordinate
      avatarUrl: map['avatarUrl'], // Parse avatarUrl
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      userId: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      subordinate: List<String>.from(data['subordinate'] ?? []), // Handle subordinate from Firestore
      avatarUrl: data['avatarUrl'], // Handle avatarUrl from Firestore
    );
  }
}

/// Represents an appointment/task.
class Appointment {
  final String appointmentId;
  final String category;
  final String title;
  final String? description;
  final DateTime date;
  final String time; // Stored as 'HH:mm' string
  String status; // e.g., Pending, Completed, etc.
  final String userId; // FK to AppUser
  final List<String> commentIds; // List of FK to AppointmentComment
  final double? amount; // New field for sales closing appointments

  Appointment({
    required this.appointmentId,
    required this.category,
    required this.title,
    this.description,
    required this.date,
    required this.time,
    required this.status,
    required this.userId,
    required this.commentIds,
    this.amount, // Include in constructor
  });

  factory Appointment.create({
    required String category,
    required String title,
    String? description,
    required DateTime date,
    required String time,
    required String status,
    required String userId,
    double? amount, // Include in factory constructor
  }) {
    return Appointment(
      appointmentId: uuid.v4(),
      category: category,
      title: title,
      description: description,
      date: date,
      time: time,
      status: status,
      userId: userId,
      commentIds: [],
      amount: amount, // Pass to constructor
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'category': category,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'time': time,
      'status': status,
      'userId': userId,
      'commentIds': commentIds,
      'amount': amount, // Include in toMap
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      appointmentId: map['appointmentId'],
      category: map['category'],
      title: map['title'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      status: map['status'],
      userId: map['userId'],
      commentIds: List<String>.from(map['commentIds'] ?? []),
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null, // Parse amount
    );
  }

  /// Firestore factory constructor to create an Appointment from Firestore DocumentSnapshot
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle date field: it might be Timestamp or String
    DateTime parsedDate;
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      parsedDate = DateTime.parse(data['date']);
    } else {
      parsedDate = DateTime.now(); // fallback
    }

    return Appointment(
      appointmentId: doc.id,
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      date: parsedDate,
      time: data['time'] ?? '00:00', // default time if missing
      status: data['status'] ?? 'Pending', // Changed default status to 'Pending'
      userId: data['userId'] ?? '',
      commentIds: List<String>.from(data['commentIds'] ?? []),
      amount: data['amount'] != null ? (data['amount'] as num).toDouble() : null, // Handle amount from Firestore
    );
  }
}

/// Represents a comment on an appointment.
class AppointmentComment {
  final String commentId;
  final String appointmentId; // FK to Appointment
  final String commentedByUserId; // FK to AppUser
  final String content;
  final DateTime timestamp;

  AppointmentComment({
    required this.commentId,
    required this.appointmentId,
    required this.commentedByUserId,
    required this.content,
    required this.timestamp,
  });

  factory AppointmentComment.create({
    required String appointmentId,
    required String commentedByUserId,
    required String content,
  }) {
    return AppointmentComment(
      commentId: uuid.v4(),
      appointmentId: appointmentId,
      commentedByUserId: commentedByUserId,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'appointmentId': appointmentId,
      'commentedByUserId': commentedByUserId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AppointmentComment.fromMap(Map<String, dynamic> map) {
    return AppointmentComment(
      commentId: map['commentId'],
      appointmentId: map['appointmentId'],
      commentedByUserId: map['commentedByUserId'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  factory AppointmentComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parsedTimestamp;
    if (data['timestamp'] is Timestamp) {
      parsedTimestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is String) {
      parsedTimestamp = DateTime.parse(data['timestamp']);
    } else {
      parsedTimestamp = DateTime.now();
    }

    return AppointmentComment(
      commentId: doc.id,
      appointmentId: data['appointmentId'] ?? '',
      commentedByUserId: data['commentedByUserId'] ?? '',
      content: data['content'] ?? '',
      timestamp: parsedTimestamp,
    );
  }
}
