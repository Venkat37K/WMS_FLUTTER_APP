import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Mbr3StatusScreen extends StatefulWidget {
  const Mbr3StatusScreen({super.key});

  @override
  State<Mbr3StatusScreen> createState() => _Mbr3StatusScreenState();
}

class _Mbr3StatusScreenState extends State<Mbr3StatusScreen> {
  // Same endpoint
  static const String apiUrl = 'http://192.168.123.154:5000/api/mbr-analog/latest';

  // ---- SAME display settings as MBR1/MBR2 ----
  static const double levelLow = 20.0; // %
  static const double levelHigh = 80.0; // %
  static const String levelUnit = 'M';

  static const String pressureUnit = 'mH2O';
  static const double pressureLow = 2.0;
  static const double pressureHigh = 8.0;
  static const double pressureMax = 10.0;

  static const String flowUnit = 'm³/h';
  static const String totalUnit = 'm³';
  static const double maxFlow = 500.0;
  static const double maxTotal = 10000.0;
  static const double noFlowThreshold = 0.1;

  static const String chlorineUnit = 'mg/L';
  static const String conductivityUnit = 'µS/m';

  late Future<_MbrFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_MbrFetchResult> _fetch() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final root = json.decode(res.body) as Map<String, dynamic>;
    final data = (root['data'] ?? {}) as Map<String, dynamic>;

    // Pick the MBR_03 block (tolerant to spacing/variants)
    final mbr03 = (data['MBR_03'] ??
        data['MBR 03'] ??
        data['MBR3'] ??
        {}) as Map<String, dynamic>;
    final sensors = (mbr03['sensors'] ?? {}) as Map<String, dynamic>;

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // ---- Mapping for MBR_03 ----
    final lt = _toDouble(sensors['ULT 3']);
    final pt = _toDouble(sensors['PT 3']);
    final ft = _toDouble(sensors['FT 3']);
    final ftTotal = _toDouble(sensors['FT_TT']);
    final oclr = _toDouble(sensors['OCLR']);
    final ocnd = _toDouble(sensors['OCND']);

    // Timestamp
    final date = (mbr03['date'] as String?)?.trim();
    final time = (mbr03['time'] as String?)?.trim();
    String? iso;
    if (date != null && time != null && date.isNotEmpty && time.isNotEmpty) {
      iso = '${date}T$time';
    }

