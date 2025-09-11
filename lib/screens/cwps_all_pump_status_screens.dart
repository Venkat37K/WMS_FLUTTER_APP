import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 0/1 from API → OFF/ON
enum CwphPumpState { on, off }

class CwphPumpInfo {
  final String name;
  final CwphPumpState state;
  final double? flowM3h;
  final double? pressureBar;

  const CwphPumpInfo({
    required this.name,
    required this.state,
    this.flowM3h,
    this.pressureBar,
  });
}

class CwphAllPumpStatusScreen extends StatefulWidget {
  const CwphAllPumpStatusScreen({super.key});

  @override
  State<CwphAllPumpStatusScreen> createState() => _CwphAllPumpStatusScreenState();
}

class _CwphAllPumpStatusScreenState extends State<CwphAllPumpStatusScreen> {
  // TODO: replace with your CWPH endpoint
  static const String apiUrl = 'http://192.168.123.154:5000/api/cwph/tabs';

  // We show exactly 6 pumps: A1..A6 → PUMP-01..PUMP-06
  static const int visiblePumpCount = 6;

  late Future<_CwphPumpFetchResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPumps();
  }

  CwphPumpState _stateFromRaw(dynamic raw) {
    // Accept 1, 1.0, '1' as ON; anything else → OFF
    if (raw == 1 || raw == 1.0) return CwphPumpState.on;
    if (raw is String && raw.trim() == '1') return CwphPumpState.on;
    return CwphPumpState.off;
  }

  Future<_CwphPumpFetchResult> _fetchPumps() async {
    final res = await http.get(Uri.parse(apiUrl));
    if (res.statusCode != 200) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final tabs = (data['tabs'] ?? {}) as Map<String, dynamic>;

    // If your JSON uses "TAB 1" (with a space), this handles both:
    final tab1Any = tabs['TAB1'] ?? tabs['TAB 1'];
    final tab1 = (tab1Any is Map<String, dynamic>) ? tab1Any : <String, dynamic>{};

    final List<CwphPumpInfo> pumps = [];

    // A1..A6 => PUMP-01..PUMP-06
    for (int i = 1; i <= visiblePumpCount; i++) {
      final key = 'A$i';
      pumps.add(CwphPumpInfo(
        // name: 'PUMP-${i.toString().padLeft(2, '0')}',
        name: 'PUMP $i',
        state: _stateFromRaw(tab1[key]),
        flowM3h: null,
        pressureBar: null,
      ));
    }

    final String? at = data['at'] as String?;
    return _CwphPumpFetchResult(pumps: pumps, serverTimeIso: at);
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
        title: const Text('CWPS • All Pump Status', style: TextStyle(color: Colors.white)),
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
            child: FutureBuilder<_CwphPumpFetchResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                }
                if (snap.hasError) {
                  return _CwphErrorView(
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
                          _CwphLegendDot(label: 'ON',  color: Color(0xFF2ECC71)),
                          _CwphLegendDot(label: 'OFF', color: Color(0xFFBDC3C7)),
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
                          itemBuilder: (context, i) => _CwphPumpStatusTile(pump: pumps[i]),
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

class _CwphPumpFetchResult {
  final List<CwphPumpInfo> pumps;
  final String? serverTimeIso;

  _CwphPumpFetchResult({required this.pumps, required this.serverTimeIso});
}

class _CwphLegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _CwphLegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text(' ', style: TextStyle(color: Colors.white, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class _CwphPumpStatusTile extends StatelessWidget {
  final CwphPumpInfo pump;
  const _CwphPumpStatusTile({super.key, required this.pump});

  @override
  Widget build(BuildContext context) {
    late final Color chipColor;
    late final String chipText;
    late final IconData icon;
    late final Color iconBg;

    if (pump.state == CwphPumpState.on) {
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CwphErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback onRetry;
  const _CwphErrorView({required this.message, this.details, required this.onRetry});

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
