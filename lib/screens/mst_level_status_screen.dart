import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MstLevelStatusScreen extends StatefulWidget {
  const MstLevelStatusScreen({super.key});

  @override
  State<MstLevelStatusScreen> createState() => _MstLevelStatusScreenState();
}

class _MstLevelStatusScreenState extends State<MstLevelStatusScreen> {
  // MST API (flat sensor names)
  static const String apiUrl = 'http://192.168.123.154:5000/api/mst-analog/latest';

  // Keys in the "sensors" object
  static const String kLT1 = 'Level Transmitter 1';
  static const String kLT2 = 'Level Transmitter 2';

  late Future<_MstLevelFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchLevel();
  }

  Future<_MstLevelFetchResult> _fetchLevel() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final root = json.decode(res.body) as Map<String, dynamic>;
    final data = (root['data'] ?? {}) as Map<String, dynamic>;

    // Pick MST_01 if present; otherwise take the first entry defensively
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
    final String? serverAt = (dateStr != null && timeStr != null) ? '${dateStr}T$timeStr' : null;

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lt1 = _toDouble(sensors[kLT1]);
    final lt2 = _toDouble(sensors[kLT2]);

    return _MstLevelFetchResult(lt1: lt1, lt2: lt2, serverTimeIso: serverAt);
  }

  Future<void> _refresh() async {
    final r = await _fetchLevel();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _LevelStatus _classify(double? v) {
    // Same thresholds/style as CWPS screen
    if (v == null) return _LevelStatus('UNKNOWN', Colors.grey);
    if (v < 20) return _LevelStatus('LOW', const Color(0xFFE67E22));
    if (v > 80) return _LevelStatus('HIGH', const Color(0xFFE74C3C));
    return _LevelStatus('NORMAL', const Color(0xFF2ECC71));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('MST • Level Transmitters', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_MstLevelFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _LevelErrorView(
                    message: 'Failed to load level',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchLevel()),
                  );
                }

                final result = snap.data!;
                final tiles = <({String title, double? value})>[
                  (title: 'Level Transmitter 1', value: result.lt1),
                  (title: 'Level Transmitter 2', value: result.lt2),
                ];

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
                          _LegendDot(label: 'LOW', color: Color(0xFFE67E22)),
                          _LegendDot(label: 'NORMAL', color: Color(0xFF2ECC71)),
                          _LegendDot(label: 'HIGH', color: Color(0xFFE74C3C)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),

                      const SizedBox(height: 12),

                      ...tiles.map((t) {
                        final st = _classify(t.value);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LevelTile(
                            title: t.title,
                            value: t.value,
                            unit: 'M',
                            statusText: st.text,
                            statusColor: st.color,
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

// ===== Models =====
class _MstLevelFetchResult {
  final double? lt1;
  final double? lt2;
  final String? serverTimeIso;
  _MstLevelFetchResult({required this.lt1, required this.lt2, required this.serverTimeIso});
}

class _LevelStatus {
  final String text;
  final Color color;
  _LevelStatus(this.text, this.color);
}

// ===== Widgets (same look as CWPS) =====
class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color, super.key});

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
  final double? value; // assume 0–100 scale unless you adjust thresholds
  final String unit;
  final String statusText;
  final Color statusColor;

  const _LevelTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.statusText,
    required this.statusColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = ((value ?? 0).clamp(0, 100)) / 100.0;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          Text(
            value == null ? '—' : '${value!.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress,
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

class _LevelErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _LevelErrorView({required this.message, this.details, required this.onRetry, super.key});

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
