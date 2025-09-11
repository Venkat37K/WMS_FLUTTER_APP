import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FlowStatusScreen extends StatefulWidget {
  const FlowStatusScreen({super.key});

  @override
  State<FlowStatusScreen> createState() => _FlowStatusScreenState();
}

class _FlowStatusScreenState extends State<FlowStatusScreen> {
  static const String apiUrl = 'http://192.168.123.154:5000/api/rwph/tabs';

  // ---- Your mapping (TAB2) ----
  static const String tabName = 'TAB2';
  // FT-1..FT-7 => A16..A22
  static const int ftFirstIndex = 16;
  static const int ftCount = 7;
  // FTZ-1..FTZ-7 => A23..A29
  static const int ftzFirstIndex = 23;
  static const int ftzCount = 7;

  // ---- Display settings (tweak to your plant values) ----
  static const String flowUnit = 'm³/h';
  static const String totalUnit = 'm³';
  static const double maxFlow = 500.0;       // for FT progress bar scaling
  static const double maxTotal = 10000.0;    // for FTZ progress (optional)
  static const double noFlowThreshold = 0.1; // <= this => "NO FLOW"

  String _ftTitle(int idx) =>
    idx == 1 ? 'FT 1 (Common)' : 'FT $idx (Pump ${idx - 1})';

String _fiqTitle(int idx) =>
    idx == 1 ? 'FIQ 1 (Common)' : 'FIQ $idx (Pump ${idx - 1})';

  late Future<_FlowFetchResult> _future;
  bool _showTotalizer = false; // false => show FT; true => show FTZ

  @override
  void initState() {
    super.initState();
    _future = _fetchFlow();
  }

  Future<_FlowFetchResult> _fetchFlow() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;
    final tab = (tabs[tabName] ?? {}) as Map<String, dynamic>;

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // FT 1..7 => A16..A22
    final List<_Reading> fts = [];
    for (int i = 0; i < ftCount; i++) {
      final idx = ftFirstIndex + i;
      final key = 'A$idx';
      fts.add(_Reading(labelIndex: i + 1, key: key, value: _toDouble(tab[key])));
    }

    // FTZ 1..7 => A23..A29
    final List<_Reading> ftzs = [];
    for (int i = 0; i < ftzCount; i++) {
      final idx = ftzFirstIndex + i;
      final key = 'A$idx';
      ftzs.add(_Reading(labelIndex: i + 1, key: key, value: _toDouble(tab[key])));
    }

    return _FlowFetchResult(
      fts: fts,
      ftzs: ftzs,
      serverTimeIso: data['at'] as String?,
    );
  }

  Future<void> _refresh() async {
    final r = await _fetchFlow();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  _Status classifyFlow(double? v) {
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
        title: Text(
          _showTotalizer ? 'RWPS • Flow Totalizers' : 'RWPS • Flow Transmitters',
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
            child: FutureBuilder<_FlowFetchResult>(
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
                    onRetry: () => setState(() => _future = _fetchFlow()),
                  );
                }

                final result = snap.data!;
                final list = _showTotalizer ? result.ftzs : result.fts;

                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Legend & timestamp
                      if (!_showTotalizer)
                        const Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _LegendDot(label: 'NO FLOW', color: Color(0xFFE67E22)),
                            _LegendDot(label: 'FLOWING', color: Color(0xFF2ECC71)),
                          ],
                        ),
                      if (_showTotalizer)
                        const _LegendDot(label: 'TOTALIZER (Cumulative)', color: Colors.white),

                      const SizedBox(height: 8),
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),

                      // Items
                      ...list.map((r) {
                        final title = _showTotalizer
                            ? _fiqTitle(r.labelIndex)
                            : _ftTitle(r.labelIndex);

                        // Status only for FT (rates)
                        final status = _showTotalizer ? null : classifyFlow(r.value);

                        // Units & progress scaling
                        final unit = _showTotalizer ? totalUnit : (r.labelIndex == 1 ? flowUnit : 'LPM');
                        final maxVal = _showTotalizer ? maxTotal : maxFlow;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ValueTile(
                            title: title,
                            value: r.value,
                            unit: unit,
                            maxValue: maxVal,
                            statusText: status?.text,
                            statusColor: status?.color,
                          ),
                        );
                      }),

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
                          child: Text(_showTotalizer ? 'PREV' : 'NEXT'),
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

// --- Models & widgets ---

class _FlowFetchResult {
  final List<_Reading> fts;   // FT 1..7
  final List<_Reading> ftzs;  // FTZ 1..7
  final String? serverTimeIso;
  _FlowFetchResult({required this.fts, required this.ftzs, required this.serverTimeIso});
}

class _Reading {
  final int labelIndex; // 1..7
  final String key;     // A16..A22 / A23..A29
  final double? value;
  _Reading({required this.labelIndex, required this.key, required this.value});
}

class _Status {
  final String text;
  final Color color;
  _Status(this.text, this.color);
}

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
  final String? statusText; // null => no chip
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
