import 'package:flutter/material.dart';
import 'home_screen.dart';

class MBRScreen extends StatelessWidget {
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
              color: Color(0xFFB21212),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
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
                        'assets/Mstlogo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Main content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Padding(
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
                    SizedBox(height: 32),
                    Row(
                      children: [
                        Text(
                          'MBR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.precision_manufacturing, color: Colors.black87, size: 28),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    _MenuItem(label: 'LEVEL'),
                    _MenuItem(label: 'FLOW'),
                    SizedBox(height: 32),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFFB21212),
                          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                        child: Text(
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
  const _MenuItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}