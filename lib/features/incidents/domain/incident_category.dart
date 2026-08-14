import 'package:equatable/equatable.dart';

/// Categoría de incidente configurable (R3). Vive en `categorias_incidente`.
class IncidentCategory extends Equatable {
  const IncidentCategory({
    required this.id,
    required this.nombre,
    this.orden = 0,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final int orden;
  final bool activo;

  @override
  List<Object?> get props => [id, nombre, orden, activo];
}

/// Categorías por defecto de la tesis (las únicas 3 acordadas). Se usan para
/// sembrar la colección la primera vez y como respaldo si aún no hay datos.
const List<String> categoriasPorDefecto = [
  'Robo',
  'Asalto',
  'Persona sospechosa',
];

/// Etiqueta para una alerta sin categoría asignada.
const String categoriaSinEspecificar = 'Sin especificar';
