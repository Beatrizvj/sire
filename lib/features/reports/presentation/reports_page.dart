import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../alerts/domain/entities/alert_status.dart';
import '../../alerts/domain/entities/sos_alert.dart';
import '../../alerts/presentation/providers/alerts_providers.dart';
import '../../users/domain/entities/app_user.dart';
import '../../users/presentation/providers/users_providers.dart';

// Paleta del panel.
const _brand = Color(0xFFC62828);
const _dark = Color(0xFF2B1917);
const _line = Color(0xFFEADFDD);

// Colores para las series de las gráficas (accesibles y consistentes).
const _serie = <Color>[
  Color(0xFFC62828), // rojo
  Color(0xFFEF6C00), // naranja
  Color(0xFF2E7D32), // verde
  Color(0xFF1565C0), // azul
  Color(0xFF6A1B9A), // morado
  Color(0xFF8D6E63), // café
];

/// Módulo de Reportes con inteligencia de negocio (BI): indicadores, gráficas
/// y exportación a CSV, Excel y PDF.
class ReportesBody extends ConsumerWidget {
  const ReportesBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertasAsync = ref.watch(allAlertsProvider);
    final usuarios = ref.watch(allUsersProvider).asData?.value ?? const [];

    return alertasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error al cargar: $e')),
      data: (alertas) => _ReportesContenido(alertas: alertas, usuarios: usuarios),
    );
  }
}

class _ReportesContenido extends StatelessWidget {
  const _ReportesContenido({required this.alertas, required this.usuarios});

  final List<SosAlert> alertas;
  final List<AppUser> usuarios;

