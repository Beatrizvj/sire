import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/validation/name_validator.dart';
import '../../../alerts/domain/entities/alert_status.dart';
import '../../../alerts/domain/entities/sos_alert.dart';
import '../../../alerts/presentation/providers/alerts_providers.dart';
import '../../../alerts/presentation/widgets/alarm_sound.dart';
import '../../../alerts/presentation/widgets/alert_status_chip.dart';
import '../../../alerts/presentation/widgets/new_alert_alarm.dart';
import '../../../audit/data/audit_repository.dart';
import '../../../audit/domain/audit_entry.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../identity/data/identity_repository.dart';
import '../../../incidents/data/incident_category_repository.dart';
import '../../../reports/presentation/reports_page.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/user_role.dart';
import '../../../users/presentation/providers/approvals_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

// Paleta del panel (según el prototipo): barra lateral oscura, contenido claro.
const _side = Color(0xFF2B1917);
const _sideActive = Color(0xFF3D2624);
const _sideText = Color(0xFFD9C6C3);
const _brand = Color(0xFFC62828);
const _bg = Color(0xFFFFF8F6);
const _line = Color(0xFFEADFDD);

const _crit = (Color(0xFFBA1A1A), Color(0xFFFFDAD6));
const _warn = (Color(0xFF8A5A00), Color(0xFFFFE7B8));
const _good = (Color(0xFF2E6B32), Color(0xFFCFEBD0));
const _neut = (Color(0xFF6B5A57), Color(0xFFEDE5E3));

/// Centro aproximado de San Miguel Sigüilá para el mapa en vivo del panel.
const LatLng _centroMunicipioPanel = LatLng(14.8726, -91.6009);

const _comunidades = ['Cabecera', 'La Ciénaga', 'La Emboscada', 'El Llano'];

const _secciones = <(IconData, String)>[
  (Icons.dashboard_outlined, 'Dashboard'),
  (Icons.notifications_outlined, 'Alertas'),
  (Icons.group_outlined, 'Usuarios'),
  (Icons.how_to_reg_outlined, 'Aprobaciones'),
  (Icons.holiday_village_outlined, 'Comunidades'),
  (Icons.map_outlined, 'Mapa en vivo'),
  (Icons.insights_outlined, 'Reportes'),
  (Icons.settings_outlined, 'Configuración'),
];

// Índices de sección (para badges y ruteo legible).
const _ixAlertas = 1;
const _ixAprobaciones = 3;

/// Panel web municipal (consola de escritorio, **responsive**). Reusa los mismos
/// providers y datos de Firestore que la app móvil. Solo lo ven COCODE y
/// Municipalidad (el control de acceso vive en AppShell).
class WebPanel extends ConsumerStatefulWidget {
  const WebPanel({super.key});

  @override
  ConsumerState<WebPanel> createState() => _WebPanelState();
}

class _WebPanelState extends ConsumerState<WebPanel> {
  int _seccion = 0;
  // Los navegadores bloquean el audio hasta un gesto del usuario; el botón
  // "Activar sonido" lo habilita y aquí se recuerda mientras dure la sesión.
  bool _sonidoActivado = false;

  Widget _cuerpo(int i) => switch (i) {
        0 => const _Dashboard(),
        1 => const _AlertasBody(),
        2 => const _UsuariosBody(),
        3 => const _AprobacionesBody(),
        4 => const _ComunidadesBody(),
        5 => const _MapaEnVivoBody(),
        6 => const ReportesBody(),
        _ => const _ConfiguracionBody(),
      };

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.of(context).size.width < 1000;
    final pendientes = ref.watch(allAlertsProvider).asData?.value
            .where((a) => a.status == AlertStatus.pendiente)
            .length ??
        0;

    // R1: cuántas cuentas le toca revisar a esta autoridad.
    final actor = ref.watch(currentUserProfileProvider).asData?.value;
    final todos = ref.watch(allUsersProvider).asData?.value ?? const [];
    final pendientesAprob =
        actor == null ? 0 : pendientesPara(todos, actor).length;

    Widget barra({required bool enDrawer}) => _SidebarContent(
          seleccion: _seccion,
          pendientes: pendientes,
          pendientesAprob: pendientesAprob,
          onSelect: (i) {
            setState(() => _seccion = i);
            if (enDrawer) Navigator.of(context).pop();
          },
          onLogout: () =>
              ref.read(authControllerProvider.notifier).signOut(),
        );

