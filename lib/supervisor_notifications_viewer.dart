import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'notification_service.dart';
import 'supervisor_report_detail.dart';

class SupervisorNotificationsViewer extends StatefulWidget {
  final User user;
  const SupervisorNotificationsViewer({super.key, required this.user});

  @override
  State<SupervisorNotificationsViewer> createState() =>
      _SupervisorNotificationsViewerState();
}

class _SupervisorNotificationsViewerState
    extends State<SupervisorNotificationsViewer> {
  final NotificationService _notificationService = NotificationService();
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    // Auto-mark all unread notifications as read when viewer opens
    _notificationService.autoMarkUnreadNotificationsAsRead(widget.user.uid);
  }

  String _getTimeString(Duration difference) {
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getSeverityIcon(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return Icons.priority_high;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _openIncident(String reportId) async {
    try {
      // Fetch the incident details
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('incidents').child(reportId).get();
      
      if (snapshot.exists && mounted) {
        final reportData = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Navigate to report detail
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SupervisorReportDetail(
                reportId: reportId,
                report: reportData,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening incident: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening incident: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          // Mark All as Read Button
          StreamBuilder<int>(
            stream:
                _notificationService.getUnreadNotificationCount(widget.user.uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return unreadCount > 0
                  ? IconButton(
                      tooltip: 'Mark all as read',
                      icon: const Icon(Icons.done_all),
                      onPressed: () async {
                        await _notificationService
                            .markAllNotificationsAsRead(widget.user.uid);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('All notifications marked as read'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    )
                  : const Padding(padding: EdgeInsets.zero);
            },
          ),
          // Filter Chip
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: FilterChip(
                label: const Text('Unread Only'),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text('Error loading notifications: ${snapshot.error}'),
                ],
              ),
            );
          }

          List<Map<String, dynamic>> notifications = snapshot.data ?? [];

          if (_showUnreadOnly) {
            notifications =
                notifications.where((n) => !(n['read'] ?? false)).toList();
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showUnreadOnly
                        ? 'No unread notifications'
                        : 'No notifications yet',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will receive notifications when new reports are submitted',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['read'] ?? false;
              final notificationId = notification['id'];
              final title = notification['title'];
              final body = notification['body'];
              final timestamp = notification['timestamp'];
              final severity = notification['severity'];
              final reporterName = notification['reporterName'];
              final reportId = notification['reportId'];

              // Parse timestamp
              DateTime notificationTime = DateTime.now();
              if (timestamp is String && timestamp.isNotEmpty) {
                try {
                  notificationTime = DateTime.parse(timestamp);
                } catch (e) {
                  // Keep current time
                }
              }

              final timeDiff =
                  DateTime.now().difference(notificationTime);
              String timeString = _getTimeString(timeDiff);

              return Dismissible(
                key: Key(notificationId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red.shade400,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _notificationService.deleteNotification(
                    widget.user.uid,
                    notificationId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification deleted')),
                    );
                  }
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  elevation: isRead ? 0 : 2,
                  color: isRead ? Colors.grey.shade50 : Colors.blue.shade50,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(severity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getSeverityIcon(severity),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (reporterName != null && reporterName is String)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    reporterName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    onTap: () {
                      // Mark as read
                      if (!isRead) {
                        _notificationService.markNotificationAsRead(
                          widget.user.uid,
                          notificationId,
                        );
                        setState(() {});
                      }

                      // Open the incident if reportId exists
                      if (reportId != null && reportId.isNotEmpty) {
                        _openIncident(reportId);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
