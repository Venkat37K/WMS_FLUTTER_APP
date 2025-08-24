import 'package:flutter/material.dart';
import 'cwps_screen.dart';
import 'rwps_screen.dart';
import 'tl_screen.dart';
import 'mst_screen.dart';
import 'msr_screen.dart';
import 'mbr_screen.dart';
import 'alarms_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Map<String, dynamic>> locations = [
    {'label': 'RWPS', 'widget': RWPScreen(), 'icon': Icons.water_drop},
    {'label': 'CWPS', 'widget': CWPScreen(), 'icon': Icons.water},
    {'label': 'TL', 'widget': TLScreen(), 'icon': Icons.bolt},
    {'label': 'MST', 'widget': MSTScreen(), 'icon': Icons.precision_manufacturing},
    {'label': 'MSR', 'widget': MSRScreen(), 'icon': Icons.science},
    {'label': 'MBR', 'widget': MBRScreen(), 'icon': Icons.bubble_chart},
    {'label': 'Critical Alarms', 'widget': AlarmScreen(), 'icon': Icons.warning},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB21212), Colors.red],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home, size: 64, color: Color(0xFFB21212)),
                    SizedBox(height: 16),
                    Text(
                      'WMS Home',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB21212),
                      ),
                    ),
                    SizedBox(height: 24),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: locations.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.red[50],
                          leading: Icon(
                            locations[index]['icon'],
                            color: Color(0xFFB21212),
                          ),
                          title: Text(
                            locations[index]['label'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFFB21212)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => locations[index]['widget']),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}