    final cuerpo = Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.light),
        scaffoldBackgroundColor: _bg,
      ),
      child: Container(color: _bg, child: _cuerpo(_seccion)),
    );

    final Widget scaffold = compacto
        ? Scaffold(
            appBar: AppBar(
              backgroundColor: _side,
              foregroundColor: Colors.white,
              title: Text(_secciones[_seccion].$2),
            ),
            drawer: Drawer(
              backgroundColor: _side,
              child: barra(enDrawer: true),
            ),
            body: cuerpo,
          )
        : Scaffold(
            body: Row(
              children: [
                Container(
                    width: 232, color: _side, child: barra(enDrawer: false)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        titulo: _secciones[_seccion].$2,
                        sonidoActivado: _sonidoActivado,
                        onActivarSonido: () =>
                            setState(() => _sonidoActivado = true),
                      ),
                      Expanded(child: cuerpo),
                    ],
                  ),
                ),
              ],
            ),
          );

    // RF-14: alarma sonora + aviso visual cuando entra una alerta nueva.
    return Stack(
      children: [
        scaffold,
        NewAlertAlarm(onVer: () => setState(() => _seccion = _ixAlertas)),
      ],
    );
  }
}

// ─────────────────────────── Barra lateral ───────────────────────────

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.seleccion,
    required this.pendientes,
    required this.pendientesAprob,
    required this.onSelect,
    required this.onLogout,
  });

  final int seleccion;
  final int pendientes;
  final int pendientesAprob;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  String? _badgeDe(int i) {
    if (i == _ixAlertas && pendientes > 0) return '$pendientes';
    if (i == _ixAprobaciones && pendientesAprob > 0) return '$pendientesAprob';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('S',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SIRE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('PANEL MUNICIPAL',
                        style: TextStyle(
                            color: _sideText, fontSize: 8, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < _secciones.length; i++)
            _NavItem(
              icon: _secciones[i].$1,
              label: _secciones[i].$2,
              activo: seleccion == i,
              badge: _badgeDe(i),
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 6, 18, 6),
            child: Text('San Miguel Sigüilá\nMunicipalidad',
                style: TextStyle(color: _sideText, fontSize: 10, height: 1.4)),
          ),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 16, color: _sideText),
            label: const Text('Cerrar sesión',
                style: TextStyle(color: _sideText, fontSize: 12)),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: activo ? _sideActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18, color: activo ? Colors.white : _sideText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: activo ? Colors.white : _sideText,
                          fontSize: 13,
                          fontWeight:
                              activo ? FontWeight.w600 : FontWeight.normal)),
                ),
                if (badge case final b?)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _crit.$1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(b,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.titulo,
    required this.sonidoActivado,
    required this.onActivarSonido,
  });

  final String titulo;
  final bool sonidoActivado;
  final VoidCallback onActivarSonido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text(titulo,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          _BotonActivarSonido(
              activado: sonidoActivado, onActivar: onActivarSonido),
          const SizedBox(width: 16),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _good.$1, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('En vivo',
              style: TextStyle(
                  color: _good.$1, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Dashboard ───────────────────────────

class _Dashboard extends ConsumerWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(allAlertsProvider).asData?.value ?? const [];
    final users = ref.watch(allUsersProvider).asData?.value ?? const [];
    final pendientes =
        alerts.where((a) => a.status == AlertStatus.pendiente).length;
    final ciudadanos = users.where((u) => u.rol == UserRole.ciudadano).length;
    final ultimas = [...alerts]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _Kpi(
                  label: 'Pendientes',
                  valor: '$pendientes',
                  nota: 'requieren atención',
                  critico: true),
              _Kpi(
                  label: 'Alertas totales',
                  valor: '${alerts.length}',
                  nota: 'registradas'),
              _Kpi(
                  label: 'Ciudadanos',
                  valor: '$ciudadanos',
                  nota: 'registrados'),
              _Kpi(
                  label: 'Usuarios',
                  valor: '${users.length}',
                  nota: 'en el sistema'),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            titulo: 'Últimas alertas',
            child: ultimas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Aún no hay alertas.')),
                  )
                : _TablaAlertas(alertas: ultimas.take(8).toList()),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.valor,
    required this.nota,
    this.critico = false,
  });

  final String label;
  final String valor;
  final String nota;
  final bool critico;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B5A57))),
          const SizedBox(height: 6),
          Text(valor,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: critico ? _crit.$1 : const Color(0xFF231918))),
          Text(nota,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5A57))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(titulo,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────── Tabla de alertas ───────────────────────────

class _TablaAlertas extends ConsumerWidget {
  const _TablaAlertas({required this.alertas, this.conAcciones = false});

  final List<SosAlert> alertas;
  final bool conAcciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 26,
        headingRowHeight: 40,
        columns: [
          const DataColumn(label: Text('Ciudadano')),
          const DataColumn(label: Text('Ubicación')),
          const DataColumn(label: Text('Origen')),
          const DataColumn(label: Text('Tipo')),
          const DataColumn(label: Text('Fecha')),
          const DataColumn(label: Text('Estado')),
          const DataColumn(label: Text('Respuesta')),
          if (conAcciones) const DataColumn(label: Text('Acción')),
        ],
        rows: [
          for (final a in alertas)
            DataRow(cells: [
              DataCell(Text(
                  (a.userName != null && a.userName!.isNotEmpty)
                      ? a.userName!
                      : 'Ciudadano',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(SizedBox(
                width: 210,
                child: Text(
                  a.address ??
                      ((a.latitude == 0 && a.longitude == 0)
                          ? 'Sin ubicación'
                          : '${a.latitude.toStringAsFixed(5)}, ${a.longitude.toStringAsFixed(5)}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(Text(a.source.label)),
              DataCell(_CategoriaChip(categoria: a.categoria)),
              DataCell(Text(df.format(a.timestamp))),
              DataCell(_EstadoChip(status: a.status)),
              DataCell(Text(a.tiempoRespuesta != null
                  ? formatearDuracion(a.tiempoRespuesta!)
                  : '—')),
              if (conAcciones) DataCell(_AccionesAlerta(alerta: a, ref: ref)),
            ]),
        ],
      ),
    );
  }
}

class _AccionesAlerta extends StatelessWidget {
  const _AccionesAlerta({required this.alerta, required this.ref});

  final SosAlert alerta;
  final WidgetRef ref;

  Future<void> _set(BuildContext context, AlertStatus s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(alertsControllerProvider.notifier)
          .updateStatus(alerta.id, s);
      messenger.showSnackBar(
          SnackBar(content: Text('Alerta marcada como ${s.label}.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _clasificar(BuildContext context, String categoria) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(alertsControllerProvider.notifier)
          .updateCategoria(alerta.id, categoria);
      messenger.showSnackBar(
          SnackBar(content: Text('Clasificada como "$categoria".')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasActivasProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<AlertStatus>(
          tooltip: 'Cambiar estado',
          onSelected: (s) => _set(context, s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: AlertStatus.atendida, child: Text('Atender')),
            PopupMenuItem(value: AlertStatus.resuelta, child: Text('Resolver')),
            PopupMenuItem(
                value: AlertStatus.falsaAlarma, child: Text('Falsa alarma')),
          ],
          child: const Chip(
            label: Text('Gestionar', style: TextStyle(fontSize: 12)),
            avatar: Icon(Icons.expand_more, size: 16),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Clasificar incidente',
          onSelected: (c) => _clasificar(context, c),
          itemBuilder: (_) => [
            for (final c in categorias)
              PopupMenuItem(value: c, child: Text(c)),
          ],
          child: const Chip(
            label: Text('Clasificar', style: TextStyle(fontSize: 12)),
            avatar: Icon(Icons.label_outline, size: 16),
          ),
        ),
      ],
    );
  }
}

class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({required this.categoria});

  final String? categoria;

  @override
  Widget build(BuildContext context) {
    final sinEspecificar = categoria == null || categoria!.isEmpty;
    final (fg, bg) = sinEspecificar ? _neut : _crit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        sinEspecificar ? 'Sin especificar' : categoria!,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────── Alertas ───────────────────────────

class _AlertasBody extends ConsumerWidget {
  const _AlertasBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(allAlertsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Error(
              mensaje: '$e',
              onRetry: () => ref.invalidate(allAlertsProvider)),
          data: (alertas) {
            if (alertas.isEmpty) {
              return const Center(child: Text('Aún no hay alertas.'));
            }
            final ordenadas = [...alertas]
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _Card(
                titulo: '${ordenadas.length} alertas',
                child: _TablaAlertas(alertas: ordenadas, conAcciones: true),
              ),
            );
          },
        );
  }
}

// ─────────────────────────── Usuarios ───────────────────────────

class _UsuariosBody extends ConsumerWidget {
  const _UsuariosBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserProfileProvider).asData?.value;
    final esVerificador = actor?.puedeVerIdentidad ?? false;
    return ref.watch(allUsersProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Error(
              mensaje: '$e', onRetry: () => ref.invalidate(allUsersProvider)),
          data: (users) {
            if (users.isEmpty) {
              return const Center(child: Text('No hay usuarios.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _Card(
                titulo: '${users.length} usuarios registrados',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 26,
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Correo')),
                      DataColumn(label: Text('Comunidad')),
                      DataColumn(label: Text('Rol')),
                      DataColumn(label: Text('Acción')),
                    ],
                    rows: [
                      for (final u in users)
                        DataRow(cells: [
                          DataCell(Text(u.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                          DataCell(Text(u.email ?? '')),
                          DataCell(Text(u.aldea.isEmpty ? '—' : u.aldea)),
                          DataCell(_RolChip(rol: u.rol)),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (esVerificador && actor != null)
                                TextButton(
                                  onPressed: () => verDpi(context, ref,
                                      objetivo: u, actor: actor),
                                  child: const Text('Ver DPI'),
                                ),
                              TextButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => _EditarUsuario(usuario: u),
                                ),
                                child: const Text('Editar'),
                              ),
                            ],
                          )),
                        ]),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }
}

class _EditarUsuario extends ConsumerStatefulWidget {
  const _EditarUsuario({required this.usuario});

  final AppUser usuario;

  @override
  ConsumerState<_EditarUsuario> createState() => _EditarUsuarioState();
}

class _EditarUsuarioState extends ConsumerState<_EditarUsuario> {
  late UserRole _rol = widget.usuario.rol;
  late String _comunidad =
      _comunidades.contains(widget.usuario.aldea) ? widget.usuario.aldea : '';
  late bool _verIdentidad = widget.usuario.puedeVerIdentidad;
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.usuario.nombre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rol', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final r in UserRole.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _rol == r,
                  onSelected: (_) => setState(() => _rol = r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Comunidad',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sin asignar'),
                selected: _comunidad.isEmpty,
                onSelected: (_) => setState(() => _comunidad = ''),
              ),
              for (final c in _comunidades)
                ChoiceChip(
                  label: Text(c),
                  selected: _comunidad == c,
                  onSelected: (_) => setState(() => _comunidad = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _brand,
            value: _verIdentidad,
            onChanged: (v) => setState(() => _verIdentidad = v),
            title: const Text('Puede ver fotos del DPI',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text(
                'Autoriza a esta persona a ver las fotos de identidad de otros '
                'usuarios (verificador).',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (ref.watch(currentUserProfileProvider).asData?.value?.rol ==
            UserRole.municipalidad)
          TextButton(
            onPressed: _guardando ? null : _eliminar,
            style: TextButton.styleFrom(foregroundColor: _crit.$1),
            child: const Text('Eliminar'),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _guardando ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('¿Eliminar a ${widget.usuario.nombre}?'),
        content: const Text(
          'Se borrará su perfil y sus fotos de DPI de la base de datos. '
          'Su cuenta de acceso (Authentication) debe borrarse aparte desde la '
          'consola de Firebase. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _crit.$1),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final actor = ref.read(currentUserProfileProvider).asData?.value;
    try {
      await ref.read(identityRepositoryProvider).eliminar(widget.usuario.id);
      await ref.read(userRepositoryProvider).deleteUser(widget.usuario.id);
      if (actor != null) {
        await ref.read(auditRepositoryProvider).registrar(AuditEntry(
              accion: 'eliminar_usuario',
              actorUid: actor.id,
              actorRol: actor.rol.value,
              objetivoUid: widget.usuario.id,
              objetivoNombre: widget.usuario.nombre,
            ));
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.usuario.nombre} eliminado.')),
      );
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(userRepositoryProvider).saveUser(
            widget.usuario.copyWith(
              rol: _rol,
              aldea: _comunidad,
              puedeVerIdentidad: _verIdentidad,
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.usuario.nombre} → ${_rol.label}.')),
      );
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ─────────────────────────── Comunidades ───────────────────────────

class _ComunidadesBody extends ConsumerWidget {
  const _ComunidadesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(allUsersProvider).asData?.value ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final c in _comunidades)
            _ComunidadCard(
              nombre: c,
              usuarios: users.where((u) => u.aldea == c).length,
              cocode: users
                  .where((u) => u.aldea == c && u.rol == UserRole.cocode)
                  .length,
            ),
          _ComunidadCard(
            nombre: 'Sin asignar',
            usuarios: users.where((u) => u.aldea.isEmpty).length,
            cocode: 0,
          ),
        ],
      ),
    );
  }
}

class _ComunidadCard extends StatelessWidget {
  const _ComunidadCard({
    required this.nombre,
    required this.usuarios,
    required this.cocode,
  });

  final String nombre;
  final int usuarios;
  final int cocode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.holiday_village_outlined,
                  color: _brand, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('$usuarios',
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold)),
          const Text('usuarios registrados',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B5A57))),
          const SizedBox(height: 6),
          Text('$cocode COCODE asignado(s)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B5A57))),
        ],
      ),
    );
  }
}

// ─────────────────────────── Aprobaciones (R1) ───────────────────────────

class _AprobacionesBody extends ConsumerWidget {
  const _AprobacionesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserProfileProvider).asData?.value;
    final usuariosAsync = ref.watch(allUsersProvider);

    if (actor == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return usuariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar: $e')),
      data: (todos) {
        final pendientes = pendientesPara(todos, actor);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                titulo: actor.rol == UserRole.municipalidad
                    ? 'Solicitudes pendientes · todo el municipio'
                    : 'Solicitudes pendientes · aldea ${actor.aldea.isEmpty ? "(sin asignar)" : actor.aldea}',
                child: pendientes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay cuentas pendientes de revisión.',
                          style: TextStyle(color: Color(0xFF6B5A57)),
                        ),
                      )
                    : Column(
                        children: [
                          for (final u in pendientes)
                            _SolicitudTile(actor: actor, objetivo: u),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SolicitudTile extends ConsumerWidget {
  const _SolicitudTile({required this.actor, required this.objetivo});

  final AppUser actor;
  final AppUser objetivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFEDE5E3),
            child: Icon(Icons.person_outline, color: Color(0xFF6B5A57)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(objetivo.nombre.isEmpty ? '(sin nombre)' : objetivo.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${objetivo.email ?? "—"}  ·  Tel: ${objetivo.telefono.isEmpty ? "—" : objetivo.telefono}',
                  style: const TextStyle(color: Color(0xFF6B5A57), fontSize: 12),
                ),
                Text(
                  'Aldea declarada: ${objetivo.aldeaSolicitada.isEmpty ? "—" : objetivo.aldeaSolicitada}',
                  style: const TextStyle(color: Color(0xFF6B5A57), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (actor.puedeVerIdentidad)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: () =>
                    verDpi(context, ref, objetivo: objetivo, actor: actor),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Ver DPI'),
              ),
            ),
          OutlinedButton(
            onPressed: () => _rechazar(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: _crit.$1),
            child: const Text('Rechazar'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            onPressed: () => _aprobar(context, ref),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }

  Future<void> _aprobar(BuildContext context, WidgetRef ref) async {
    // La Municipalidad puede asignar cualquier rol; el COCODE solo Ciudadano.
    final rolesPermitidos = actor.rol == UserRole.municipalidad
        ? [UserRole.ciudadano, UserRole.cocode, UserRole.municipalidad]
        : [UserRole.ciudadano];
    var rol = rolesPermitidos.first;
    var aldea = objetivo.aldeaSolicitada.isEmpty
        ? (actor.aldea.isEmpty ? _comunidades.first : actor.aldea)
        : objetivo.aldeaSolicitada;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setState) => AlertDialog(
          title: Text('Aprobar a ${objetivo.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: rol,
                decoration: const InputDecoration(
                    labelText: 'Rol a asignar', border: OutlineInputBorder()),
                items: rolesPermitidos
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (r) => setState(() => rol = r ?? rol),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    _comunidades.contains(aldea) ? aldea : _comunidades.first,
                decoration: const InputDecoration(
                    labelText: 'Aldea / Comunidad',
                    border: OutlineInputBorder()),
                items: _comunidades
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (a) => setState(() => aldea = a ?? aldea),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _brand),
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Aprobar')),
          ],
        ),
      ),
    );
    if (confirmado != true) return;
    try {
      await ref.read(approvalsServiceProvider).aprobar(
            objetivo,
            rol: rol,
            aldea: _comunidades.contains(aldea) ? aldea : _comunidades.first,
            actor: actor,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${objetivo.nombre} aprobado como ${rol.label}.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo aprobar: $e')));
    }
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref) async {
    final motivoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Rechazar a ${objetivo.nombre}'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _crit.$1),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Rechazar')),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ref.read(approvalsServiceProvider).rechazar(
            objetivo,
            actor: actor,
            motivo: motivoCtrl.text.trim(),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solicitud de ${objetivo.nombre} rechazada.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
    }
  }
}

