import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'screens/group_detail.dart';
import 'screens/groups.dart';
import 'screens/join.dart';
import 'screens/login.dart';
import 'screens/place_detail.dart';
import 'screens/review_form.dart';

import 'screens/group_map.dart';

/// Hace que el router vuelva a evaluar el redirect cuando cambia la sesión.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final router = GoRouter(
  refreshListenable: _AuthRefresh(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final atLogin = state.matchedLocation == '/login';

    // Sin sesión: ir a login recordando a dónde quería entrar (p. ej. un link de invitación)
    if (!loggedIn && !atLogin) {
      final from = state.uri.toString();
      return from == '/' ? '/login' : '/login?from=${Uri.encodeComponent(from)}';
    }
    // Con sesión: salir de login hacia el destino original
    if (loggedIn && atLogin) {
      return state.uri.queryParameters['from'] ?? '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const GroupsScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/group/:gid',
      builder: (_, s) => GroupDetailScreen(gid: s.pathParameters['gid']!),
    ),
    GoRoute(
      path: '/group/:gid/place/:pid',
      builder: (_, s) => PlaceDetailScreen(
        gid: s.pathParameters['gid']!,
        pid: s.pathParameters['pid']!,
      ),
    ),
    GoRoute(
      path: '/group/:gid/place/:pid/review',
      builder: (_, s) => ReviewFormScreen(
        gid: s.pathParameters['gid']!,
        pid: s.pathParameters['pid']!,
        reviewId: s.uri.queryParameters['edit'],
      ),
    ),
    GoRoute(
      path: '/join/:inviteId',
      builder: (_, s) => JoinScreen(inviteId: s.pathParameters['inviteId']!),
    ),
    GoRoute(
      path: '/group/:gid/map',
      builder: (_, s) => GroupMapScreen(gid: s.pathParameters['gid']!),
    ),
  ],
);