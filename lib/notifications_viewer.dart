import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'notification_service.dart';
import 'reporter_report_detail.dart';
import 'ui_components.dart';

class NotificationsViewer extends StatefulWidget {
  final User user;

  const NotificationsViewer({super.key, required this.user});

  @override
  State<NotificationsViewer> createState() => _NotificationsViewerState();
}

class _NotificationsViewerState extends State<NotificationsViewer> {
  final NotificationService _notificationService = NotificationService();
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadNotificationCount(
              widget.user.uid,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Mark all as read',
                icon: const Icon(Icons.done_all_rounded),
                onPressed: () async {
                  await _notificationService.markAllNotificationsAsRead(
                    widget.user.uid,
                  );
                  if (!context.mounted) return;
                  showAppSnackBar(
                    context,
                    'All notifications marked as read.',
                    type: AppSnackBarType.success,
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: FilterChip(
                label: const Text('Unread only'),
                selected: _showUnreadOnly,
                onSelected: (selected) {
                  setState(() => _showUnreadOnly = selected);
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationService.getUserNotifications(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _NotificationSkeleton();
          }

          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Notifications unavailable',
              description:
                  'We could not load your notifications right now. Please try again.',
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }

          var notifications = snapshot.data ?? <Map<String, dynamic>>[];
          if (_showUnreadOnly) {
            notifications = notifications
                .where((item) => !(item['read'] ?? false))
                .toList();
          }

          if (notifications.isEmpty) {
            return AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: _showUnreadOnly
                  ? 'No unread notifications'
                  : 'No notifications yet',
              description:
                  'Updates from supervisors will appear here as your reports change.',
            );
          }

          final grouped = _groupNotifications(notifications);
          final sections = grouped.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final entry = sections[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == sections.length - 1 ? 0 : AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...entry.value.map(_buildNotificationCard),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final notificationId = notification['id']?.toString() ?? '';
    final isRead = notification['read'] ?? false;
    final title = notification['title']?.toString() ?? 'Notification';
    final body = notification['body']?.toString() ?? 'No details available';
    final status = notification['status']?.toString();
    final supervisorName = notification['supervisorName']?.toString();
    final reportId = notification['reportId']?.toString();
    final notificationTime = _parseTimestamp(notification['timestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Dismissible(
        key: Key(notificationId),
        background: _SwipeActionBackground(
          color: AppColors.statusActive,
          alignment: Alignment.centerLeft,
          icon: Icons.mark_email_read_rounded,
          label: 'Mark read',
        ),
        secondaryBackground: _SwipeActionBackground(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await _notificationService.markNotificationAsRead(
              widget.user.uid,
              notificationId,
            );
            if (mounted) {
              showAppSnackBar(
                context,
                'Notification marked as read.',
                type: AppSnackBarType.success,
              );
            }
            return false;
          }

          await _notificationService.deleteNotification(
            widget.user.uid,
            notificationId,
          );
          if (mounted) {
            showAppSnackBar(
              context,
              'Notification deleted.',
              type: AppSnackBarType.info,
            );
          }
          return true;
        },
        child: AppSectionCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: InkWell(
            onTap: () async {
              if (!isRead) {
                await _notificationService.markNotificationAsRead(
                  widget.user.uid,
                  notificationId,
                );
              }
              if (reportId != null && reportId.isNotEmpty && mounted) {
                await _openIncidentReport(reportId);
              }
            },
            borderRadius: AppRadii.large,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppStatus.resolve(
                      status,
                    ).color.withValues(alpha: 0.12),
                    borderRadius: AppRadii.medium,
                  ),
                  child: Icon(
                    AppStatus.resolve(status).icon,
                    color: AppStatus.resolve(status).color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaLabel(
                            icon: Icons.access_time_rounded,
                            text: _getTimeString(notificationTime),
                          ),
                          if (supervisorName != null &&
                              supervisorName.isNotEmpty)
                            _MetaLabel(
                              icon: Icons.person_outline_rounded,
                              text: supervisorName,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    for (final notification in notifications) {
      final date = _parseTimestamp(notification['timestamp']);
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

      if (!date.isBefore(startOfToday)) {
        grouped['Today']!.add(notification);
      } else if (!date.isBefore(startOfYesterday)) {
        grouped['Yesterday']!.add(notification);
      } else {
        grouped['Older']!.add(notification);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  DateTime _parseTimestamp(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _getTimeString(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _openIncidentReport(String reportId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('incidents')
          .child(reportId)
          .get();

      if (!mounted) return;
      if (!snapshot.exists) {
        showAppSnackBar(
          context,
          'That report is no longer available.',
          type: AppSnackBarType.info,
        );
        return;
      }

      final reportData = Map<String, dynamic>.from(snapshot.value as Map);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              ReporterReportDetail(reportId: reportId, report: reportData),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'We could not open that report right now.',
        type: AppSnackBarType.error,
      );
    }
  }
}

class _MetaLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final IconData icon;
  final String label;

  const _SwipeActionBackground({
    required this.color,
    required this.alignment,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? AppSpacing.lg : 0,
        right: isLeft ? 0 : AppSpacing.lg,
      ),
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.large),
      child: Row(
        mainAxisAlignment: isLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (!isLeft) Text(label, style: const TextStyle(color: Colors.white)),
          if (!isLeft) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (isLeft) const SizedBox(width: 8),
          if (isLeft) Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeletonBox(height: 44, width: 44),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(height: 14, width: 140),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeletonBox(height: 12),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeletonBox(height: 12, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
