import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
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

// ─────────────────────────── Hero del panel web ───────────────────────────

/// Panel lateral (solo web escritorio): identidad institucional de SIRE y las
/// capacidades del panel municipal, sobre un gradiente rojo de marca. Lo usan
/// login y registro para dar una entrada de escritorio coherente.
class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241413), Color(0xFF5C1512), AppColors.emergencyDark],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Motivo decorativo: anillos de "baliza" translúcidos.
          Positioned(top: -120, right: -120, child: _ring(360, 0.05)),
          Positioned(bottom: -80, left: -100, child: _ring(280, 0.04)),
          // Contenido.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lockup de marca.
                  Row(
                    children: [
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(Icons.shield,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIRE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'PANEL MUNICIPAL',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),

                  // Titular de valor.
                  const Text(
                    'Coordina la respuesta\nante emergencias del\nmunicipio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConfig.appTagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 44),

                  // Capacidades del panel.
                  const _HeroFeature(
                    icon: Icons.notifications_active_outlined,
                    titulo: 'Alertas SOS en tiempo real',
                    detalle: 'Recibe y atiende los reportes ciudadanos al '
                        'instante.',
                  ),
                  const SizedBox(height: 22),
                  const _HeroFeature(
                    icon: Icons.how_to_reg_outlined,
                    titulo: 'Validación de cuentas',
                    detalle: 'Aprueba a los ciudadanos por COCODE o '
                        'Municipalidad.',
                  ),
                  const SizedBox(height: 22),
                  const _HeroFeature(
                    icon: Icons.map_outlined,
                    titulo: 'Mapa en vivo del municipio',
                    detalle: 'Ubica cada incidente en el territorio a medida '
                        'que ocurre.',
                  ),
                  const SizedBox(height: 52),

                  // Pie institucional.
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        'San Miguel Sigüilá · Municipalidad',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, double alpha) => Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: alpha),
            width: 40,
          ),
        ),
      );
}

/// Fila de capacidad del hero (ícono en burbuja translúcida + texto).
class _HeroFeature extends StatelessWidget {
  const _HeroFeature({
    required this.icon,
    required this.titulo,
    required this.detalle,
  });

  final IconData icon;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detalle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
