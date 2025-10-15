import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CwpsLevelStatusScreen extends StatefulWidget {
  const CwpsLevelStatusScreen({super.key});

  @override
  State<CwpsLevelStatusScreen> createState() => _CwpsLevelStatusScreenState();
}

class _CwpsLevelStatusScreenState extends State<CwpsLevelStatusScreen> {
  // Same CWPS API base you used for pumps:
  static const String apiUrl = 'http://13.126.21.76:5000/api/cwph/tabs';

  // Read from TAB2 → A1
  static const String _tabName = 'TAB2';
  static const String _lt1Key = 'A1';

  late Future<_CwpsLevelFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchLevel();
  }

  Future<_CwpsLevelFetchResult> _fetchLevel() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // Handle TAB2 or "TAB 2"
    final t2Any = tabs[_tabName] ?? tabs['TAB 2'];
    final t2 = (t2Any is Map<String, dynamic>) ? t2Any : <String, dynamic>{};

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lt1 = _toDouble(t2[_lt1Key]);
    final serverAt = data['at'] as String?;

    return _CwpsLevelFetchResult(lt1: lt1, serverTimeIso: serverAt);
  }

  Future<void> _refresh() async {
    final r = await _fetchLevel();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _CwpsLevelStatus _classify(double? v) {
    // Adjust thresholds to your real units (assuming 0–100%)
    if (v == null) return _CwpsLevelStatus('UNKNOWN', Colors.grey);
    if (v < 20) return _CwpsLevelStatus('LOW', const Color(0xFFE67E22));
    if (v > 80) return _CwpsLevelStatus('HIGH', const Color(0xFFE74C3C));
    return _CwpsLevelStatus('NORMAL', const Color(0xFF2ECC71));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('CWPS • Level Transmitter', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_CwpsLevelFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _CwpsLevelErrorView(
                    message: 'Failed to load level',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetchLevel()),
                  );
                }

                final result = snap.data!;
                final status = _classify(result.lt1);

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

                      _CwpsLevelTile(
                        title: 'LT 1',
                        value: result.lt1,
                        unit: 'M', // change if your units differ
                        statusText: status.text,
                        statusColor: status.color,
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

class _CwpsLevelFetchResult {
  final double? lt1;
  final String? serverTimeIso;
  _CwpsLevelFetchResult({required this.lt1, required this.serverTimeIso});
}

class _CwpsLevelStatus {
  final String text;
  final Color color;
  _CwpsLevelStatus(this.text, this.color);
}

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

class _CwpsLevelTile extends StatelessWidget {
  final String title;
  final double? value; // assume 0–100
  final String unit;
  final String statusText;
  final Color statusColor;

  const _CwpsLevelTile({
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
          // Row: title + status chip
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
            value == null ? '—' : '${value!.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value == null ? null : progress, // null shows indeterminate
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

class _CwpsLevelErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _CwpsLevelErrorView({required this.message, this.details, required this.onRetry, super.key});

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
