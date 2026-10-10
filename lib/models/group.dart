import 'package:cloud_firestore/cloud_firestore.dart';

/// Grupo tal como aparece en mi índice personal (users/{uid}/memberships).
class Group {
  final String id;
  final String name;
  final String role;

  Group({required this.id, required this.name, required this.role});

  factory Group.fromMembership(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return Group(
      id: d.id,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
    );
  }
}

class Member {
  final String uid;
  final String displayName;
  final String role;

  Member({required this.uid, required this.displayName, required this.role});

  bool get isAdmin => role == 'admin';

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return Member(
      uid: d.id,
      displayName: data['displayName'] as String? ?? 'Sin nombre',
      role: data['role'] as String? ?? 'member',
    );
  }
}

class Invite {
  final String id;
  final String groupId;
  final String groupName;
  final String? email;
  final DateTime expiresAt;

  Invite({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.email,
    required this.expiresAt,
  });

  bool get expired => expiresAt.isBefore(DateTime.now());

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    return Invite(
      id: d.id,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String? ?? 'Grupo',
      email: data['email'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }
}