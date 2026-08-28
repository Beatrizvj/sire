import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/power_button_bridge.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/validation/name_validator.dart';
import '../../../../core/validation/password_validator.dart';
import '../../../alerts/presentation/providers/sos_trigger_mode.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/user_role.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Ajustes del móvil (ambos roles): apariencia, disparo del SOS (solo
/// ciudadano) y cuenta (editar perfil y cambiar contraseña).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final perfil = ref.watch(currentUserProfileProvider).asData?.value;
    final esCiudadano = perfil?.rol == UserRole.ciudadano;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Apariencia ──────────────────────────────────────────────────
          const _SectionHeader('Apariencia', icon: Icons.palette_outlined),
          _ChoiceTile(
            icon: Icons.brightness_auto_outlined,
            title: 'Automático (según el sistema)',
            selected: themeMode == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.system),
          ),
          _ChoiceTile(
            icon: Icons.light_mode_outlined,
            title: 'Claro',
            selected: themeMode == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.light),
          ),
          _ChoiceTile(
            icon: Icons.dark_mode_outlined,
            title: 'Oscuro',
            selected: themeMode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
          ),

          // ── Alertas SOS (solo ciudadano) ────────────────────────────────
          if (esCiudadano) ...[
            const Divider(height: 24),
            const _SectionHeader('Cómo enviar un SOS',
                icon: Icons.sos_outlined),
            _SosModeTiles(current: ref.watch(sosTriggerModeProvider)),
          ],

          // ── Cuenta ──────────────────────────────────────────────────────
          const Divider(height: 24),
          const _SectionHeader('Cuenta', icon: Icons.manage_accounts_outlined),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Editar perfil'),
            subtitle: Text(perfil == null
                ? 'Cargando…'
                : 'Nombre y teléfono'),
            trailing: const Icon(Icons.chevron_right),
            onTap: perfil == null
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (_) => _EditProfileDialog(perfil: perfil),
                    ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            subtitle: const Text('Actualiza tu contraseña de acceso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _ChangePasswordDialog(),
            ),
          ),

          // ── Información ─────────────────────────────────────────────────
          const Divider(height: 24),
          const _SectionHeader('Información', icon: Icons.info_outline),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Acerca de SIRE'),
            subtitle: const Text('Versión, municipio y créditos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAcercaDe(context),
          ),
        ],
      ),
    );
  }
}

/// Diálogo "Acerca de" con la identidad del proyecto (versión, municipio y
/// créditos). Usa el diálogo estándar de Material (incluye licencias).
void _showAcercaDe(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: AppConfig.appName,
    applicationVersion: 'v1',
    applicationIcon: Icon(
      Icons.shield,
      size: 40,
      color: Theme.of(context).colorScheme.primary,
    ),
    children: const [
      SizedBox(height: 12),
      Text(AppConfig.appTagline),
      SizedBox(height: 8),
      Text('Municipalidad de San Miguel Sigüilá, Quetzaltenango.'),
      SizedBox(height: 8),
      Text('Proyecto de graduación · Universidad Mariano Gálvez de Guatemala.'),
    ],
  );
}

/// Tiles del modo de disparo del SOS. Al elegir un modo que NO usa el botón de
/// encendido, detiene el servicio nativo para que quede realmente apagado.
class _SosModeTiles extends ConsumerWidget {
  const _SosModeTiles({required this.current});

  final SosTriggerMode current;

  Future<void> _select(WidgetRef ref, SosTriggerMode mode) async {
    await ref.read(sosTriggerModeProvider.notifier).set(mode);
    if (!mode.usaEncendido) {
      // Ya no usa el botón de encendido: apaga la detección nativa.
      await ref.read(powerButtonBridgeProvider).stopDetection();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ChoiceTile(
          icon: Icons.touch_app_outlined,
          title: 'Ambos',
          subtitle: 'Botón en pantalla y botón de encendido',
          selected: current == SosTriggerMode.ambos,
          onTap: () => _select(ref, SosTriggerMode.ambos),
        ),
        _ChoiceTile(
          icon: Icons.smartphone_outlined,
          title: 'Solo botón en pantalla',
          subtitle: 'Únicamente el botón SOS de la app',
          selected: current == SosTriggerMode.pantalla,
          onTap: () => _select(ref, SosTriggerMode.pantalla),
        ),
        _ChoiceTile(
          icon: Icons.power_settings_new_outlined,
          title: 'Solo botón de encendido',
          subtitle: 'Pulsando el botón físico varias veces seguidas',
          selected: current == SosTriggerMode.encendido,
          onTap: () => _select(ref, SosTriggerMode.encendido),
        ),
      ],
    );
  }
}

// ─────────────────────────── Piezas de UI ───────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon,
          color: selected ? scheme.primary : scheme.onSurfaceVariant),
      title: Text(title,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.outline,
      ),
      onTap: onTap,
    );
  }
}

// ─────────────────────── Diálogo: editar perfil ───────────────────────

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.perfil});

  final AppUser perfil;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.perfil.nombre);
  late final _telefono = TextEditingController(text: widget.perfil.telefono);
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(userRepositoryProvider).saveUser(
            widget.perfil.copyWith(
              nombre: NameValidator.normalizar(_nombre.text),
              telefono: _telefono.text.trim(),
            ),
          );
      // El perfil se observa en vivo (currentUserProfileProvider), se refresca solo.
      navigator.pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Perfil actualizado.')),
        );
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => NameValidator.validar(v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 8)
                  ? 'Teléfono inválido'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────── Diálogo: cambiar contraseña ───────────────────────

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirma = TextEditingController();
  bool _obscure = true;
  bool _cambiando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cambiando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: _actual.text,
          newPassword: _nueva.text,
        );
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada.')),
        );
    } else {
      setState(() => _cambiando = false);
      final err = ref.read(authControllerProvider).error ??
          'No se pudo cambiar la contraseña.';
      messenger.showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _actual,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Escribe tu contraseña actual' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nueva,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                helperText: 'Mínimo 8 caracteres, con letra y número',
                prefixIcon: Icon(Icons.lock_reset_outlined),
                border: OutlineInputBorder(),
              ),
              validator: PasswordValidator.validar,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirma,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                prefixIcon: Icon(Icons.lock_reset_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v != _nueva.text ? 'Las contraseñas no coinciden' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cambiando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _cambiando ? null : _cambiar,
          child: _cambiando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cambiar'),
        ),
      ],
    );
  }
}
