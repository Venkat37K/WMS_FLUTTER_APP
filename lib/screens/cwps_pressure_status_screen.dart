import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CwpsPressureStatusScreen extends StatefulWidget {
  const CwpsPressureStatusScreen({super.key});

  @override
  State<CwpsPressureStatusScreen> createState() => _CwpsPressureStatusScreenState();
}

class _CwpsPressureStatusScreenState extends State<CwpsPressureStatusScreen> {
  // Same CWPH API base you used earlier:
  static const String apiUrl = 'http://192.168.123.154:5000/api/cwph/tabs';

  // Mapping: TAB2.A2..A8 => PT-1..PT-7
  static const String tabName = 'TAB2';
  static const int firstKeyIndex = 2;    // A2 is PT-1
  static const int transmitterCount = 7; // PT-1..PT-7 (A2..A8)

  // Display settings (tweak to your plant)
  static const String unit = 'mH20';
  static const double maxBar = 10.0;         // for progress scaling
  static const double lowThreshold = 2.0;    // < 2.0 -> LOW
  static const double highThreshold = 8.0;   // > 8.0 -> HIGH

  String _ptTitle(int idx) => idx == 7 ? 'PT 7 (Common)' : 'PT $idx (Pump $idx)';

  late Future<_CwpsPressureFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPressures();
  }

  Future<_CwpsPressureFetchResult> _fetchPressures() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // Handle 'TAB2' or 'TAB 2'
    final t2Any = tabs[tabName] ?? tabs['TAB 2'];
    final t2 = (t2Any is Map<String, dynamic>) ? t2Any : <String, dynamic>{};

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final List<_CwpsPTReading> pts = [];
    for (int i = 0; i < transmitterCount; i++) {
      final keyIndex = firstKeyIndex + i; // 2..8
      final key = 'A$keyIndex';           // 'A2'..'A8'
      final labelIndex = i + 1;           // PT-1..PT-7
      final value = _toDouble(t2[key]);
      pts.add(_CwpsPTReading(index: labelIndex, key: key, value: value));
    }

    return _CwpsPressureFetchResult(
      pts: pts,
      serverTimeIso: data['at'] as String?,
    );
  }

  Future<void> _refresh() async {
    final r = await _fetchPressures();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _CwpsStatus _classify(double? v) {
    if (v == null) return _CwpsStatus('UNKNOWN', Colors.grey);
    if (v < lowThreshold) return _CwpsStatus('LOW', const Color(0xFFE67E22));
    if (v > highThreshold) return _CwpsStatus('HIGH', const Color(0xFFE74C3C));
    return _CwpsStatus('NORMAL', const Color(0xFF2ECC71));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('CWPS • Pressure Transmitters', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_CwpsPressureFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _CwpsErrorView(
                    message: 'Failed to load pressures',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchPressures()),
                  );
                }

                final result = snap.data!;
                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _CwpsLegendDot(label: 'LOW', color: Color(0xFFE67E22)),
                          _CwpsLegendDot(label: 'NORMAL', color: Color(0xFF2ECC71)),
                          _CwpsLegendDot(label: 'HIGH', color: Color(0xFFE74C3C)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),

                      ...result.pts.map((pt) {
                        final st = _classify(pt.value);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CwpsPTTile(
                           title: _ptTitle(pt.index),
                            value: pt.value,
                            unit: unit,
                            statusText: st.text,
                            statusColor: st.color,
                            maxValue: maxBar,
                          ),
                        );
                      }),
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

// ---------- models ----------

class _CwpsPressureFetchResult {
  final List<_CwpsPTReading> pts;
  final String? serverTimeIso;
  _CwpsPressureFetchResult({required this.pts, required this.serverTimeIso});
}

class _CwpsPTReading {
  final int index;   // PT-1..PT-7
  final String key;  // 'A2'..'A8'
  final double? value;
  _CwpsPTReading({required this.index, required this.key, required this.value});
}

class _CwpsStatus {
  final String text;
  final Color color;
  _CwpsStatus(this.text, this.color);
}

// ---------- widgets ----------

class _CwpsLegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _CwpsLegendDot({required this.label, required this.color, super.key});

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

class _CwpsPTTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final String statusText;
  final Color statusColor;
  final double maxValue;

  const _CwpsPTTile({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.statusText,
    required this.statusColor,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = value == null || maxValue <= 0
        ? 0.0
        : (value!.clamp(0, maxValue) / maxValue);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Value
          Text(
            value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress, // null => indeterminate
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CwpsErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _CwpsErrorView({required this.message, this.details, required this.onRetry, super.key});

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
