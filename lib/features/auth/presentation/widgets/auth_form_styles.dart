import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Estilos compartidos por las pantallas de autenticación (login y registro).
///
/// Estas pantallas usan un diseño oscuro propio, independiente del brillo del
/// tema de la app, para dar una identidad institucional consistente al acceso.

// ── Paleta (tema oscuro fijo) ─────────────────────────────────────────────
const Color kAuthBackground = Color(0xFF121212); // fondo profesional oscuro
const Color kAuthSurface = Color(0xFF1E1E1E); // relleno de campos/tarjetas
const Color kAuthLightRed = Color(0xFFFF8A80); // rojo claro para enlaces
const Color kAuthError = Color(0xFFEF5350); // rojo de error en campos

/// Decoración compartida por los campos de texto en tema oscuro
/// (fondo oscuro, bordes redondeados y foco en rojo emergencia).
InputDecoration authFieldDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
  String? helperText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: kAuthSurface,
    prefixIcon: Icon(icon, color: Colors.white54),
    suffixIcon: suffixIcon,
    labelStyle: const TextStyle(color: Colors.white60),
    floatingLabelStyle: const TextStyle(color: Colors.white),
    enabledBorder: border(Colors.white12),
    focusedBorder: border(AppColors.emergency, 1.6),
    errorBorder: border(kAuthError),
    focusedErrorBorder: border(kAuthError, 1.6),
    errorStyle: const TextStyle(color: Color(0xFFEF9A9A)),
  );
}

/// Chip destacado con el municipio (identidad visual compartida).
class MunicipioChip extends StatelessWidget {
  const MunicipioChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.emergency.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.emergency.withValues(alpha: 0.30),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 15, color: kAuthLightRed),
          SizedBox(width: 6),
          Text(
            'San Miguel Sigüilá',
            style: TextStyle(
              color: kAuthLightRed,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Isologo municipal: escudo dentro de un círculo con opacidad.
class AuthLogoBadge extends StatelessWidget {
  const AuthLogoBadge({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.emergency.withValues(alpha: 0.12),
        border: Border.all(
          color: AppColors.emergency.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Icon(Icons.shield, size: size * 0.48, color: AppColors.emergency),
    );
  }
}