// ─────────────────────── Ver fotos del DPI (R2) ───────────────────────

/// Abre el visor de fotos del DPI de [objetivo]. Solo para verificadores
/// autorizados; registra el acceso en auditoría antes de mostrarlas.
Future<void> verDpi(
  BuildContext context,
  WidgetRef ref, {
  required AppUser objetivo,
  required AppUser actor,
}) async {
  // Trazabilidad: queda registrado quién vio el DPI de quién y cuándo.
  await ref.read(auditRepositoryProvider).registrar(AuditEntry(
        accion: 'ver_foto_id',
        actorUid: actor.id,
        actorRol: actor.rol.value,
        objetivoUid: objetivo.id,
        objetivoNombre: objetivo.nombre,
      ));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _VerDpiDialog(objetivo: objetivo),
  );
}

class _VerDpiDialog extends ConsumerStatefulWidget {
  const _VerDpiDialog({required this.objetivo});

  final AppUser objetivo;

  @override
  ConsumerState<_VerDpiDialog> createState() => _VerDpiDialogState();
}

class _VerDpiDialogState extends ConsumerState<_VerDpiDialog> {
  Uint8List? _anverso;
  Uint8List? _reverso;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = ref.read(identityRepositoryProvider);
    final a = await repo.descargar(
        uid: widget.objetivo.id, lado: IdentityRepository.anverso);
    final r = await repo.descargar(
        uid: widget.objetivo.id, lado: IdentityRepository.reverso);
    if (!mounted) return;
    setState(() {
      _anverso = a;
      _reverso = r;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('DPI de ${widget.objetivo.nombre}'),
      content: SizedBox(
        width: 520,
        child: _cargando
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : (_anverso == null && _reverso == null)
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Este usuario no tiene fotos de DPI registradas.'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _foto('Anverso', _anverso),
                      const SizedBox(height: 12),
                      _foto('Reverso', _reverso),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _foto(String etiqueta, Uint8List? bytes) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF6B5A57))),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: Image.memory(bytes,
                        width: double.infinity, fit: BoxFit.contain),
                  )
                : Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: const Color(0xFFEDE5E3),
                    child: const Text('No disponible'),
                  ),
          ),
        ],
      );
}

