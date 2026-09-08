// Prueba de humo: la pantalla de login se dibuja y muestra el botón "Ingresar".
//
// Se usa un [AuthRepository] falso para no depender de Firebase (que no está
// inicializado en el entorno de pruebas).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/auth/domain/entities/auth_user.dart';
import 'package:sire/features/auth/domain/repositories/auth_repository.dart';
import 'package:sire/features/auth/presentation/pages/login_page.dart';
import 'package:sire/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.value(null);

  @override
  Future<AuthUser> signIn({required String email, required String password}) async =>
      const AuthUser(uid: 'test');

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      const AuthUser(uid: 'test');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
}

void main() {
  testWidgets('La pantalla de login se dibuja con el botón "Ingresar"',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });
}
