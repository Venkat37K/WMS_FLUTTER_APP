import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CwtlTlStatusScreen extends StatefulWidget {
  const CwtlTlStatusScreen({super.key});

  @override
  State<CwtlTlStatusScreen> createState() => _CwtlTlStatusScreenState();
}

class _CwtlTlStatusScreenState extends State<CwtlTlStatusScreen> {
  // Same endpoint used before, per-tag: /api/transmission/A1 ... /A32
  static const String baseUrl = 'http://13.126.21.76:5000/api/transmission';

  // ---- CWTL subset: A7..A12 ----
  static const List<int> _tagIndexes = [7, 8, 9, 10, 11, 12];

  // Display tuning (same as RWTL)
  static const String unit = 'mH2O';
  static const double maxBar = 10.0;       // progress bar scale
  static const double lowThreshold = 2.0;  // < 2 => LOW
  static const double highThreshold = 8.0; // > 8 => HIGH

  late Future<_TLFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSubset();
  }

  Future<_TLFetchResult> _fetchSubset() async {
    final futures = <Future<_TLReading>>[];
    for (final i in _tagIndexes) {
      futures.add(_fetchOne(i));
    }
    final items = await Future.wait(futures);

    DateTime? latest;
    for (final r in items) {
      if (r.dbTime != null) {
        latest = (latest == null || r.dbTime!.isAfter(latest!)) ? r.dbTime : latest;
      }
    }
    return _TLFetchResult(items: items, latestDbTime: latest);
  }

  Future<_TLReading> _fetchOne(int index) async {
    final tag = 'A$index';
    try {
      final res = await http.get(Uri.parse('$baseUrl/$tag'));
      if (res.statusCode != 200) {
        return _TLReading(index: index, value: null, dbTime: null, error: 'HTTP ${res.statusCode}');
      }

      final map = json.decode(res.body) as Map<String, dynamic>;

      // Parse value
      double? val;
      final raw = map['value'];
      if (raw is num) {
        val = raw.toDouble();
      } else if (raw is String) {
        // some endpoints send "No data" — ignore that
        val = double.tryParse(raw);
      }

      // Parse combined date+time (e.g. "2025-09-10" + "10:30:00")
      DateTime? dbTime;
      final date = map['date'];
      final time = map['time'];
      if (date is String && time is String && date != '-' && time != '-') {
        try {
          dbTime = DateTime.parse('$date $time');
        } catch (_) {}
      }

      return _TLReading(index: index, value: val, dbTime: dbTime, error: null);
    } catch (e) {
      return _TLReading(index: index, value: null, dbTime: null, error: e.toString());
    }
  }

  _Status _classify(double? v) {
    if (v == null) return _Status('UNKNOWN', Colors.grey);
    if (v < lowThreshold) return _Status('LOW', const Color(0xFFE67E22));
    if (v > highThreshold) return _Status('HIGH', const Color(0xFFE74C3C));
    return _Status('NORMAL', const Color(0xFF2ECC71));
  }

  Future<void> _refresh() async {
    final r = await _fetchSubset();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  // Tile titles per your sheet ("CTL - 1" .. "CTL - 6")
  String _titleFor(int i) => 'CTL - $i';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('CWTL • Pressure', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_TLFetchResult>(
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
                    message: 'Failed to load pressures',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchSubset()),
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
                          _LegendDot(label: 'LOW', color: Color(0xFFE67E22)),
                          _LegendDot(label: 'NORMAL', color: Color(0xFF2ECC71)),
                          _LegendDot(label: 'HIGH', color: Color(0xFFE74C3C)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (result.latestDbTime != null)
                        Text(
                          'Last update: ${_fmt(result.latestDbTime!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),

                      ...result.items.map((r) {
                        final st = _classify(r.value);
                        // r.index is 7..12 -> display CTL 1..6
                        final ctlIndex = r.index - 6;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PTTile(
                            title: _titleFor(ctlIndex),
                            value: r.value,
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

  static String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
           '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

// ---- models ----
class _TLFetchResult {
  final List<_TLReading> items;
  final DateTime? latestDbTime;
  _TLFetchResult({required this.items, required this.latestDbTime});
}

class _TLReading {
  final int index;        // 7..12 for CWTL
  final double? value;    // may be null if "No data"
  final DateTime? dbTime; // from SQL row (optional)
  final String? error;
  _TLReading({required this.index, required this.value, required this.dbTime, required this.error});
}

class _Status {
  final String text;
  final Color color;
  _Status(this.text, this.color);
}

// ---- widgets (same style as your TL/RWTL tiles) ----
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusText == 'UNKNOWN'
                      ? Colors.grey.withOpacity(.14)
                      : statusColor.withOpacity(.14),
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
            value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
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
