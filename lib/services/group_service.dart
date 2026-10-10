import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';
import 'auth_service.dart';

/// URL pública donde se despliega la app (GitHub Pages). Cámbiala por la tuya,
/// con la barra final. Con la estrategia de URL por defecto se usa "#/ruta".
const kPublicUrl = 'https://asvv-03.github.io/reviewer/';

class GroupService {
  GroupService._();
  static final instance = GroupService._();

  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _membership(String gid) =>
      _db.collection('users').doc(_uid).collection('memberships').doc(gid);

  // ---------- Grupos ----------

  Stream<List<Group>> watchMyGroups() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('memberships')
        .snapshots()
        .map((s) {
      final list = s.docs.map(Group.fromMembership).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Stream<List<Member>> watchMembers(String gid) {
    return _db
        .collection('groups')
        .doc(gid)
        .collection('members')
        .snapshots()
        .map((s) => s.docs.map(Member.fromDoc).toList());
  }

  Future<bool> isMember(String gid) async {
    final doc = await _membership(gid).get();
    return doc.exists;
  }

  Future<String> createGroup(String name) async {
    final cleanName = name.trim();
    final groupRef = _db.collection('groups').doc();
    final batch = _db.batch();

    batch.set(groupRef, {
      'name': cleanName,
      'ownerId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(groupRef.collection('members').doc(_uid), {
      'displayName': AuthService.instance.displayName,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_membership(groupRef.id), {
      'name': cleanName,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return groupRef.id;
  }

  Future<void> leaveGroup(String gid) async {
    final batch = _db.batch();
    batch.delete(_db.collection('groups').doc(gid).collection('members').doc(_uid));
    batch.delete(_membership(gid));
    await batch.commit();
  }

  // ---------- Invitaciones ----------

  /// Crea una invitación y devuelve el enlace para compartir.
  /// Si [email] viene vacío, cualquiera con el enlace puede unirse (hasta que venza).
  Future<String> createInvite({
    required String groupId,
    required String groupName,
    String? email,
  }) async {
    final ref = _db.collection('invites').doc();
    final cleanEmail = (email == null || email.trim().isEmpty)
        ? null
        : email.trim().toLowerCase();

    await ref.set({
      'groupId': groupId,
      'groupName': groupName,
      'email': cleanEmail,
      'invitedBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
    return '${kPublicUrl}#/join/${ref.id}';
  }

  Future<Invite?> getInvite(String inviteId) async {
    final doc = await _db.collection('invites').doc(inviteId).get();
    if (!doc.exists) return null;
    return Invite.fromDoc(doc);
  }

  Future<void> joinGroup(Invite invite) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('groups').doc(invite.groupId).collection('members').doc(_uid),
      {
        'displayName': AuthService.instance.displayName,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'inviteId': invite.id, // las reglas validan la invitación con este campo
      },
    );
    batch.set(_membership(invite.groupId), {
      'name': invite.groupName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // Las invitaciones por correo son de un solo uso
    if (invite.email != null) {
      try {
        await _db.collection('invites').doc(invite.id).delete();
      } catch (_) {}
    }
  }
}