  // ── Agregaciones (BI) ──
  Map<String, int> get _porEstado {
    final m = {for (final s in AlertStatus.values) s.label: 0};
    for (final a in alertas) {
      m[a.status.label] = (m[a.status.label] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get _porCategoria {
    final m = <String, int>{};
    for (final a in alertas) {
      final k = (a.categoria == null || a.categoria!.isEmpty)
          ? 'Sin especificar'
          : a.categoria!;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get _porOrigen {
    final m = <String, int>{};
    for (final a in alertas) {
      m[a.source.label] = (m[a.source.label] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get _porComunidad {
    final aldeaDe = {for (final u in usuarios) u.id: u.aldea};
    final m = <String, int>{};
    for (final a in alertas) {
      final aldea = aldeaDe[a.userId];
      final k = (aldea == null || aldea.isEmpty) ? 'Sin aldea' : aldea;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  /// Alertas por día de los últimos 7 días.
  Map<String, int> get _porDia {
    final fmt = DateFormat('dd/MM');
    final hoy = DateTime.now();
    final dias = <String, int>{};
    for (var i = 6; i >= 0; i--) {
      final d = hoy.subtract(Duration(days: i));
      dias[fmt.format(d)] = 0;
    }
    for (final a in alertas) {
      final k = fmt.format(a.timestamp);
      if (dias.containsKey(k)) dias[k] = dias[k]! + 1;
    }
    return dias;
  }

  @override
  Widget build(BuildContext context) {
    final total = alertas.length;
    final pendientes =
        alertas.where((a) => a.status == AlertStatus.pendiente).length;
    final resueltas =
        alertas.where((a) => a.status == AlertStatus.resuelta).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de exportación.
          Row(
            children: [
              const Text('Reportes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              _BotonExport(
                  icono: Icons.grid_on,
                  texto: 'CSV',
                  onTap: () => _exportarCsv()),
              const SizedBox(width: 8),
              _BotonExport(
                  icono: Icons.table_chart,
                  texto: 'Excel',
                  onTap: () => _exportarExcel()),
              const SizedBox(width: 8),
              _BotonExport(
                  icono: Icons.picture_as_pdf,
                  texto: 'PDF',
                  onTap: () => _exportarPdf(),
                  primario: true),
            ],
          ),
          const SizedBox(height: 20),
          // KPIs.
          Row(
            children: [
              _Kpi(titulo: 'Alertas totales', valor: '$total', color: _dark),
              const SizedBox(width: 14),
              _Kpi(
                  titulo: 'Pendientes', valor: '$pendientes', color: _brand),
              const SizedBox(width: 14),
              _Kpi(
                  titulo: 'Resueltas',
                  valor: '$resueltas',
                  color: const Color(0xFF2E7D32)),
              const SizedBox(width: 14),
              _Kpi(
                  titulo: 'Usuarios',
                  valor: '${usuarios.length}',
                  color: const Color(0xFF1565C0)),
            ],
          ),
          const SizedBox(height: 20),
          // Gráficas.
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _PanelGrafica(
                titulo: 'Alertas por estado',
                child: _Pastel(datos: _porEstado),
              ),
              _PanelGrafica(
                titulo: 'Alertas por tipo de incidente',
                child: _Barras(datos: _porCategoria),
              ),
              _PanelGrafica(
                titulo: 'Alertas por comunidad',
                child: _Barras(datos: _porComunidad),
              ),
              _PanelGrafica(
                titulo: 'Alertas por origen',
                child: _Pastel(datos: _porOrigen),
              ),
              _PanelGrafica(
                titulo: 'Alertas por día (últimos 7 días)',
                ancho: 720,
                child: _Barras(datos: _porDia),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Datos tabulares para exportar ──
  static const _cols = [
    'Fecha',
    'Ciudadano',
    'Comunidad',
    'Origen',
    'Tipo de incidente',
    'Estado',
    'Latitud',
    'Longitud',
    'Dirección',
  ];

  List<List<String>> _filas() {
    final aldeaDe = {for (final u in usuarios) u.id: u.aldea};
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return [
      for (final a in alertas)
        [
          fmt.format(a.timestamp),
          a.userName ?? 'Ciudadano',
          (aldeaDe[a.userId] ?? '').isEmpty ? '—' : aldeaDe[a.userId]!,
          a.source.label,
          (a.categoria == null || a.categoria!.isEmpty)
              ? 'Sin especificar'
              : a.categoria!,
          a.status.label,
          a.latitude.toStringAsFixed(5),
          a.longitude.toStringAsFixed(5),
          a.address ?? '',
        ],
    ];
  }

  Future<void> _exportarCsv() async {
    // Se usa ';' como separador (el que Excel en español divide solo) junto con
    // la marca UTF-8 (BOM). Así se separan las columnas Y los acentos salen bien.
    // No se usa la línea "sep=" porque hace que Excel ignore la marca UTF-8.
    final buffer = StringBuffer();
    buffer.writeln(_cols.map(_csvCampo).join(';'));
    for (final fila in _filas()) {
      buffer.writeln(fila.map(_csvCampo).join(';'));
    }
    final bytes = Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())],
    );
    await FileSaver.instance.saveFile(
      name: 'reporte_sire_${_stamp()}',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static String _csvCampo(String v) {
    final escapado = v.replaceAll('"', '""');
    return '"$escapado"';
  }

  Future<void> _exportarExcel() async {
    final excel = Excel.createExcel();
    final hoja = excel['Alertas'];
    hoja.appendRow(_cols.map((c) => TextCellValue(c)).toList());
    for (final fila in _filas()) {
      hoja.appendRow(fila.map((c) => TextCellValue(c)).toList());
    }
    // Quita la hoja vacía por defecto y deja solo "Alertas".
    excel.setDefaultSheet('Alertas');
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.save();
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name: 'reporte_sire_${_stamp()}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _exportarPdf() async {
    final doc = pw.Document();
    final filas = _filas();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SIRE — Reporte de alertas',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'San Miguel Sigüilá · Generado ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Total de alertas: ${alertas.length}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: _cols,
            data: filas,
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2B1917)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF7ECEA)),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await FileSaver.instance.saveFile(
      name: 'reporte_sire_${_stamp()}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static String _stamp() =>
      DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
}

// ─────────────────────────── Widgets de UI ───────────────────────────

class _Kpi extends StatelessWidget {
  const _Kpi({required this.titulo, required this.valor, required this.color});

  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B5A57), letterSpacing: .5)),
            const SizedBox(height: 6),
            Text(valor,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PanelGrafica extends StatelessWidget {
  const _PanelGrafica(
      {required this.titulo, required this.child, this.ancho = 348});

  final String titulo;
  final Widget child;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }
}

class _Barras extends StatelessWidget {
  const _Barras({required this.datos});

  final Map<String, int> datos;

  @override
  Widget build(BuildContext context) {
    final entradas = datos.entries.toList();
    if (entradas.isEmpty || datos.values.every((v) => v == 0)) {
      return const Center(
          child: Text('Sin datos', style: TextStyle(color: Color(0xFF6B5A57))));
    }
    final maxV = datos.values.reduce((a, b) => a > b ? a : b).toDouble();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxV * 1.2).ceilToDouble().clamp(1, double.infinity),
        barGroups: [
          for (var i = 0; i < entradas.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: entradas[i].value.toDouble(),
                color: _serie[i % _serie.length],
                width: 22,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= entradas.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 64,
                    child: Text(entradas[i].key,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9)),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _Pastel extends StatelessWidget {
  const _Pastel({required this.datos});

  final Map<String, int> datos;

  @override
  Widget build(BuildContext context) {
    final entradas = datos.entries.where((e) => e.value > 0).toList();
    final total = entradas.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) {
      return const Center(
          child: Text('Sin datos', style: TextStyle(color: Color(0xFF6B5A57))));
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (var i = 0; i < entradas.length; i++)
                  PieChartSectionData(
                    value: entradas[i].value.toDouble(),
                    title:
                        '${(entradas[i].value / total * 100).round()}%',
                    color: _serie[i % _serie.length],
                    radius: 56,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entradas.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _serie[i % _serie.length],
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${entradas[i].key} (${entradas[i].value})',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonExport extends StatelessWidget {
  const _BotonExport({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.primario = false,
  });

  final IconData icono;
  final String texto;
  final Future<void> Function() onTap;
  final bool primario;

  @override
  Widget build(BuildContext context) {
    final hijo = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 18),
      const SizedBox(width: 6),
      Text(texto),
    ]);
    Future<void> accion() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await onTap();
        messenger.showSnackBar(
            SnackBar(content: Text('Reporte $texto generado.')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('No se pudo exportar: $e')));
      }
    }

    return primario
        ? FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _brand),
            onPressed: accion,
            child: hijo)
        : OutlinedButton(onPressed: accion, child: hijo);
  }
}