    return _MbrFetchResult(
      lt1: lt,
      pt1: pt,
      ft1: ft,
      ftTotal: ftTotal,
      chlorine: oclr,
      conductivity: ocnd,
      serverIso: iso,
    );
  }

  Future<void> _refresh() async {
    final r = await _fetch();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _Status _levelStatus(double? v) {
    if (v == null) return _Status('UNKNOWN', Colors.grey);
    if (v < levelLow) return _Status('LOW', const Color(0xFFE67E22));
    if (v > levelHigh) return _Status('HIGH', const Color(0xFFE74C3C));
    return _Status('NORMAL', const Color(0xFF2ECC71));
  }

  _Status _pressureStatus(double? v) {
    if (v == null) return _Status('UNKNOWN', Colors.grey);
    if (v < pressureLow) return _Status('LOW', const Color(0xFFE67E22));
    if (v > pressureHigh) return _Status('HIGH', const Color(0xFFE74C3C));
    return _Status('NORMAL', const Color(0xFF2ECC71));
  }

  _Status _flowStatus(double? v) {
    if (v == null) return _Status('UNKNOWN', Colors.grey);
    if (v <= noFlowThreshold) return _Status('NO FLOW', const Color(0xFFE67E22));
    return _Status('FLOWING', const Color(0xFF2ECC71));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        // Keep same pattern; update label for MBR 3
        title: const Text('MBR • MBR 3 - Press Enclave', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: const Color(0xFFB21212),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: FutureBuilder<_MbrFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _ErrorView(
                    message: 'Failed to load MBR 3 data',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetch()),
                  );
                }

                final r = snap.data!;
                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // ----- Level -----
                      const Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _LegendDot(label: 'LOW', color: Color(0xFFE67E22)),
                          _LegendDot(label: 'NORMAL', color: Color(0xFF2ECC71)),
                          _LegendDot(label: 'HIGH', color: Color(0xFFE74C3C)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (r.serverIso != null)
                        Text('Last update: ${_formatIsoLocal(r.serverIso!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      _LevelTile(
                        title: 'Level Transmitter',
                        value: r.lt1,
                        unit: levelUnit,
                        status: _levelStatus(r.lt1),
                      ),

                      // ----- Pressure -----
                      const SizedBox(height: 16),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _LegendDot(label: 'LOW', color: Color(0xFFE67E22)),
                          _LegendDot(label: 'NORMAL', color: Color(0xFF2ECC71)),
                          _LegendDot(label: 'HIGH', color: Color(0xFFE74C3C)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (r.serverIso != null)
                        Text('Last update: ${_formatIsoLocal(r.serverIso!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      _PTTile(
                        title: 'Pressure Transmitter',
                        value: r.pt1,
                        unit: pressureUnit,
                        status: _pressureStatus(r.pt1),
                        maxValue: pressureMax,
                      ),

                      // ----- Flow (rate) -----
                      const SizedBox(height: 16),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _LegendDot(label: 'NO FLOW', color: Color(0xFFE67E22)),
                          _LegendDot(label: 'FLOWING', color: Color(0xFF2ECC71)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (r.serverIso != null)
                        Text('Last update: ${_formatIsoLocal(r.serverIso!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      _ValueTile(
                        title: 'Flow Transmitter',
                        value: r.ft1,
                        unit: flowUnit,
                        maxValue: maxFlow,
                        status: _flowStatus(r.ft1),
                      ),

                      // ----- Totalizer -----
                      const SizedBox(height: 16),
                      const _LegendDot(label: 'TOTALIZER (Cumulative)', color: Colors.white),
                      const SizedBox(height: 8),
                      if (r.serverIso != null)
                        Text('Last update: ${_formatIsoLocal(r.serverIso!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      _ValueTile(
                        title: 'Flow Totalizer',
                        value: r.ftTotal,
                        unit: totalUnit,
                        maxValue: maxTotal,
                        status: null,
                      ),

                      // ----- Analyzer -----
                      const SizedBox(height: 16),
                      const Text(
                        'Analyzer Parameters',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (r.serverIso != null)
                        Text('Last update: ${_formatIsoLocal(r.serverIso!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 12),
                      _HeadingRow(title: 'Chlorine Sensor', value: _fmt(r.chlorine, chlorineUnit)),
                      const SizedBox(height: 10),
                      _HeadingRow(title: 'Conductivity Electrode', value: _fmt(r.conductivity, conductivityUnit)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double? v, String unit) {
    if (v == null) return '—';
    final d = double.tryParse(v.toString());
    if (d == null) return '—';
    return '${d.toStringAsFixed(d == d.roundToDouble() ? 0 : 2)} $unit';
  }

  static String _formatIsoLocal(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }
}

// ===== model & shared widgets (same as other MBR screens) =====
class _MbrFetchResult {
  final double? lt1;
  final double? pt1;
  final double? ft1;
  final double? ftTotal;
  final double? chlorine;
  final double? conductivity;
  final String? serverIso;
  _MbrFetchResult({
    required this.lt1,
    required this.pt1,
    required this.ft1,
    required this.ftTotal,
    required this.chlorine,
    required this.conductivity,
    required this.serverIso,
  });
}

class _Status {
  final String text;
  final Color color;
  const _Status(this.text, this.color);
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final _Status status;

  const _LevelTile({required this.title, required this.value, required this.unit, required this.status});

  @override
  Widget build(BuildContext context) {
    final progress = ((value ?? 0).clamp(0, 100)) / 100.0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: status.color),
                ),
                child: Text(status.text,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: status.color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value == null ? '—' : '${value!.toStringAsFixed(1)} $unit',
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress,
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PTTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final _Status status;
  final double maxValue;

  const _PTTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value == null || maxValue <= 0 ? 0.0 : (value!.clamp(0, maxValue) / maxValue);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: status.color),
                ),
                child: Text(status.text,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: status.color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress,
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(status.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final double maxValue;
  final _Status? status;

  const _ValueTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.maxValue,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value == null || maxValue <= 0 ? 0.0 : (value!.clamp(0, maxValue) / maxValue);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status!.color.withOpacity(.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: status!.color),
                  ),
                  child: Text(status!.text,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: status!.color)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress,
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(status?.color ?? Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  final String title;
  final String value;
  const _HeadingRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Text(value, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, this.details, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.cloud_off, color: Colors.white, size: 36),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
        if (details != null) ...[
          const SizedBox(height: 4),
          Text(details!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFFB21212)),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
