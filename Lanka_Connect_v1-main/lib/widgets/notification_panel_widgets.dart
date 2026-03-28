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

  void _runAction(
    BuildContext context, {
    required String label,
    required VoidCallback? callback,
  }) {
    if (callback == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(label),
          duration: const Duration(milliseconds: 900),
        ),
      );
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Tooltip(
                message: 'Mark all read',
                child: IconButton(
                  onPressed: unreadCount == 0
                      ? null
                      : () => _runAction(
                          context,
                          label: 'Mark all read',
                          callback: onMarkAllRead,
                        ),
                  icon: const Icon(Icons.done_all),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    unreadCount == 0
                        ? 'All caught up'
                        : '$unreadCount unread notifications',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Clear all',
                child: IconButton(
                  onPressed: hasNotifications
                      ? () => _runAction(
                          context,
                          label: 'Clear all',
                          callback: onClearAll,
                        )
                      : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ),
            ],
          ),
        ),
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
