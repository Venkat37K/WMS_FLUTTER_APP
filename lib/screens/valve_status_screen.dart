import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ValveStatusScreen extends StatefulWidget {
  const ValveStatusScreen({super.key});

  @override
  State<ValveStatusScreen> createState() => _ValveStatusScreenState();
}

class _ValveStatusScreenState extends State<ValveStatusScreen> {
  // RWPS base URL
  static const String apiUrl = 'http://13.126.21.76:5000/api/rwph/tabs';

  // Mapping (RWPS)
  // TAB1: A9..A15 -> Valve 1..7 (OPEN/CLOSE)
  static const List<String> _valveKeys = ['A9','A10','A11','A12','A13','A14','A15'];
  // TAB3: A1..A7  -> Valve Position 1..7 (%)
  static const List<String> _positionKeys = ['A1','A2','A3','A4','A5','A6','A7'];

  // Titles
  String _vTitle(int idx) =>
      idx == 7 ? 'Valve 7 (Common)' : 'Valve $idx (Pump $idx)';
  String _vpTitle(int idx) =>
      idx == 7 ? 'Valve Position 7 (Common)' : 'Valve Position $idx (Pump $idx)';

  late Future<_ValveFetchResult> _future;
  bool _showPositions = false; // false => Valves page, true => Positions page

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<_ValveFetchResult> _fetch() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // Be tolerant to "TAB 1"/"TAB1" and "TAB 3"/"TAB3"
    final t1Any = tabs['TAB1'] ?? tabs['TAB 1'];
    final t3Any = tabs['TAB3'] ?? tabs['TAB 3'];
    final t1 = (t1Any is Map<String, dynamic>) ? t1Any : <String, dynamic>{};
    final t3 = (t3Any is Map<String, dynamic>) ? t3Any : <String, dynamic>{};

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // Valves (OPEN/CLOSE) from TAB1 A9..A15
    final valves = <_ValveReading>[];
    for (int i = 0; i < _valveKeys.length; i++) {
      final raw = t1[_valveKeys[i]];
      final st = _statusFromRaw(raw);
      valves.add(_ValveReading(index: i + 1, text: st.text, isOpen: st.isOpen));
    }

    // Positions (%) from TAB3 A1..A7
    final positions = <_PositionReading>[];
    for (int i = 0; i < _positionKeys.length; i++) {
      final v = _toDouble(t3[_positionKeys[i]]);
      positions.add(_PositionReading(index: i + 1, value: v));
    }

    return _ValveFetchResult(
      valves: valves,
      positions: positions,
      serverTimeIso: data['at'] as String?,
    );
  }

  static ({String text, bool isOpen}) _statusFromRaw(dynamic raw) {
    if (raw == 1 || raw == 1.0) return (text: 'OPEN', isOpen: true);
    if (raw == 0 || raw == 0.0) return (text: 'CLOSE', isOpen: false);
    if (raw is String) {
      final v = raw.trim().toUpperCase();
      if (v == '1' || v == 'OPEN' || v == 'ON') return (text: 'OPEN', isOpen: true);
      if (v == '0' || v == 'CLOSE' || v == 'OFF') return (text: 'CLOSE', isOpen: false);
      return (text: v, isOpen: v == 'OPEN');
    }
    return (text: '--', isOpen: false);
  }

  Future<void> _refresh() async {
    final r = await _fetch();
    if (!mounted) return;
    setState(() => _future = Future.value(r));
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        _showPositions ? 'RWPS • Valve Positions' : 'RWPS • Valves';

    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_ValveFetchResult>(
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
                    message: 'Failed to load valve data',
                    details: snap.error.toString(),
                    onRetry: () => setState(() => _future = _fetch()),
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
                      // Legend
                      if (!_showPositions)
                        const Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _LegendDot(label: 'OPEN',  color: Color(0xFF2ECC71)),
                            _LegendDot(label: 'CLOSE', color: Color(0xFFE74C3C)),
                          ],
                        ),
                      if (_showPositions) const _UnitsLegend(),

                      const SizedBox(height: 8),
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(height: 12),

                      // Content list
                      if (!_showPositions)
                        ...result.valves.map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ValveTileStack(
                                title: _vTitle(v.index),
                                stateText: v.text,
                                isOpen: v.isOpen,
                              ),
                            ))
                      else
                        ...result.positions.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PositionTileStack(
                                title: _vpTitle(p.index),
                                value: p.value,
                                unit: '%',
                              ),
                            )),

                      const SizedBox(height: 8),

                      // NEXT / PREV toggle
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB21212),
                            elevation: 0,
                          ),
                          onPressed: () => setState(() => _showPositions = !_showPositions),
                          child: Text(_showPositions ? 'PREV' : 'NEXT'),
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
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
             '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    } catch (_) {
      return iso;
    }
  }
}

// ===== Models =====
class _ValveReading {
  final int index;      // 1..7
  final String text;    // OPEN / CLOSE / --
  final bool isOpen;
  _ValveReading({required this.index, required this.text, required this.isOpen});
}

class _PositionReading {
  final int index;      // 1..7
  final double? value;  // percent
  _PositionReading({required this.index, required this.value});
}

class _ValveFetchResult {
  final List<_ValveReading> valves;
  final List<_PositionReading> positions;
  final String? serverTimeIso;
  _ValveFetchResult({required this.valves, required this.positions, required this.serverTimeIso});
}

// ===== Widgets (stacked like Flow screens) =====

class _ValveTileStack extends StatelessWidget {
  final String title;
  final String stateText;
  final bool isOpen;
  const _ValveTileStack({
    super.key,
    required this.title,
    required this.stateText,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final Color chipColor = (stateText == '--')
        ? Colors.blueGrey
        : (isOpen ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipColor),
            ),
            child: Text(
              stateText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: chipColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionTileStack extends StatelessWidget {
  final String title;
  final double? value;   // 0–100
  final String unit;     // '%'

  const _PositionTileStack({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            value == null ? '—' : '${value!.toStringAsFixed(2)} $unit',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

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

class _UnitsLegend extends StatelessWidget {
  const _UnitsLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.circle, size: 10, color: Colors.white),
        SizedBox(width: 6),
        Text('Units: %', style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
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
