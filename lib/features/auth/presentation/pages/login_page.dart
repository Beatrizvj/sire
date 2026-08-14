import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_routes.dart';
import '../providers/auth_providers.dart';

/// Inicio de sesión (correo + contraseña).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Si el login es correcto, el redirect del router navega al dashboard.
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
  }

  Future<void> _showResetDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordResetDialog(
        initialEmail: _email.text.trim(),
        onSubmit: (email) =>
            ref.read(authControllerProvider.notifier).sendPasswordReset(email),
      ),
    );
    if (sent == null || !mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Te enviamos un correo para restablecer tu contraseña. '
                    'Revisa tu bandeja (y spam).'
                : ref.read(authControllerProvider).error ??
                    'No se pudo enviar el correo.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    AppConfig.appTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                      if (!v.contains('@')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Ingresa tu contraseña'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.isBusy ? null : _submit,
                    child: state.isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ingresar'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: state.isBusy ? null : _showResetDialog,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.register),
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                  if (!AppConfig.firebaseEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Modo demo local: cualquier correo y contraseña funcionan.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de recuperación de contraseña.
///
/// Es un widget con estado propio para que su [TextEditingController] tenga un
/// ciclo de vida gestionado por el framework (crear en el State, liberar en
/// `dispose`). Así se evita el error `_dependents.isEmpty` que ocurría al
/// liberar el controlador manualmente tras cerrar el diálogo.
class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({
    required this.initialEmail,
    required this.onSubmit,
  });

  final String initialEmail;
  final Future<bool> Function(String email) onSubmit;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail);
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final ok = await widget.onSubmit(_controller.text);
    if (mounted) Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Escribe tu correo y te enviaremos un enlace para restablecer '
            'tu contraseña.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar enlace'),
        ),
      ],
    );
  }
}
