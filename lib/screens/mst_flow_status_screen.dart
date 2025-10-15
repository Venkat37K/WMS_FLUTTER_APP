// lib/screens/mst_flow_status_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MstFlowStatusScreen extends StatefulWidget {
  const MstFlowStatusScreen({super.key});

  @override
  State<MstFlowStatusScreen> createState() => _MstFlowStatusScreenState();
}

class _MstFlowStatusScreenState extends State<MstFlowStatusScreen> {
  static const String apiUrl = 'http://13.126.21.76:5000/api/mst-analog/latest';

  static const String flowUnit = 'm³/h';
  static const String totalUnit = 'm³';
  static const double maxFlow = 500.0;
  static const double maxTotal = 10000.0;
  static const double noFlowThreshold = 0.1;

  late Future<_MstFlowFetchResult> _future;
  bool _showTotalizer = false; // false => show FT list, true => show FIQ list

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_MstFlowFetchResult> _fetch() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final root = json.decode(res.body) as Map<String, dynamic>;
    final data = (root['data'] ?? {}) as Map<String, dynamic>;

    // Prefer MST_01, otherwise first site block
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

    // Helper to tolerate spelling/case
    dynamic _get(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k)) return m[k];
      }
      return null;
    }

    // ---- Read BOTH transmitters & totalizers ----
    final ft1 = _toDouble(_get(sensors, ['Flow transmitter 1', 'Flow Transmitter 1']));
    final ft2 = _toDouble(_get(sensors, ['Flow transmitter 2', 'Flow Transmitter 2']));
    final fiq1 = _toDouble(_get(sensors, ['Flow totaliser 1', 'Flow totalizer 1']));
    final fiq2 = _toDouble(_get(sensors, ['Flow totaliser 2', 'Flow totalizer 2']));

    return _MstFlowFetchResult(
      fts: [ft1, ft2],
      fiqs: [fiq1, fiq2],
      serverTimeIso: serverAt,
    );
  }

  _Status _classifyFlow(double? v) {
    if (v == null) return _Status('UNKNOWN', Colors.grey);
    if (v <= noFlowThreshold) return _Status('NO FLOW', const Color(0xFFE67E22));
    return _Status('FLOWING', const Color(0xFF2ECC71));
  }

  Future<void> _refresh() async {
    final r = await _fetch();
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
        title: Text(
          _showTotalizer ? 'MST • Flow Totalizer' : 'MST • Flow',
          style: const TextStyle(color: Colors.white),
        ),
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
            child: FutureBuilder<_MstFlowFetchResult>(
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
                    message: 'Failed to load flow data',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetch()),
                  );
                }

                final result = snap.data!;
                final isFTZ = _showTotalizer;
                final values = isFTZ ? result.fiqs : result.fts;
                final unit = isFTZ ? totalUnit : flowUnit;
                final maxVal = isFTZ ? maxTotal : maxFlow;

                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (!isFTZ)
                        const Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _LegendDot(label: 'NO FLOW', color: Color(0xFFE67E22)),
                            _LegendDot(label: 'FLOWING', color: Color(0xFF2ECC71)),
                          ],
                        )
                      else
                        const _LegendDot(label: 'TOTALIZER (Cumulative)', color: Colors.white),

                      const SizedBox(height: 8),
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),

                      // Render two tiles (1 & 2)
                      ...values.asMap().entries.map((e) {
                        final idx = e.key + 1; // 1 or 2
                        final val = e.value;
                        final st = isFTZ ? null : _classifyFlow(val);
                        final title = isFTZ ? 'Flow Totalizer $idx' : 'Flow Transmitter $idx';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ValueTile(
                            title: title,
                            value: val,
                            unit: unit,
                            maxValue: maxVal,
                            statusText: st?.text,
                            statusColor: st?.color,
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB21212),
                            elevation: 0,
                          ),
                          onPressed: () => setState(() => _showTotalizer = !_showTotalizer),
                          child: Text(isFTZ ? 'PREV' : 'NEXT'),
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
class _MstFlowFetchResult {
  final List<double?> fts;   // [FT-1, FT-2]
  final List<double?> fiqs;  // [FIQ-1, FIQ-2]
  final String? serverTimeIso;
  _MstFlowFetchResult({required this.fts, required this.fiqs, required this.serverTimeIso});
}

class _Status {
  final String text;
  final Color color;
  _Status(this.text, this.color);
}

// ===== Widgets =====
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

class _ValueTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final double maxValue;
  final String? statusText; // null => hide chip
  final Color? statusColor;

  const _ValueTile({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.maxValue,
    this.statusText,
    this.statusColor,
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
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              if (statusText != null && statusColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor!.withOpacity(.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor!),
                  ),
                  child: Text(statusText!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
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
              valueColor: AlwaysStoppedAnimation<Color>((statusColor ?? Colors.blueGrey)),
            ),
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
  const _ErrorView({required this.message, this.details, required this.onRetry, super.key});

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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB21212)),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
