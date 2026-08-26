import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_styles.dart';

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
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      backgroundColor: kAuthBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Isologo municipal ────────────────────────────────
                    const Center(child: AuthLogoBadge()),
                    const SizedBox(height: 22),

                    // ── Títulos ──────────────────────────────────────────
                    Text(
                      AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConfig.appTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Municipio destacado ──────────────────────────────
                    const Center(child: MunicipioChip()),
                    const SizedBox(height: 36),

                    // ── Correo ───────────────────────────────────────────
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: AppColors.emergency,
                      decoration: authFieldDecoration(
                        label: 'Correo',
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Contraseña ───────────────────────────────────────
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: AppColors.emergency,
                      onFieldSubmitted: (_) {
                        if (!state.isBusy) _submit();
                      },
                      decoration: authFieldDecoration(
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Ingresa tu contraseña'
                          : null,
                    ),

                    // ── ¿Olvidaste tu contraseña? ────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: state.isBusy ? null : _showResetDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: kAuthLightRed,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Botón principal ──────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.emergency,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.emergency.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: state.isBusy ? null : _submit,
                        child: state.isBusy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Ingresar'),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Enlace a registro ────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.register),
                        style: TextButton.styleFrom(
                          foregroundColor: kAuthLightRed,
                        ),
                        child: Text.rich(
                          const TextSpan(
                            text: '¿No tienes cuenta?  ',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Regístrate aquí',
                                style: TextStyle(
                                  color: kAuthLightRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: kAuthLightRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Aviso institucional (bajo contraste) ─────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: Colors.white38,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Las cuentas nuevas son validadas por el COCODE '
                              'de tu aldea o la Municipalidad.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Nota de modo demo local (solo si Firebase está apagado).
                    if (!AppConfig.firebaseEnabled) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Modo demo local: cualquier correo y contraseña '
                        'funcionan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
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
      backgroundColor: kAuthSurface,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: Colors.white70, height: 1.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Correo',
              icon: Icons.email_outlined,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emergency,
            foregroundColor: Colors.white,
          ),
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Enviar enlace'),
        ),
      ],
    );
  }
}
