import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MstAnalyzerScreen extends StatefulWidget {
  const MstAnalyzerScreen({super.key});

  @override
  State<MstAnalyzerScreen> createState() => _MstAnalyzerScreenState();
}

class _MstAnalyzerScreenState extends State<MstAnalyzerScreen> {
  // MST analog endpoint
  static const String apiUrl = 'http://13.126.21.76:5000/api/mst-analog/latest';

  // Show exactly these four, with labels matching the API (image) and units.
  static const List<_ParamDef> _params = [
    _ParamDef(
      label: 'PH',
      keys: ['PH', 'pH'],
      unit: 'pH',
    ),
    _ParamDef(
      label: 'Conductivity sensor',
      keys: ['Conductivity sensor', 'Conductivity'],
      unit: 'µS/m',
    ),
    _ParamDef(
      label: 'Oxidation Reduction Potential',
      keys: ['Oxidation reduction potential', 'Oxidation Reduction Potential', 'ORP'],
      unit: 'mV',
    ),
    _ParamDef(
      label: 'Chlorine sensor',
      keys: ['Chlorine sensor', 'Free chlorine', 'Total chlorine', 'Chlorine'],
      unit: 'mg/L',
    ),
  ];

  late Future<_AnalyzerFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAnalyzer();
  }

  Future<_AnalyzerFetchResult> _fetchAnalyzer() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final root = json.decode(res.body) as Map<String, dynamic>;
    final data = (root['data'] ?? {}) as Map<String, dynamic>;

    // Prefer MST_01; otherwise first site block
    Map<String, dynamic> site = {};
    if (data['MST_01'] is Map<String, dynamic>) {
      site = data['MST_01'];
    } else if (data.isNotEmpty) {
      final first = data.values.first;
      if (first is Map<String, dynamic>) site = first;
    }

    final sensors = (site['sensors'] ?? {}) as Map<String, dynamic>;
    final dateStr = site['date'] as String?;
    final timeStr = site['time'] as String?;
    final serverAt = (dateStr != null && timeStr != null) ? '${dateStr}T$timeStr' : null;

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    dynamic _lookup(List<String> keys) {
      for (final k in keys) {
        if (sensors.containsKey(k)) return sensors[k];
      }
      // be case-insensitive as a fallback
      final lower = {
        for (final e in sensors.entries) e.key.toString().toLowerCase(): e.value
      };
      for (final k in keys) {
        final v = lower[k.toLowerCase()];
        if (v != null) return v;
      }
      return null;
    }

    final readings = <_Reading>[];
    for (final p in _params) {
      final raw = _lookup(p.keys);
      final v = _formatValue(raw);
      final withUnit = (v == '--' || p.unit.isEmpty) ? v : '$v ${p.unit}';
      readings.add(_Reading(label: p.label, value: withUnit));
    }

    return _AnalyzerFetchResult(readings: readings, serverTimeIso: serverAt);
  }

  static String _formatValue(dynamic raw) {
    if (raw == null) return '--';
    if (raw is num) {
      if (raw is int) return raw.toString();
      final d = raw.toDouble();
      return (d == d.roundToDouble()) ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
    }
    if (raw is String) {
      final d = double.tryParse(raw.trim());
      if (d != null) {
        return (d == d.roundToDouble()) ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
      }
      return raw;
    }
    return raw.toString();
  }

  Future<void> _refresh() async {
    final r = await _fetchAnalyzer();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('MST • Analyzer', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: const Color(0xFFB21212),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FutureBuilder<_AnalyzerFetchResult>(
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
                    message: 'Failed to load',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchAnalyzer()),
                  );
                }

                final result = snap.data!;
                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analyzer Parameters',
                        style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: result.readings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final r = result.readings[i];
                            return _HeadingRow(title: r.label, value: r.value);
                          },
                        ),
                      ),
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

// ===== Models =====

class _ParamDef {
  final String label;
  final List<String> keys; // tolerate small naming variations
  final String unit;
  const _ParamDef({required this.label, required this.keys, required this.unit});
}

class _Reading {
  final String label;
  final String value;
  const _Reading({required this.label, required this.value});
}

class _AnalyzerFetchResult {
  final List<_Reading> readings;
  final String? serverTimeIso;
  const _AnalyzerFetchResult({required this.readings, required this.serverTimeIso});
}

// ===== Widgets (same UI as CWPS) =====

class _HeadingRow extends StatelessWidget {
  final String title;
  final String value;
  const _HeadingRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
          ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFB21212),
          ),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
