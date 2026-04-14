import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'app_theme.dart';

class ActivityTimelineWidget extends StatefulWidget {
  final User user;

  const ActivityTimelineWidget({super.key, required this.user});

  @override
  State<ActivityTimelineWidget> createState() => _ActivityTimelineWidgetState();
}

class _ActivityTimelineWidgetState extends State<ActivityTimelineWidget> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<List<Map<String, dynamic>>> _getActivityStream() {
    return _dbRef.child('incidents').onValue.map((event) {
      final activities = <Map<String, dynamic>>[];

      if (!event.snapshot.exists) {
        return activities;
      }

      final data = event.snapshot.value as Map?;
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            final reporterUid = value['reporterUid']?.toString() ?? '';
            if (reporterUid == widget.user.uid) {
              try {
                final dateStr = value['date']?.toString() ?? '';
                DateTime? date;
                if (dateStr.isNotEmpty) {
                  date = DateTime.parse(dateStr);
                }

                activities.add({
                  'id': key,
                  'type': value['type'] ?? 'Unknown',
                  'status': (value['status'] ?? 'open')
                      .toString()
                      .toLowerCase(),
                  'date': date ?? DateTime.now(),
                  'description': value['description'] ?? 'No description',
                  'location': value['location'] ?? 'Unknown',
                });
              } catch (e) {
                // Handle parsing errors
              }
            }
          }
        });
      }

      // Sort by date (newest first)
      activities.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      // Return only latest 5
      return activities.take(5).toList();
    });
  }

  Color _getStatusColor(String status) {
    return AppStatus.resolve(status).color;
  }

  IconData _getStatusIcon(String status) {
    return AppStatus.resolve(status).icon;
  }

  String _getStatusLabel(String status) {
    return AppStatus.resolve(status).label;
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getActivityStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.large,
            boxShadow: AppShadows.subtle,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.large,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surface, AppColors.surfaceRaised],
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Timeline
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activities.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        color: AppColors.outline.withValues(alpha: 0.45),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      final statusColor = _getStatusColor(activity['status']);
                      final statusIcon = _getStatusIcon(activity['status']);
                      final statusLabel = _getStatusLabel(activity['status']);
                      final timeStr = _formatTime(activity['date']);

                      return _ActivityTimelineItem(
                        icon: statusIcon,
                        color: statusColor,
                        title: activity['type'],
                        subtitle: activity['location'],
                        status: statusLabel,
                        time: timeStr,
                        isFirst: index == 0,
                        isLast: index == activities.length - 1,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Timeline Item Widget
class _ActivityTimelineItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final String time;
  final bool isFirst;
  final bool isLast;

  const _ActivityTimelineItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.time,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline line and dot
        Column(
          children: [
            // Dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
            ),
            // Line
            if (!isLast)
              Container(width: 2, height: 60, color: AppColors.outline),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
