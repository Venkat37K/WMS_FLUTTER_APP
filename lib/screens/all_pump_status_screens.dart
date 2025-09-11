import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 0/1 from API → OFF/ON
enum PumpState { on, off }

class PumpInfo {
  final String name;
  final PumpState state;
  final double? flowM3h;
  final double? pressureBar;

  const PumpInfo({
    required this.name,
    required this.state,
    this.flowM3h,
    this.pressureBar,
  });
}

class AllPumpStatusScreen extends StatefulWidget {
  const AllPumpStatusScreen({super.key});

  @override
  State<AllPumpStatusScreen> createState() => _AllPumpStatusScreenState();
}

class _AllPumpStatusScreenState extends State<AllPumpStatusScreen> {
  static const String apiUrl = 'http://192.168.123.154:5000/api/rwph/tabs';

  /// We now show A1–A6 as PUMP-01..06, then add Cooling pumps from A7 & A8.
  static const int visibleStandardPumpCount = 6;

  late Future<_PumpFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPumps();
  }

  PumpState _stateFromRaw(dynamic raw) {
    // Accept 1, 1.0, '1' as ON; anything else → OFF
    if (raw == 1 || raw == 1.0) return PumpState.on;
    if (raw is String && raw.trim() == '1') return PumpState.on;
    return PumpState.off;
  }

  Future<_PumpFetchResult> _fetchPumps() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    // Expecting: { ok, db, at, tabs: { TAB1: { A1: 0|1, ... } } }
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;
    final tab1 = (tabs['TAB1'] ?? {}) as Map<String, dynamic>;

    final List<PumpInfo> pumps = [];

    // A1..A6 => PUMP-01..PUMP-06
    for (int i = 1; i <= visibleStandardPumpCount; i++) {
      final key = 'A$i';
      final state = _stateFromRaw(tab1[key]);
      pumps.add(PumpInfo(
        name: 'PUMP ${i}',
        state: state,
        flowM3h: null,
        pressureBar: null,
      ));
    }

    // A7 => Cooling Line Water Pump 1
    pumps.add(PumpInfo(
      name: 'Cooling Line Water Pump 1',
      state: _stateFromRaw(tab1['A7']),
      flowM3h: null,
      pressureBar: null,
    ));

    // A8 => Cooling Line Water Pump 2
    pumps.add(PumpInfo(
      name: 'Cooling Line Water Pump 2',
      state: _stateFromRaw(tab1['A8']),
      flowM3h: null,
      pressureBar: null,
    ));

    final String? at = data['at'] as String?;
    return _PumpFetchResult(
      pumps: pumps,
      serverTimeIso: at,
    );
  }

  Future<void> _refresh() async {
    final result = await _fetchPumps();
    if (!mounted) return;
    setState(() => _future = Future.value(result));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB21212),
        elevation: 0,
        title: const Text('RWPS • All Pump Status', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_PumpFetchResult>(
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
                    onRetry: () => setState(() => _future = _fetchPumps()),
                  );
                }

                final result = snap.data!;
                final pumps = result.pumps;

                return RefreshIndicator(
                  color: const Color(0xFFB21212),
                  backgroundColor: Colors.white,
                  onRefresh: _refresh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Legend: ON/OFF
                      const Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _LegendDot(label: 'ON',  color: Color(0xFF2ECC71)),
                          _LegendDot(label: 'OFF', color: Color(0xFFBDC3C7)),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Last updated (server time)
                      if (result.serverTimeIso != null)
                        Text(
                          'Last update: ${_formatIsoLocal(result.serverTimeIso!)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),

                      const SizedBox(height: 12),

                      // List
                      Expanded(
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: pumps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _PumpStatusTile(pump: pumps[i]),
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

class _PumpFetchResult {
  final List<PumpInfo> pumps;
  final String? serverTimeIso;

  _PumpFetchResult({
    required this.pumps,
    required this.serverTimeIso,
  });
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
        const Text(' ', style: TextStyle(color: Colors.white, fontSize: 12)), // spacing tweak
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _PumpStatusTile extends StatelessWidget {
  final PumpInfo pump;
  const _PumpStatusTile({super.key, required this.pump});

  @override
  Widget build(BuildContext context) {
    // Colors & icons for ON/OFF
    late final Color chipColor;
    late final String chipText;
    late final IconData icon;
    late final Color iconBg;

    if (pump.state == PumpState.on) {
      chipColor = const Color(0xFF2ECC71); // green
      chipText  = 'ON';
      icon      = Icons.play_arrow;
      iconBg    = const Color(0xFF1E8449);
    } else {
      chipColor = const Color(0xFFBDC3C7); // grey
      chipText  = 'OFF';
      icon      = Icons.pause;
      iconBg    = const Color(0xFF7F8C8D);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // leading icon
          Container(
            decoration: BoxDecoration(
              color: iconBg.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconBg, size: 22),
          ),
          const SizedBox(width: 12),

          // name + optional metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pump.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pump.flowM3h != null || pump.pressureBar != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (pump.flowM3h != null)
                        'Flow: ${pump.flowM3h!.toStringAsFixed(0)} m³/h',
                      if (pump.pressureBar != null)
                        'Pressure: ${pump.pressureBar!.toStringAsFixed(1)} bar',
                    ].join('   •   '),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),

          // status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipColor),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
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
