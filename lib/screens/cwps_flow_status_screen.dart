import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CwpsFlowStatusScreen extends StatefulWidget {
  const CwpsFlowStatusScreen({super.key});

  @override
  State<CwpsFlowStatusScreen> createState() => _CwpsFlowStatusScreenState();
}

class _CwpsFlowStatusScreenState extends State<CwpsFlowStatusScreen> {
  // Same CWPH API base you used for other CWPS screens
  static const String apiUrl = 'http://13.126.21.76:5000/api/cwph/tabs';

  // Source: TAB2 → A9 (FT-1), A10 (FTZ-1)
  static const String _tabName = 'TAB2';
  static const String _ftKey = 'A9';   // Flow Transmitter 1
  static const String _ftzKey = 'A10'; // Flow Totalizer 1

  // Display settings (tweak if your plant differs)
  static const String flowUnit = 'm³/h';
  static const String totalUnit = 'm³';
  static const double maxFlow = 500.0;       // for FT progress scaling
  static const double maxTotal = 10000.0;    // for FTZ progress scaling (optional)
  static const double noFlowThreshold = 0.1; // <= this => "NO FLOW"

  late Future<_CwpsFlowFetchResult> _future;
  bool _showTotalizer = false; // false => show FT; true => show FTZ

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_CwpsFlowFetchResult> _fetch() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // Be tolerant to "TAB 2" vs "TAB2"
    final t2Any = tabs[_tabName] ?? tabs['TAB 2'];
    final t2 = (t2Any is Map<String, dynamic>) ? t2Any : <String, dynamic>{};

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final double? ft1 = _toDouble(t2[_ftKey]);   // A9
    final double? ftz1 = _toDouble(t2[_ftzKey]); // A10
    final String? serverAt = data['at'] as String?;

    return _CwpsFlowFetchResult(ft1: ft1, ftz1: ftz1, serverTimeIso: serverAt);
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
            _showTotalizer ? 'CWPS • Flow Totalizer' : 'CWPS • Flow',
        style: const TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_CwpsFlowFetchResult>(
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
                    message: 'Failed to load flow data',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetch()),
                  );
                }

                final result = snap.data!;

                // Build the one tile we need (FT OR FTZ)
                final bool isFTZ = _showTotalizer;
                final String title = isFTZ ? 'FIQ 1 (Common)' : 'FT 1 (Common)';
                final double? value = isFTZ ? result.ftz1 : result.ft1;
                final String unit = isFTZ ? totalUnit : flowUnit;
                final double maxVal = isFTZ ? maxTotal : maxFlow;
                final _Status? status = isFTZ ? null : _classifyFlow(value);

                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Legend & timestamp
                         if (!isFTZ)
                        const Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _CwpsLegendDot(label: 'NO FLOW', color: Color(0xFFE67E22)),
                            _CwpsLegendDot(label: 'FLOWING', color: Color(0xFF2ECC71)),
                          ],
                        ),
                         if (isFTZ)
                        const _CwpsLegendDot(label: 'TOTALIZER (Cumulative)', color: Colors.white),
                
                      const SizedBox(height: 8),
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),


                         // The single tile
                         Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CwpsValueTile(
                        title: title,
                        value: value,
                        unit: unit,
                        maxValue: maxVal,
                        statusText: status?.text,
                        statusColor: status?.color,
                      ),
                         ),

                      const SizedBox(height: 8),

                      // NEXT/PREV button
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

class _CwpsFlowFetchResult {
  final double? ft1;   // TAB2.A9
  final double? ftz1;  // TAB2.A10
  final String? serverTimeIso;
  _CwpsFlowFetchResult({required this.ft1, required this.ftz1, required this.serverTimeIso});
}

class _Status {
  final String text;
  final Color color;
  _Status(this.text, this.color);
}

// ===== Widgets =====

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

class _CwpsValueTile extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final double maxValue;
  final String? statusText; // null => hide chip
  final Color? statusColor;

  const _CwpsValueTile({
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
          // Title + optional status
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (statusText != null && statusColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor!.withOpacity(.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor!),
                  ),
                  child: Text(
                    statusText!,
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
              valueColor: AlwaysStoppedAnimation<Color>(
                (statusColor ?? Colors.blueGrey),
              ),
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
