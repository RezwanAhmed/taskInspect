import 'package:flutter/material.dart';

/// One number on the dashboard, e.g. "In progress: 2".
class CountTile extends StatelessWidget {
  const CountTile({
    required this.label,
    required this.count,
    required this.color,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final Color color;
  final IconData? icon;

  /// Opens the matching tasks.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                '$count',
                style: theme.textTheme.headlineMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