// ─────────────────────── Categorías de incidente (R3) ───────────────────────

class _CategoriasIncidenteCard extends ConsumerStatefulWidget {
  const _CategoriasIncidenteCard();

  @override
  ConsumerState<_CategoriasIncidenteCard> createState() =>
      _CategoriasIncidenteCardState();
}

class _CategoriasIncidenteCardState
    extends ConsumerState<_CategoriasIncidenteCard> {
  final _nuevaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Siembra las 3 categorías por defecto la primera vez (idempotente).
    Future.microtask(() =>
        ref.read(incidentCategoryRepositoryProvider).seedDefaultsIfEmpty());
  }

  @override
  void dispose() {
    _nuevaCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final nombre = _nuevaCtrl.text.trim();
    if (nombre.isEmpty) return;
    await ref.read(incidentCategoryRepositoryProvider).add(nombre);
    _nuevaCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriasProvider).asData?.value ?? const [];
    return _Card(
      titulo: 'Categorías de incidente',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tipos de incidente que el ciudadano puede reportar. Puedes '
              'activarlos, desactivarlos o agregar nuevos.',
              style: TextStyle(color: Color(0xFF6B5A57), fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: c.activo ? null : const Color(0xFF9E9E9E),
                            decoration:
                                c.activo ? null : TextDecoration.lineThrough,
                          )),
                    ),
                    Switch(
                      value: c.activo,
                      activeThumbColor: _brand,
                      onChanged: (v) => ref
                          .read(incidentCategoryRepositoryProvider)
                          .setActivo(c.id, v),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: _crit.$1,
                      onPressed: () => ref
                          .read(incidentCategoryRepositoryProvider)
                          .remove(c.id),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nuevaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _agregar(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  onPressed: _agregar,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Configuración ───────────────────────────

class _ConfiguracionBody extends ConsumerStatefulWidget {
  const _ConfiguracionBody();

  @override
  ConsumerState<_ConfiguracionBody> createState() => _ConfiguracionBodyState();
}

class _ConfiguracionBodyState extends ConsumerState<_ConfiguracionBody> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String? _cargadoParaId; // inicializa los campos una sola vez por usuario.
  bool _guardando = false;

  // Cambiar contraseña.
  final _passFormKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmaCtrl = TextEditingController();
  bool _cambiandoPass = false;
  bool _verPass = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    if (!_passFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cambiandoPass = true);
    final ok = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: _actualCtrl.text,
          newPassword: _nuevaCtrl.text,
        );
    if (!mounted) return;
    setState(() => _cambiandoPass = false);
    if (ok) {
      _actualCtrl.clear();
      _nuevaCtrl.clear();
      _confirmaCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    } else {
      final err = ref.read(authControllerProvider).error ??
          'No se pudo cambiar la contraseña.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<void> _guardar(AppUser perfil) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final actualizado = perfil.copyWith(
        nombre: NameValidator.normalizar(_nombreCtrl.text),
        telefono: _telefonoCtrl.text.trim(),
      );
      await ref.read(userRepositoryProvider).saveUser(actualizado);
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(currentUserProfileProvider).asData?.value;
    if (perfil == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Carga los datos actuales en los campos la primera vez (o si cambia el uid).
    if (_cargadoParaId != perfil.id) {
      _cargadoParaId = perfil.id;
      _nombreCtrl.text = perfil.nombre;
      _telefonoCtrl.text = perfil.telefono;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            titulo: 'Editar mi perfil',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _campo(
                      controlador: _nombreCtrl,
                      etiqueta: 'Nombre',
                      icono: Icons.person_outline,
                      validador: (v) => NameValidator.validar(v),
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      controlador: _telefonoCtrl,
                      etiqueta: 'Teléfono',
                      icono: Icons.phone_outlined,
                      teclado: TextInputType.phone,
                      validador: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Escribe tu teléfono.';
                        if (t.length < 8) return 'Teléfono muy corto.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    // Campos de identidad: solo lectura (los asigna la autoridad).
                    _fila('Correo', perfil.email ?? '—'),
                    _fila('Rol', perfil.rol.label),
                    _fila('Comunidad',
                        perfil.aldea.isEmpty ? '—' : perfil.aldea),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _brand),
                        onPressed: _guardando ? null : () => _guardar(perfil),
                        icon: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                            _guardando ? 'Guardando…' : 'Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            titulo: 'Cambiar contraseña',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _passFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _campo(
                      controlador: _actualCtrl,
                      etiqueta: 'Contraseña actual',
                      icono: Icons.lock_outline,
                      oculto: !_verPass,
                      validador: (v) => (v == null || v.isEmpty)
                          ? 'Escribe tu contraseña actual.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      controlador: _nuevaCtrl,
                      etiqueta: 'Nueva contraseña',
                      icono: Icons.lock_reset_outlined,
                      oculto: !_verPass,
                      validador: (v) {
                        final t = v ?? '';
                        if (t.length < 6) {
                          return 'Mínimo 6 caracteres.';
                        }
                        if (t == _actualCtrl.text) {
                          return 'Debe ser distinta a la actual.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _campo(
                      controlador: _confirmaCtrl,
                      etiqueta: 'Confirmar nueva contraseña',
                      icono: Icons.lock_reset_outlined,
                      oculto: !_verPass,
                      validador: (v) => (v != _nuevaCtrl.text)
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _verPass,
                          activeColor: _brand,
                          onChanged: (v) =>
                              setState(() => _verPass = v ?? false),
                        ),
                        const Text('Mostrar contraseñas'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _brand),
                        onPressed:
                            _cambiandoPass ? null : _cambiarContrasena,
                        icon: _cambiandoPass
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_cambiandoPass
                            ? 'Actualizando…'
                            : 'Actualizar contraseña'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (perfil.rol == UserRole.municipalidad) ...[
            const SizedBox(height: 16),
            const _CategoriasIncidenteCard(),
          ],
          const SizedBox(height: 16),
          _Card(
            titulo: 'Sistema',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fila('Proyecto', 'sire-app-179d3'),
                  _fila('Fuente de datos', 'Cloud Firestore (tiempo real)'),
                  _fila('Acceso', 'COCODE · Municipalidad'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required String etiqueta,
    required IconData icono,
    String? Function(String?)? validador,
    TextInputType? teclado,
    bool oculto = false,
  }) =>
      TextFormField(
        controller: controlador,
        keyboardType: teclado,
        validator: validador,
        obscureText: oculto,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _brand, width: 2),
          ),
        ),
      );

  Widget _fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
                width: 130,
                child: Text(k,
                    style: const TextStyle(color: Color(0xFF6B5A57)))),
            Expanded(
                child:
                    Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

// ─────────────────────────── Chips y helpers ───────────────────────────

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final c = alertStatusColors(status);
    return _pill(status.label, c.fg, c.bg);
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});

  final UserRole rol;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (rol) {
      UserRole.ciudadano => _neut,
      UserRole.cocode => _warn,
      UserRole.municipalidad => _crit,
    };
    return _pill(rol.label, fg, bg);
  }
}

