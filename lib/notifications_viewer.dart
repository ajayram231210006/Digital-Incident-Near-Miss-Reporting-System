import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

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
        backgroundColor: Colors.green,
        elevation: 2,
        actions: [
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
            notifications = notifications.where((n) => !(n['read'] ?? false)).toList();
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your supervisor will notify you when your reports are updated',
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
              final status = notification['status'];
              final supervisorName = notification['supervisorName'];

              // Parse timestamp
              DateTime notificationTime = DateTime.now();
              if (timestamp is String && timestamp.isNotEmpty) {
                try {
                  notificationTime = DateTime.parse(timestamp);
                } catch (e) {
                  // Keep current time
                }
              }

              final timeDiff = DateTime.now().difference(notificationTime);
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
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
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
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(status),
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
                          if (supervisorName != null && supervisorName is String)
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
                                    supervisorName,
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
                    onTap: !isRead
                      ? () {
                          _notificationService.markNotificationAsRead(
                            widget.user.uid,
                            notificationId,
                          );
                        }
                      : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeString(Duration diff) {
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins minute${mins > 1 ? 's' : ''} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days day${days > 1 ? 's' : ''} ago';
    } else {
      return 'A week ago';
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.blue;
    switch (status.toLowerCase()) {
      case 'closed':
        return Colors.green;
      case 'active':
        return Colors.orange;
      case 'open':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.info;
    switch (status.toLowerCase()) {
      case 'closed':
        return Icons.check_circle;
      case 'active':
        return Icons.schedule;
      case 'open':
        return Icons.mail;
      default:
        return Icons.notifications;
    }
  }
}
