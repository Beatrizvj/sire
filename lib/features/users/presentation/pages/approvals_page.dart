import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../communities/aldeas_providers.dart';
import '../../../identity/data/identity_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/approvals_providers.dart';
import '../providers/users_providers.dart';

/// Aprobación de cuentas (R1) desde la app móvil.
/// - Municipalidad: todas las solicitudes pendientes del municipio.
/// - COCODE: solo las de su aldea.
///
/// Reusa [pendientesPara] y [approvalsServiceProvider] (los mismos del panel
/// web), de modo que un COCODE pueda aprobar desde el teléfono sin necesitar
/// computadora — cumple la función "aprobar cuentas de su localidad" de la
/// Tabla 9 del PG2 también en el móvil.
class ApprovalsPage extends ConsumerWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final autoridad = ref.watch(currentUserProfileProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Aprobaciones')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorAprob(
              mensaje: '$e',
              onReintentar: () => ref.invalidate(allUsersProvider),
            ),
            data: (users) {
              if (autoridad == null) {
                return const Center(child: Text('Perfil no disponible.'));
              }
              final pendientes = pendientesPara(users, autoridad);
              if (pendientes.isEmpty) return const _SinPendientes();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                itemCount: pendientes.length,
                itemBuilder: (_, i) => _SolicitudTile(
                  solicitante: pendientes[i],
                  autoridad: autoridad,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitante, required this.autoridad});

  final AppUser solicitante;
  final AppUser autoridad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aldea = solicitante.aldeaSolicitada.isEmpty
        ? 'Sin aldea declarada'
        : solicitante.aldeaSolicitada;
    void abrirRevision() => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _RevisarSheet(
            solicitante: solicitante,
            autoridad: autoridad,
          ),
        );

    // Se usa ListTile (patrón probado en el resto de la app) con un chevron
    // pequeño como trailing: así el nombre/teléfono/aldea reciben todo el ancho
    // y ya no salen en vertical. Toda la tarjeta abre la revisión.
    return Card(
      child: ListTile(
        onTap: abrirRevision,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            solicitante.nombre.isNotEmpty
                ? solicitante.nombre[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          solicitante.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${solicitante.telefono}\nAldea solicitada: $aldea'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _RevisarSheet extends ConsumerStatefulWidget {
  const _RevisarSheet({required this.solicitante, required this.autoridad});

  final AppUser solicitante;
  final AppUser autoridad;

  @override
  ConsumerState<_RevisarSheet> createState() => _RevisarSheetState();
}

class _RevisarSheetState extends ConsumerState<_RevisarSheet> {
  UserRole _rol = UserRole.ciudadano;
  late String _aldea = widget.solicitante.aldeaSolicitada;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comunidades = ref.watch(aldeasProvider).asData?.value ?? aldeasBase;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.solicitante.nombre, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tel: ${widget.solicitante.telefono}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            const _Label('Identidad (DPI)'),
            const SizedBox(height: 8),
            if (widget.autoridad.puedeVerIdentidad)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DpiThumb(
                      uid: widget.solicitante.id,
                      lado: IdentityRepository.anverso,
                      etiqueta: 'Anverso',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DpiThumb(
                      uid: widget.solicitante.id,
                      lado: IdentityRepository.reverso,
                      etiqueta: 'Reverso',
                    ),
                  ),
                ],
              )
            else
              Text(
                'Para ver las fotos del DPI necesitas permiso de verificador. '
                'La Municipalidad lo activa en la consola web '
                '(Usuarios → "Puede ver fotos del DPI").',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 20),
            const _Label('Rol a asignar'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            const _Label('Aldea / Comunidad'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in comunidades)
                  ChoiceChip(
                    label: Text(c),
                    selected: _aldea == c,
                    onSelected: (_) => setState(() => _aldea = c),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_saving || _aldea.isEmpty) ? null : _aprobar,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_saving ? 'Guardando…' : 'Aprobar'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _rechazar,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Rechazar solicitud'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aprobar() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(approvalsServiceProvider).aprobar(
            widget.solicitante,
            rol: _rol,
            aldea: _aldea,
            actor: widget.autoridad,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              '${widget.solicitante.nombre} aprobado como ${_rol.label}.'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo aprobar: $e')),
      );
    }
  }

  Future<void> _rechazar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Rechazar esta solicitud?'),
        content: Text(
          'La cuenta de ${widget.solicitante.nombre} quedará rechazada y no '
          'podrá acceder a SIRE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sí, rechazar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(approvalsServiceProvider).rechazar(
            widget.solicitante,
            actor: widget.autoridad,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.solicitante.nombre} rechazado.')),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo rechazar: $e')),
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Miniatura de una foto del DPI (anverso/reverso) que se carga bajo demanda.
/// Solo se muestra a autoridades con permiso de verificador; al tocarla, se ve
/// en grande. Las fotos viven en `identidad/{uid}/fotos/{lado}` (privadas).
class _DpiThumb extends ConsumerStatefulWidget {
  const _DpiThumb({
    required this.uid,
    required this.lado,
    required this.etiqueta,
  });

  final String uid;
  final String lado;
  final String etiqueta;

  @override
  ConsumerState<_DpiThumb> createState() => _DpiThumbState();
}

class _DpiThumbState extends ConsumerState<_DpiThumb> {
  Uint8List? _bytes;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final b = await ref
          .read(identityRepositoryProvider)
          .descargar(uid: widget.uid, lado: widget.lado);
      if (mounted) {
        setState(() {
          _bytes = b;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _verGrande() {
    final bytes = _bytes;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (dctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.memory(bytes)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(dctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1.58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: _contenido(scheme),
          ),
        ),
      ],
    );
  }

  Widget _contenido(ColorScheme scheme) {
    if (_cargando) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return Center(
        child: Text('Sin foto',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      );
    }
    return GestureDetector(
      onTap: _verGrande,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }
}

class _SinPendientes extends StatelessWidget {
  const _SinPendientes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_reg_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No hay solicitudes pendientes',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cuando alguien se registre en tu localidad, aparecerá aquí para '
              'aprobar o rechazar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorAprob extends StatelessWidget {
  const _ErrorAprob({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('No se pudieron cargar las solicitudes',
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
