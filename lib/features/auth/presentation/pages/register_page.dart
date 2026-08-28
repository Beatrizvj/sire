import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/validation/name_validator.dart';
import '../../../../core/validation/password_validator.dart';
import '../../../identity/data/identity_repository.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_form_styles.dart';

/// Ancho a partir del cual, **solo en web**, el registro pasa a pantalla
/// dividida (hero institucional + formulario), igual que el login.
const double _kWideBreakpoint = 900;

/// Localidades de San Miguel Sigüilá (aldea que declara el ciudadano).
const _aldeas = <String>['Cabecera', 'La Ciénaga', 'La Emboscada', 'El Llano'];

/// Registro de un nuevo usuario (crea identidad + perfil en `usuarios`).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _aldea;
  bool _obscure = true;

  // R2: fotos del DPI (obligatorias para completar el registro).
  final _picker = ImagePicker();
  Uint8List? _anverso;
  Uint8List? _reverso;
  bool _subiendo = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(String lado) async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kAuthSurface,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: Colors.white70),
              title: const Text('Tomar foto',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white70),
              title: const Text('Elegir de la galería',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fuente == null) return;
    // Achica la imagen al capturarla para que la foto (guardada como base64 en
    // Firestore) NUNCA supere el límite de 1 MB por documento.
    final foto = await _picker.pickImage(
        source: fuente, maxWidth: 1000, maxHeight: 1000, imageQuality: 70);
    if (foto == null) return;

    // Pantalla de recorte para ajustar bien el DPI. La compresión fuerte deja
    // la imagen liviana para Firestore (muy por debajo de 1 MB por documento).
    final recortada = await ImageCropper().cropImage(
      sourcePath: foto.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 40,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar foto del DPI',
          toolbarColor: const Color(0xFFC62828),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFC62828),
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Ajustar foto del DPI'),
      ],
    );
    if (recortada == null) return; // canceló el recorte
    final bytes = await recortada.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (lado == IdentityRepository.anverso) {
        _anverso = bytes;
      } else {
        _reverso = bytes;
      }
    });
  }

  void _descartar(String lado) {
    setState(() {
      if (lado == IdentityRepository.anverso) {
        _anverso = null;
      } else {
        _reverso = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_anverso == null || _reverso == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text(
            'Toma las dos fotos de tu DPI (anverso y reverso) para registrarte.',
          ),
        ));
      return;
    }

    setState(() => _subiendo = true);
    // Las fotos del DPI se envían al controlador, que las sube de forma
    // confiable (aunque la pantalla se cierre al pasar a "Cuenta en revisión").
    final ok = await ref.read(authControllerProvider.notifier).register(
          nombre: NameValidator.normalizar('${_nombre.text} ${_apellido.text}'),
          telefono: _telefono.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          aldeaSolicitada: _aldea ?? '',
          dpiAnverso: _anverso,
          dpiReverso: _reverso,
        );

    if (!mounted) return;
    setState(() => _subiendo = false);
    if (ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text(
            'Cuenta creada. Queda en revisión hasta que una autoridad '
            '(COCODE o Municipalidad) valide tu identidad y la apruebe.',
          ),
        ));
    }
    // Si falló, el error ya se muestra vía ref.listen.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // El hero split solo aparece en el panel web en pantallas anchas.
        final wide = kIsWeb && constraints.maxWidth >= _kWideBreakpoint;
        if (wide) {
          return Scaffold(
            backgroundColor: kAuthBackground,
            body: SafeArea(
              child: Row(
                children: [
                  const Expanded(flex: 6, child: AuthHeroPanel()),
                  Expanded(flex: 5, child: _formScroll(state, compact: true)),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: kAuthBackground,
          appBar: AppBar(
            backgroundColor: kAuthBackground,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Crear cuenta'),
          ),
          body: SafeArea(child: _formScroll(state, compact: false)),
        );
      },
    );
  }

  Widget _formScroll(AuthState state, {required bool compact}) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 48 : 24,
        vertical: compact ? 40 : 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _formContent(state, compact: compact),
        ),
      ),
    );
  }

  /// Formulario de registro. En [compact] (web) la marca vive en el hero, así
  /// que aquí solo va un encabezado breve; si no, la cabecera de marca completa.
  Widget _formContent(AuthState state, {required bool compact}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            const Text(
              'Crear cuenta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Completa tus datos. Tu cuenta quedará en revisión hasta que '
              'una autoridad la valide.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
          ] else ...[
            const Center(child: AuthLogoBadge(size: 64)),
            const SizedBox(height: 14),
            const Center(child: MunicipioChip()),
            const SizedBox(height: 6),
            const Text(
              'Crea tu cuenta ciudadana',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 26),
          ],

          // ── Datos personales ─────────────────────────────────────────────
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Nombre(s)',
              icon: Icons.person_outline,
            ),
            validator: (v) => NameValidator.validar(v, campo: 'nombre'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _apellido,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Apellido(s)',
              icon: Icons.badge_outlined,
            ),
            validator: (v) => NameValidator.validar(v, campo: 'apellido'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Teléfono',
              icon: Icons.phone_outlined,
            ),
            validator: (v) => (v == null || v.trim().length < 8)
                ? 'Teléfono inválido'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Correo',
              icon: Icons.email_outlined,
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
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.emergency,
            decoration: authFieldDecoration(
              label: 'Contraseña',
              icon: Icons.lock_outline,
              helperText: 'Mínimo 8 caracteres, con letra y número',
              suffixIcon: IconButton(
                tooltip:
                    _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: PasswordValidator.validar,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _aldea,
            isExpanded: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            dropdownColor: kAuthSurface,
            iconEnabledColor: Colors.white54,
            decoration: authFieldDecoration(
              label: 'Aldea / Localidad',
              icon: Icons.groups_outlined,
            ),
            items: _aldeas
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (a) => setState(() => _aldea = a),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Selecciona tu aldea' : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu rol lo asignará una autoridad (COCODE o Municipalidad) al '
            'revisar tu cuenta. No se asigna automáticamente.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          // ── Verificación de identidad (DPI) ──────────────────────────────
          const Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: Colors.white54),
              SizedBox(width: 8),
              Text(
                'Verificación de identidad (DPI)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Toma una foto de cada lado de tu DPI. Solo se usan para validar '
            'tu identidad; se guardan de forma privada.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FotoDpi(
                  etiqueta: 'DPI · Anverso',
                  bytes: _anverso,
                  onTap: () => _tomarFoto(IdentityRepository.anverso),
                  onDiscard: () => _descartar(IdentityRepository.anverso),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FotoDpi(
                  etiqueta: 'DPI · Reverso',
                  bytes: _reverso,
                  onTap: () => _tomarFoto(IdentityRepository.reverso),
                  onDiscard: () => _descartar(IdentityRepository.reverso),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Botón principal ──────────────────────────────────────────────
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
              onPressed: (state.isBusy || _subiendo) ? null : _submit,
              child: (state.isBusy || _subiendo)
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Crear cuenta'),
            ),
          ),
          const SizedBox(height: 14),

          // ── Enlace a login ───────────────────────────────────────────────
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.login),
              style: TextButton.styleFrom(foregroundColor: kAuthLightRed),
              child: Text.rich(
                const TextSpan(
                  text: '¿Ya tienes cuenta?  ',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Inicia sesión',
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

          // Nota de modo demo local (solo si Firebase está apagado).
          if (!AppConfig.firebaseEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              'Modo demo local: el registro se guarda en el dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recuadro para tomar/mostrar una foto del DPI.
class _FotoDpi extends StatelessWidget {
  const _FotoDpi({
    required this.etiqueta,
    required this.bytes,
    required this.onTap,
    required this.onDiscard,
  });

  final String etiqueta;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = bytes != null;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: kAuthSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tieneFoto ? AppColors.emergency : Colors.white24,
                width: tieneFoto ? 2 : 1,
              ),
              image: tieneFoto
                  ? DecorationImage(
                      image: MemoryImage(bytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: tieneFoto
                ? const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.emergency,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined,
                          color: Colors.white54),
                      const SizedBox(height: 6),
                      Text(etiqueta,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54)),
                    ],
                  ),
          ),
        ),
        if (tieneFoto)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
                TextButton.icon(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label:
                      const Text('Descartar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: kAuthLightRed,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
