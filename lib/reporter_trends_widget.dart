import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'ui_components.dart';

class ReporterTrendsWidget extends StatefulWidget {
  final User user;

  const ReporterTrendsWidget({super.key, required this.user});

  @override
  State<ReporterTrendsWidget> createState() => _ReporterTrendsWidgetState();
}

class _ReporterTrendsWidgetState extends State<ReporterTrendsWidget> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<Map<String, int>> _getTrendsStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      final trendData = <String, int>{};
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        trendData[_dateKey(date)] = 0;
      }

      if (!event.snapshot.exists) {
        return trendData;
      }

      final data = event.snapshot.value as Map?;
      data?.forEach((key, value) {
        if (value is! Map) return;
        if (value['reporterUid']?.toString() != widget.user.uid) return;

        final date = DateTime.tryParse(value['date']?.toString() ?? '');
        if (date == null) return;

        final keyString = _dateKey(date);
        if (trendData.containsKey(keyString)) {
          trendData[keyString] = (trendData[keyString] ?? 0) + 1;
        }
      });

      return trendData;
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _getTrendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(height: 18, width: 160),
                SizedBox(height: AppSpacing.lg),
                AppSkeletonBox(height: 220),
              ],
            ),
          );
        }

        final trendData = snapshot.data ?? {};
        final labels = <String>[];
        final spots = <FlSpot>[];
        final values = <double>[];

        for (int i = 0; i < 7; i++) {
          final date = DateTime.now().subtract(Duration(days: 6 - i));
          final count = (trendData[_dateKey(date)] ?? 0).toDouble();
          labels.add(_weekdayLabel(date.weekday));
          values.add(count);
          spots.add(FlSpot(i.toDouble(), count));
        }

        final totalThisWeek = values.fold<double>(
          0,
          (sum, value) => sum + value,
        );
        final maxValue = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a > b ? a : b);
        final maxY = maxValue <= 0 ? 1.0 : maxValue + 1;
        final average = totalThisWeek / 7;

        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submission trends',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Last 7 days',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.outline.withValues(alpha: 0.7),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(
                          color: AppColors.outline.withValues(alpha: 0.8),
                        ),
                        bottom: BorderSide(
                          color: AppColors.outline.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[index],
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (items) {
                          return items.map((item) {
                            return LineTooltipItem(
                              '${labels[item.x.toInt()]}\n${item.y.toInt()} submissions',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: maxValue > 0,
                        curveSmoothness: maxValue > 0 ? 0.25 : 0,
                        preventCurveOverShooting: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.18),
                              AppColors.primary.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isActive = spot.y > 0;
                            return FlDotCirclePainter(
                              radius: isActive ? 4 : 3,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.surfaceMuted,
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
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _TrendSummary(
                      label: 'This week',
                      value: totalThisWeek.toInt().toString(),
                      icon: Icons.insights_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _TrendSummary(
                      label: 'Avg / day',
                      value: average.toStringAsFixed(1),
                      icon: Icons.show_chart_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      default:
        return 'Sun';
    }
  }
}

class _TrendSummary extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TrendSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadii.medium,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadii.small,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
