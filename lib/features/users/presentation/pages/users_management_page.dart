import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../communities/aldeas_providers.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/users_providers.dart';
import '../../../../core/utils/whatsapp_link.dart';
import '../../domain/permisos.dart';

/// Gestión de usuarios: la Municipalidad asigna **rol** y **comunidad** a cada
/// usuario desde la app (sin editar Firestore a mano). Se apoya en las reglas:
/// la Municipalidad puede actualizar cualquier perfil.
class UsersManagementPage extends ConsumerWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final actor = ref.watch(currentUserProfileProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de usuarios')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(allUsersProvider),
            ),
            data: (todos) {
              // Mínimo privilegio: el COCODE solo ve/gestiona los de su aldea.
              final users = usuariosVisiblesPara(todos, actor);
              if (users.isEmpty) {
                return const Center(
                    child: Text('No hay usuarios registrados.'));
              }
              // Solo la Municipalidad y el coordinador de la aldea editan; los
              // demás integrantes consultan la lista (y pueden llamar).
              Widget tarjeta(int i) => _UserTile(
                    user: users[i],
                    remitente: remitenteSire(actor?.rol, actor?.aldea ?? ''),
                    onTap: (actor != null && actor.puedeEditar(users[i]))
                        ? () => showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              isScrollControlled: true,
                              builder: (_) => _EditSheet(user: users[i]),
                            )
                        : null,
                  );
              const padding = EdgeInsets.fromLTRB(12, 12, 12, 32);
              // Responsivo: 1 columna en teléfono; 2 en tablet o teléfono
              // horizontal; 3 en pantallas anchas.
              return LayoutBuilder(builder: (context, c) {
                final columnas = c.maxWidth >= 1100
                    ? 3
                    : c.maxWidth >= 650
                        ? 2
                        : 1;
                if (columnas == 1) {
                  return ListView.builder(
                    padding: padding,
                    itemCount: users.length,
                    itemBuilder: (_, i) => tarjeta(i),
                  );
                }
                // Alto fijo por tarjeta, escalado si el usuario agranda la letra.
                final alto = MediaQuery.textScalerOf(context).scale(122);
                return GridView.builder(
                  padding: padding,
                  itemCount: users.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    mainAxisExtent: alto,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) => tarjeta(i),
                );
              });
            },
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(
      {required this.user, required this.onTap, required this.remitente});

  final AppUser user;

  /// Autoridad que escribe por WhatsApp (ver [remitenteSire]).
  final String remitente;
  final VoidCallback? onTap;

  Future<void> _llamar(BuildContext context) async {
    final tel = user.telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (tel.isEmpty) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: tel));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el marcador para $tel.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final comunidad = user.aldea.isEmpty ? 'Sin comunidad' : user.aldea;
    final tel = user.telefono.trim();
    // Nombre como título (negrita) y datos secundarios más pequeños y
    // atenuados, cada uno en UNA línea con "…" si no cabe. Las acciones van a
    // la derecha en tamaño compacto para dejar el ancho al texto.
    final secundario = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nombre,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    _RolChip(rol: user.rol),
                    const SizedBox(height: 4),
                    if ((user.email ?? '').isNotEmpty)
                      Text(user.email!,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: secundario),
                    Text(
                      '${tel.isEmpty ? 'Sin teléfono' : tel} · $comunidad',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: secundario,
                    ),
                  ],
                ),
              ),
              if (tel.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Llamar',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.call, color: scheme.primary),
                  onPressed: () => _llamar(context),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  onPressed: () => abrirWhatsApp(user.telefono, user.nombre,
                      remitente: remitente),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});

  final UserRole rol;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (rol) {
      UserRole.ciudadano => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      UserRole.cocode || UserRole.auxiliatura => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      UserRole.municipalidad => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rol.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.user});

  final AppUser user;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late UserRole _rol = widget.user.rol;
  late String _comunidad = widget.user.aldea;
  late final Set<String> _contactos = widget.user.contactosConfianza.toSet();
  late bool _verIdentidad = widget.user.puedeVerIdentidad;
  late bool _responsable = widget.user.esResponsable;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = ref.watch(currentUserProfileProvider).asData?.value;
    // La Municipalidad cambia rol y comunidad y designa coordinadores; el
    // coordinador cambia el rol entre ciudadano y su cuerpo y delega la
    // aprobación (máx. [maxDelegados]).
    final esMuni = actor?.rol == UserRole.municipalidad;
    final roles = actor?.rolesEditables ?? const <UserRole>[];
    final comunidades = ref.watch(aldeasProvider).asData?.value ?? aldeasBase;
    // RF-11: candidatos = ciudadanos aprobados de la MISMA comunidad (vecinos),
    // sin incluir al propio usuario. Solo la autoridad arma estos grupos.
    final todos = ref.watch(allUsersProvider).asData?.value ?? const <AppUser>[];
    final delegados = delegadosEn(
        todos.where((u) => u.id != widget.user.id).toList(), _comunidad, _rol);
    final puedeDelegar = esMuni ||
        (actor != null &&
            actor.esCoordinador &&
            _rol == actor.rol &&
            (_verIdentidad || delegados < maxDelegados));
    final candidatos = _comunidad.isEmpty
        ? const <AppUser>[]
        : todos
            .where((u) =>
                u.id != widget.user.id &&
                u.rol == UserRole.ciudadano &&
                u.puedeAcceder &&
                u.aldea == _comunidad)
            .toList();

    return SafeArea(
      child: SingleChildScrollView(
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
              Text(widget.user.nombre, style: theme.textTheme.titleLarge),
              if ((widget.user.email ?? '').isNotEmpty)
                Text(
                  widget.user.email!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              if (roles.isNotEmpty) ...[
                const SizedBox(height: 20),
                _Label(text: 'Rol'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in roles)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _rol == r,
                        onSelected: (_) => setState(() => _rol = r),
                      ),
                  ],
                ),
              ],
              if (esMuni) ...[
                const SizedBox(height: 20),
                _Label(text: 'Comunidad'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Sin asignar'),
                      selected: _comunidad.isEmpty,
                      onSelected: (_) => setState(() => _comunidad = ''),
                    ),
                    for (final c in comunidades)
                      ChoiceChip(
                        label: Text(c),
                        selected: _comunidad == c,
                        onSelected: (_) => setState(() => _comunidad = c),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  '${widget.user.rol.label} · ${widget.user.aldea.isEmpty ? 'Sin aldea' : widget.user.aldea}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (esMuni && _rol.esAutoridadDeAldea)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _responsable,
                  onChanged: (v) => setState(() => _responsable = v),
                  title: Text(
                      'Coordinador ${_rol == UserRole.cocode ? 'del COCODE' : 'de la Alcaldía Auxiliar'}'),
                  subtitle: const Text(
                      'Aprueba cuentas de su aldea, gestiona a sus integrantes '
                      'y delega la aprobación.'),
                ),
              if (_rol != UserRole.ciudadano &&
                  !(_rol.esAutoridadDeAldea && _responsable))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _verIdentidad,
                  onChanged: puedeDelegar
                      ? (v) => setState(() => _verIdentidad = v)
                      : null,
                  title: const Text('Puede aprobar cuentas (ver DPI)'),
                  subtitle: Text(esMuni
                      ? 'Revisa el DPI y aprueba las solicitudes de su aldea.'
                      : 'Delegados en tu aldea: $delegados de $maxDelegados.'),
                ),
              if (_rol == UserRole.ciudadano) ...[
                const SizedBox(height: 20),
                _Label(text: 'Contactos de confianza'),
                const SizedBox(height: 4),
                Text(
                  'Grupo de confianza de ${widget.user.nombre}: a todos les suena '
                  'la alarma cuando cualquiera del grupo envía un SOS (es mutuo).',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (_comunidad.isEmpty)
                  Text(
                    'Asigna primero una comunidad para ver a los vecinos.',
                    style: theme.textTheme.bodySmall,
                  )
                else if (candidatos.isEmpty)
                  Text(
                    'No hay otros ciudadanos aprobados en esta comunidad.',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in candidatos)
                        FilterChip(
                          label: Text(c.nombre),
                          selected: _contactos.contains(c.id),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              _contactos.add(c.id);
                            } else {
                              _contactos.remove(c.id);
                            }
                          }),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _guardar,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(userRepositoryProvider);
    final yo = widget.user.id;
    final nuevos = _rol == UserRole.ciudadano ? _contactos : <String>{};
    final viejos = widget.user.contactosConfianza.toSet();
    try {
      await repo.saveUser(
        widget.user.copyWith(
          rol: _rol,
          aldea: _comunidad,
          puedeVerIdentidad: _rol != UserRole.ciudadano &&
              !(_rol.esAutoridadDeAldea && _responsable) &&
              _verIdentidad,
          esResponsable: _rol.esAutoridadDeAldea && _responsable,
          contactosConfianza: nuevos.toList(),
        ),
      );
      // Grupo MUTUO (RF-11): a cada vecino AÑADIDO, agrégame en su lista; a cada
      // QUITADO, quítame. Así el grupo queda recíproco armándolo de un solo lado.
      for (final otroId in nuevos.difference(viejos)) {
        final otro = await repo.getUser(otroId);
        if (otro != null && !otro.contactosConfianza.contains(yo)) {
          await repo.saveUser(otro.copyWith(
            contactosConfianza: [...otro.contactosConfianza, yo],
          ));
        }
      }
      for (final otroId in viejos.difference(nuevos)) {
        final otro = await repo.getUser(otroId);
        if (otro != null && otro.contactosConfianza.contains(yo)) {
          await repo.saveUser(otro.copyWith(
            contactosConfianza:
                otro.contactosConfianza.where((c) => c != yo).toList(),
          ));
        }
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${widget.user.nombre} → ${_rol.label}.')),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            Text(
              'No se pudieron cargar los usuarios',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
