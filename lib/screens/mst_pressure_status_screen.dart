// lib/screens/mst_pressure_screen_status.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MstPressureStatusScreen extends StatefulWidget {
  const MstPressureStatusScreen({super.key});

  @override
  State<MstPressureStatusScreen> createState() => _MstPressureStatusScreenState();
}

class _MstPressureStatusScreenState extends State<MstPressureStatusScreen> {
  // MST analog endpoint (same as your level screen)
  static const String apiUrl = 'http://13.126.21.76:5000/api/mst-analog/latest';

  // Display settings (kept same look/feel as CWPS)
  static const String unit = 'mH20';
  static const double maxBar = 10.0;
  static const double lowThreshold = 2.0;   // < 2.0 -> LOW
  static const double highThreshold = 8.0;  // > 8.0 -> HIGH

  late Future<_MstPressureFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPressures();
  }

  Future<_MstPressureFetchResult> _fetchPressures() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final root = json.decode(res.body) as Map<String, dynamic>;
    final data = (root['data'] ?? {}) as Map<String, dynamic>;

    // Prefer "MST_01"; otherwise use the first site defensively
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

    // Support either single "Pressure Transmitter" or numbered "Pressure Transmitter 1/2"
    final hasPT1 = sensors.containsKey('Pressure Transmitter 1');
    final hasPT2 = sensors.containsKey('Pressure Transmitter 2');
    final hasPT = sensors.containsKey('Pressure Transmitter');

    final readings = <_MstPTReading>[];
    if (hasPT1 || hasPT2) {
      if (hasPT1) readings.add(_MstPTReading(index: 1, value: _toDouble(sensors['Pressure Transmitter 1'])));
      if (hasPT2) readings.add(_MstPTReading(index: 2, value: _toDouble(sensors['Pressure Transmitter 2'])));
    } else if (hasPT) {
      readings.add(_MstPTReading(index: 1, value: _toDouble(sensors['Pressure Transmitter'])));
    }

    return _MstPressureFetchResult(pts: readings, serverTimeIso: serverAt);
  }

  Future<void> _refresh() async {
    final r = await _fetchPressures();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _MstStatus _classify(double? v) {
    if (v == null) return _MstStatus('UNKNOWN', Colors.grey);
    if (v < lowThreshold) return _MstStatus('LOW', const Color(0xFFE67E22));
    if (v > highThreshold) return _MstStatus('HIGH', const Color(0xFFE74C3C));
    return _MstStatus('NORMAL', const Color(0xFF2ECC71));
  }

  String _titleForIndex(int idx, int total) {
    // Keep titles simple (no pump tags for MST)
    if (total == 1) return 'Pressure Transmitter';
    return 'Pressure Transmitter $idx';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('MST • Pressure Transmitter', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_MstPressureFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _MstErrorView(
                    message: 'Failed to load pressures',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchPressures()),
                  );
                }

                final result = snap.data!;
                final total = result.pts.length;

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

                      ...result.pts.map((pt) {
                        final st = _classify(pt.value);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PTTile(
                            title: _titleForIndex(pt.index, total),
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

// ===== Models =====
class _MstPressureFetchResult {
  final List<_MstPTReading> pts;
  final String? serverTimeIso;
  _MstPressureFetchResult({required this.pts, required this.serverTimeIso});
}

class _MstPTReading {
  final int index;      // 1, 2 (or 1 if single PT)
  final double? value;
  _MstPTReading({required this.index, required this.value});
}

class _MstStatus {
  final String text;
  final Color color;
  _MstStatus(this.text, this.color);
}

// ===== Widgets (same as CWPS) =====
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

class _PTTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final String statusText;
  final Color statusColor;
  final double maxValue;

  const _PTTile({
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
    final double progress = value == null || maxValue <= 0 ? 0.0 : (value!.clamp(0, maxValue) / maxValue);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Value
          Text(value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
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

class _MstErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _MstErrorView({required this.message, this.details, required this.onRetry, super.key});

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
