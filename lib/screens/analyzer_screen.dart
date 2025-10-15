import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  static const String apiUrl = 'http://13.126.21.76:5000/api/rwph/tabs';

  late Future<_AnalyzerFetchResult> _future;

  // Mapping: label → TAB2 key
  static const List<_ParamDef> _params = [
    _ParamDef(label: 'PH',                                key: 'A30', unit: 'pH'),
    _ParamDef(label: 'Conductivity',                      key: 'A31', unit: 'µS/m'),
    _ParamDef(label: 'Oxidation Reduction Potential',     key: 'A32', unit: 'mV'),
    _ParamDef(label: 'Free chlorine',                     key: 'A33', unit: 'mg/L'),
    _ParamDef(label: 'Total chlorine',                    key: 'A34', unit: 'mg/L'),
  ];

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

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // Handle either "TAB2" or "TAB 2" (defensive)
    Map<String, dynamic> tab2 = {};
    final maybeTab2 = tabs['TAB2'] ?? tabs['TAB 2'];
    if (maybeTab2 is Map<String, dynamic>) tab2 = maybeTab2;

    final readings = <_Reading>[];
    for (final p in _params) {
      final raw = tab2[p.key];
      final v = _formatValue(raw);
      final vWithUnit = (v == '--' || p.unit.isEmpty) ? v : '$v ${p.unit}';
      readings.add(_Reading(label: p.label, value: vWithUnit));
    }

    final String? at = data['at'] as String?;
    return _AnalyzerFetchResult(readings: readings, serverTimeIso: at);
  }

  static String _formatValue(dynamic raw) {
    if (raw == null) return '--';
    if (raw is num) {
      // Keep integers as-is; doubles with up to 2 decimals
      if (raw is int) return raw.toString();
      return raw.toStringAsFixed(2);
    }
    // Try to parse numeric strings
    if (raw is String) {
      final d = double.tryParse(raw.trim());
      if (d != null) {
        // If it’s effectively an int (e.g., "5.0"), show without decimals
        if (d == d.roundToDouble()) return d.toStringAsFixed(0);
        return d.toStringAsFixed(2);
      }
      return raw; // non-numeric string
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
        title: const Text('RWPS • Analyzer', style: TextStyle(color: Colors.white)),
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
      return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _ParamDef {
  final String label;
  final String key;
  final String unit;
  const _ParamDef({required this.label, required this.key, required this.unit});
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
