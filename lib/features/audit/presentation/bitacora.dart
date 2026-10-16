import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../users/domain/entities/app_user.dart';
import '../../users/domain/entities/user_role.dart';
import '../../users/domain/permisos.dart';
import '../data/audit_repository.dart';
import '../domain/audit_entry.dart';

/// Aldea con la que consulta [u] la bitácora: vacía para la Municipalidad
/// (todo el municipio); la suya para las autoridades de aldea.
String _aldeaConsulta(AppUser? u) =>
    u?.rol == UserRole.municipalidad ? '' : (u?.aldea ?? '');

/// Puede abrir la bitácora completa: Municipalidad o coordinador de aldea.
bool puedeVerBitacora(AppUser? u) =>
    u != null && (u.rol == UserRole.municipalidad || u.esCoordinador);

/// Bitácora visible para el usuario actual.
final bitacoraProvider = StreamProvider.autoDispose<List<AuditEntry>>((ref) {
  final yo = ref.watch(currentUserProfileProvider).asData?.value;
  if (!puedeVerBitacora(yo)) return Stream.value(const []);
  return ref
      .watch(auditRepositoryProvider)
      .watchBitacora(aldea: _aldeaConsulta(yo));
});

/// Historial de acciones de una alerta.
final historialAlertaProvider = StreamProvider.autoDispose
    .family<List<AuditEntry>, String>((ref, alertaId) {
  final yo = ref.watch(currentUserProfileProvider).asData?.value;
  if (yo == null || !yo.rol.esAutoridad) return Stream.value(const []);
  return ref
      .watch(auditRepositoryProvider)
      .watchHistorialAlerta(alertaId, aldea: _aldeaConsulta(yo));
});

/// "Ezequías López · Alcaldía Auxiliar (coordinador)".
String quienLoHizo(AuditEntry e) {
  final nombre = e.actorNombre.isEmpty ? 'Desconocido' : e.actorNombre;
  if (e.actorRol.isEmpty) return nombre;
  final rol = UserRole.fromValue(e.actorRol).label;
  return '$nombre · $rol${e.actorCoordinador ? ' (coordinador)' : ''}';
}

String _valor(Object? v) => switch (v) {
      null => '—',
      List() when v.isEmpty => 'ninguno',
      List() => v.join(', '),
      true => 'sí',
      false => 'no',
      String() when v.isEmpty => '—',
      _ => '$v'.replaceAll('_', ' '),
    };

/// Cambios "campo: antes → después" de un registro.
List<String> cambiosDe(AuditEntry e) {
  final antes = e.valorAnterior ?? const {};
  final despues = e.valorNuevo ?? const {};
  return [
    for (final k in {...antes.keys, ...despues.keys})
      '$k: ${_valor(antes[k])} → ${_valor(despues[k])}',
  ];
}

enum _Filtro { todo, alertas, usuarios }

/// Lista de la bitácora con filtro por tipo y búsqueda por nombre. Sirve en
/// la app móvil ([BitacoraPage]) y en el panel web.
class BitacoraLista extends ConsumerStatefulWidget {
  const BitacoraLista({super.key});

  @override
  ConsumerState<BitacoraLista> createState() => _BitacoraListaState();
}

class _BitacoraListaState extends ConsumerState<BitacoraLista> {
  _Filtro _filtro = _Filtro.todo;
  String _buscar = '';

  bool _pasa(AuditEntry e) {
    if (_filtro == _Filtro.alertas && e.objetivoTipo != 'alerta') return false;
    if (_filtro == _Filtro.usuarios && e.objetivoTipo == 'alerta') return false;
    final q = _buscar.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.actorNombre.toLowerCase().contains(q) ||
        e.objetivoNombre.toLowerCase().contains(q) ||
        descripcionAccion(e.accion).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bitacoraProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por persona o acción',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _buscar = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<_Filtro>(
            segments: const [
              ButtonSegment(value: _Filtro.todo, label: Text('Todo')),
              ButtonSegment(value: _Filtro.alertas, label: Text('Alertas')),
              ButtonSegment(value: _Filtro.usuarios, label: Text('Cuentas')),
            ],
            selected: {_filtro},
            onSelectionChanged: (s) => setState(() => _filtro = s.first),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar la bitácora: $e'),
              ),
            ),
            data: (todos) {
              final lista = todos.where(_pasa).toList();
              if (lista.isEmpty) {
                return const Center(
                    child: Text('Aún no hay acciones registradas.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _RegistroTile(entry: lista[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RegistroTile extends StatelessWidget {
  const _RegistroTile({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenue = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final fecha = entry.fechaHora == null
        ? 'ahora'
        : DateFormat('dd/MM/yyyy HH:mm').format(entry.fechaHora!);
    final esAlerta = entry.objetivoTipo == 'alerta';
    final sobre = esAlerta
        ? 'Alerta de ${entry.objetivoNombre.isEmpty ? 'ciudadano' : entry.objetivoNombre}'
        : entry.objetivoNombre;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(esAlerta ? Icons.notifications_outlined : Icons.person_outline),
      title: Text('${descripcionAccion(entry.accion)}'
          '${sobre.isEmpty ? '' : ' — $sobre'}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Por: ${quienLoHizo(entry)}'),
          for (final c in cambiosDe(entry)) Text(c, style: tenue),
          if (entry.detalle != null && entry.detalle!.isNotEmpty)
            Text('Motivo: ${entry.detalle}', style: tenue),
          Text(
              '$fecha${entry.aldea.isEmpty ? '' : ' · ${entry.aldea}'}',
              style: tenue),
        ],
      ),
    );
  }
}

/// Pantalla de la bitácora (app móvil).
class BitacoraPage extends StatelessWidget {
  const BitacoraPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bitácora de acciones')),
        body: const BitacoraLista(),
      );
}

/// Historial de una alerta, en orden cronológico ("Atendió… → Resolvió…").
class HistorialAlerta extends ConsumerWidget {
  const HistorialAlerta({super.key, required this.alertaId});

  final String alertaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final registros =
        ref.watch(historialAlertaProvider(alertaId)).asData?.value ?? const [];
    final tenue = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (registros.isEmpty)
          Text('Sin acciones registradas todavía.', style: tenue)
        else
          for (final e in registros.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.history, size: 16),
                  ),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${descripcionAccion(e.accion)} · '),
                      TextSpan(
                          text: quienLoHizo(e),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(
                        text: e.fechaHora == null
                            ? ''
                            : ' · ${DateFormat('dd/MM HH:mm').format(e.fechaHora!)}',
                        style: tenue,
                      ),
                    ])),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
