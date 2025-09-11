import 'package:flutter/material.dart';
import 'rwtl_tl_screen_status.dart';
import 'cwtl_tl_screen_status.dart';
import 'feeder_main1_tl_screen_status.dart';
import 'feeder_main2_tl_screen_status.dart';
import 'home_screen.dart';


class TLScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18404A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFB21212),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Logo at top right
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/image.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Main content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Padding(
                      padding: const EdgeInsets.only(right: 64),
                      child: Text(
                        'WMS-APP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Text(
                          'TL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.black87, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                      Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        _MenuItem(
                      label: 'RWTL',
                      onTap: () {
Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RwtlTlStatusScreen()),
                      );
                      },
                    ),

                      _MenuItem(
                      label: 'CWTL',
                      onTap: () {
Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CwtlTlStatusScreen()),
                      );
                      },
                    ),

                      _MenuItem(
                      label: 'FEEDER MAIN 1',
                      onTap: () {
Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeederMain1TlStatusScreen()),
                      );
                      },
                    ),

                      _MenuItem(
                      label: 'FEEDER MAIN 2',
                      onTap: () {
Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeederMain2TlStatusScreen()),
                      );
                      },
                    ),

                      ],
                      ),

                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFB21212),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'HOME',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _MenuItem({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
     return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.1,
        ),
      ),
      ),
    );
  }
}