// frontend/lib/widgets/config_card.dart

import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../utils/localization.dart';

class ConfigListItemCard extends StatelessWidget {
  final RoboClawConfig config;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  const ConfigListItemCard({
    super.key,
    required this.config,
    required this.isSelected,
    required this.onTap,
    required this.onActivate,
    required this.onClone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : config.isActive
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).dividerColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      config.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (config.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.secondary,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF82B1FF)
                              : Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.android,
                    size: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey
                        : const Color(0xFF334155),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    config.robotName,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey
                        : const Color(0xFF334155),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    config.environment,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              if (config.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  config.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey
                        : const Color(0xFF334155),
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!config.isActive)
                    TextButton(
                      onPressed: onActivate,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        '활성화'.tr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: onClone,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '복제'.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '삭제'.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