Widget _pill(String texto, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(texto,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );

/// Botón que desbloquea el audio del navegador para que suene la alarma de
/// alertas nuevas (los navegadores exigen un gesto del usuario antes de
/// reproducir sonido de forma automática).
class _BotonActivarSonido extends StatelessWidget {
  const _BotonActivarSonido({required this.activado, required this.onActivar});

  final bool activado;
  final VoidCallback onActivar;

  Future<void> _activar(BuildContext context) async {
    // El clic del usuario desbloquea el audio del navegador. Reproducimos la
    // sirena una vez (con el <audio> nativo del navegador) para confirmar que
    // suena y dejar habilitadas las alarmas siguientes.
    String msg;
    try {
      await alarmOnce();
      msg = 'Reproduciendo sirena de prueba. Si NO la oyes: sube el volumen del '
          'sistema y revisa que la pestaña no esté silenciada.';
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await alarmStop();
    } catch (e) {
      msg = 'No se pudo reproducir: $e';
    }
    onActivar();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activado) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, size: 16, color: _good.$1),
          const SizedBox(width: 6),
          Text('Sonido activado',
              style: TextStyle(
                  color: _good.$1, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _activar(context),
      icon: const Icon(Icons.volume_off, size: 16),
      label: const Text('Activar sonido'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _brand,
        side: const BorderSide(color: _line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Mapa en vivo del panel: ubica las alertas activas (pendiente / en atención)
/// sobre OpenStreetMap. No requiere Google Maps ni cuenta de facturación.
class _MapaEnVivoBody extends ConsumerWidget {
  const _MapaEnVivoBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(allAlertsProvider);
    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo cargar el mapa.\n$e',
              textAlign: TextAlign.center),
        ),
      ),
      data: (alerts) {
        final activas = alerts
            .where((a) =>
                (a.status == AlertStatus.pendiente ||
                    a.status == AlertStatus.atendida) &&
                !(a.latitude == 0 && a.longitude == 0))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final centro = activas.isNotEmpty
            ? LatLng(activas.first.latitude, activas.first.longitude)
            : _centroMunicipioPanel;
        final marcadores = activas.take(120).toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: centro,
                    initialZoom: 14,
                    backgroundColor: _bg,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'gt.edu.miumg.sire',
                      errorTileCallback: (tile, error, stackTrace) =>
                          debugPrint('SIRE panel mapa · tile no cargó: $error'),
                    ),
                    MarkerLayer(
                      markers: [
                        for (final a in marcadores)
                          Marker(
                            point: LatLng(a.latitude, a.longitude),
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message:
                                  '${a.userName ?? 'Ciudadano'} · ${a.categoria ?? 'Sin especificar'}'
                                  '\n${a.address ?? ''}',
                              child: Icon(
                                Icons.location_on,
                                size: 40,
                                color: a.status == AlertStatus.pendiente
                                    ? AppColors.statusPendiente
                                    : AppColors.statusAtendida,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (activas.isEmpty)
                  const Center(child: _TarjetaSinAlertasMapa()),
                const Positioned(left: 12, bottom: 12, child: _LeyendaMapa()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TarjetaSinAlertasMapa extends StatelessWidget {
  const _TarjetaSinAlertasMapa();

  @override
  Widget build(BuildContext context) => const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(width: 8),
              Text('No hay alertas activas en el mapa.'),
            ],
          ),
        ),
      );
}

class _LeyendaMapa extends StatelessWidget {
  const _LeyendaMapa();

  @override
  Widget build(BuildContext context) => const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeyendaItemMapa(
                  color: AppColors.statusPendiente, texto: 'Pendiente'),
              SizedBox(height: 4),
              _LeyendaItemMapa(
                  color: AppColors.statusAtendida, texto: 'En atención'),
            ],
          ),
        ),
      );
}

class _LeyendaItemMapa extends StatelessWidget {
  const _LeyendaItemMapa({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: color),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: _crit.$1),
          const SizedBox(height: 12),
          SizedBox(
              width: 360,
              child: Text(mensaje, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
