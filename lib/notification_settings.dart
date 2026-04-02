import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class NotificationSettings extends StatefulWidget {
  final User user;
  const NotificationSettings({super.key, required this.user});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final NotificationService _notificationService = NotificationService();
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
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
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          final filtered = _showUnreadOnly
              ? notifications.where((n) => !(n['read'] ?? false)).toList()
              : notifications;

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showUnreadOnly
                        ? 'No unread notifications'
                        : 'No notifications yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final notification = filtered[index];
              final isRead = notification['read'] ?? false;
              final timestamp = notification['timestamp'] ?? '';
              final timeStr = timestamp.isNotEmpty
                  ? DateTime.tryParse(timestamp)?.toString().substring(0, 16) ??
                      'Unknown time'
                  : 'Unknown time';

              return Dismissible(
                key: ValueKey(notification['id']),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  _notificationService.deleteNotification(
                    widget.user.uid,
                    notification['id'],
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications,
                      color: isRead ? Colors.grey : Colors.blue,
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notification['body'] ?? ''),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                    onTap: () {
                      if (!isRead) {
                        _notificationService.markNotificationAsRead(
                          widget.user.uid,
                          notification['id'],
                        );
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
