import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userId = auth.user?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.black,
        ),
        body: const Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: () async {
              try {
                await _notificationService.markAllAsRead(userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => _showClearAllDialog(userId),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!, Colors.black],
          ),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _notificationService.getUserNotifications(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading notifications: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: TextStyle(color: Colors.grey[300], fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isRead = notification['read'] ?? false;
                final createdAt = notification['createdAt']?.toDate() ?? DateTime.now();
                final title = notification['title'] ?? 'Notification';
                final body = notification['body'] ?? '';

                return Card(
                  color: isRead ? Colors.grey[850] : Colors.grey[800],
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey : Colors.blue,
                      child: Icon(
                        _getNotificationIcon(notification['data']),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[100],
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      color: Colors.grey[800],
                      onSelected: (value) async {
                        switch (value) {
                          case 'mark_read':
                            if (!isRead) {
                              await _notificationService.markAsRead(notification['id']);
                            }
                            break;
                          case 'delete':
                            await _notificationService.deleteNotification(notification['id']);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isRead)
                          const PopupMenuItem(
                            value: 'mark_read',
                            child: Row(
                              children: [
                                Icon(Icons.mark_email_read, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Mark as read', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      if (!isRead) {
                        await _notificationService.markAsRead(notification['id']);
                      }
                      // Handle notification tap based on type
                      _handleNotificationTap(notification);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getNotificationIcon(Map<String, dynamic>? data) {
    if (data == null) return Icons.notifications;
    
    final type = data['type'] as String?;
    switch (type) {
      case 'visitor_approval':
        return Icons.person_add;
      case 'visitor_status':
        return Icons.check_circle;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final type = data['type'] as String?;
    switch (type) {
      case 'visitor_approval':
        // Navigate to visitor approval screen
        break;
      case 'visitor_status':
        // Navigate to visitor details
        break;
      default:
        break;
    }
  }

  void _showClearAllDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Clear All Notifications', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _notificationService.clearAllNotifications(userId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications cleared')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
