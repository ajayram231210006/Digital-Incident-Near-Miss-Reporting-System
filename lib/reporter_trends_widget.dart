import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class ReporterTrendsWidget extends StatefulWidget {
  final User user;

  const ReporterTrendsWidget({super.key, required this.user});

  @override
  State<ReporterTrendsWidget> createState() => _ReporterTrendsWidgetState();
}

class _ReporterTrendsWidgetState extends State<ReporterTrendsWidget> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final bool _isWeekly = true;

  Stream<Map<String, int>> _getTrendsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      final Map<String, int> trendData = {};
      final now = DateTime.now();

      // Initialize data for last 7 days (weekly) or 12 months (yearly)
      if (_isWeekly) {
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final key =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          trendData[key] = 0;
        }
      }

      if (!event.snapshot.exists) {
        return trendData;
      }

      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            final reporterUid = value['reporterUid']?.toString() ?? '';
            if (reporterUid == widget.user.uid) {
              try {
                final dateStr = value['date']?.toString() ?? '';
                if (dateStr.isNotEmpty) {
                  final date = DateTime.parse(dateStr);
                  final reportKey = _isWeekly
                      ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                      : '${date.year}-${date.month.toString().padLeft(2, '0')}';

                  if (_isWeekly) {
                    final daysDiff =
                        now.difference(date).inDays;
                    if (daysDiff >= 0 && daysDiff < 7) {
                      trendData[reportKey] = (trendData[reportKey] ?? 0) + 1;
                    }
                  }
                }
              } catch (e) {
                // Handle date parsing errors
              }
            }
          }
        });
      }

      return trendData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _getTrendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final trendData = snapshot.data ?? {};
        final spots = <FlSpot>[];
        final labels = <String>[];

        if (_isWeekly) {
          final now = DateTime.now();
          for (int i = 0; i < 7; i++) {
            final date = now.subtract(Duration(days: 6 - i));
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final count = trendData[key] ?? 0;
            spots.add(FlSpot(i.toDouble(), count.toDouble()));
            labels.add(_getDayLabel(i));
          }
        }

        final maxY = spots.isEmpty ? 5.0 : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 2;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submission Trends',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last 7 days',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Chart
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 0.8,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() < labels.length) {
                                  return Text(
                                    labels[value.toInt()],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value == value.toInt()) {
                                  return Text(
                                    '${value.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 0.8,
                            ),
                            left: BorderSide(
                              color: Colors.grey.shade200,
                              width: 0.8,
                            ),
                          ),
                        ),
                        minX: 0,
                        maxX: (spots.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.blue.shade400,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withValues(alpha: 0.1),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 5,
                                  color: Colors.blue.shade400,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _TrendStatBox(
                          label: 'This Week',
                          value: spots
                              .fold<int>(0, (sum, spot) => sum + spot.y.toInt())
                              .toString(),
                          icon: Icons.trending_up,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TrendStatBox(
                          label: 'Avg/Day',
                          value: (spots.isEmpty
                                  ? 0
                                  : spots
                                          .fold<int>(
                                              0,
                                              (sum, spot) =>
                                                  sum +
                                                  spot.y
                                                      .toInt())
                                          .toDouble() /
                                      7)
                              .toStringAsFixed(1),
                          icon: Icons.show_chart,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getDayLabel(int index) {
    final now = DateTime.now();
    final date = now.subtract(Duration(days: 6 - index));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday % 7];
  }
}

// Stat Box Widget
class _TrendStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TrendStatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
