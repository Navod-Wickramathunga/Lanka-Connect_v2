import 'package:flutter/material.dart';

class NotificationToolbar extends StatelessWidget {
  const NotificationToolbar({
    super.key,
    required this.unreadCount,
    required this.hasNotifications,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final int unreadCount;
  final bool hasNotifications;
  final VoidCallback? onMarkAllRead;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Chip(label: Text('Unread: $unreadCount')),
          OutlinedButton.icon(
            onPressed: unreadCount == 0 ? null : onMarkAllRead,
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
          OutlinedButton.icon(
            onPressed: hasNotifications ? onClearAll : null,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.timeLabel,
    required this.isRead,
    required this.onOpen,
    required this.onViewDetails,
    required this.onRemove,
  });

  final String title;
  final String body;
  final String type;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onOpen;
  final VoidCallback onViewDetails;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onOpen,
      leading: Icon(
        isRead ? Icons.notifications_none : Icons.notifications_active,
        color: isRead ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurface),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                type,
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (timeLabel.trim().isNotEmpty)
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'view') {
            onViewDetails();
            return;
          }
          if (value == 'delete') {
            onRemove();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'view', child: Text('View details')),
          PopupMenuItem(value: 'delete', child: Text('Remove')),
        ],
      ),
    );
  }
}
