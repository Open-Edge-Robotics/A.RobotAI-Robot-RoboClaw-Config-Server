// frontend/lib/widgets/config_list_panel.dart

import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../utils/localization.dart';
import 'config_card.dart';

class ConfigListPanel extends StatelessWidget {
  final List<RoboClawConfig> configs;
  final bool isLoading;
  final RoboClawConfig? selectedConfig;
  final ValueChanged<RoboClawConfig> onConfigSelected;
  final ValueChanged<int> onConfigActivated;
  final ValueChanged<int> onConfigCloned;
  final ValueChanged<int> onConfigDeleted;
  final ValueChanged<String> onSearchRobotChanged;
  final ValueChanged<String> onSearchEnvChanged;
  final VoidCallback onAddPressed;

  const ConfigListPanel({
    super.key,
    required this.configs,
    required this.isLoading,
    this.selectedConfig,
    required this.onConfigSelected,
    required this.onConfigActivated,
    required this.onConfigCloned,
    required this.onConfigDeleted,
    required this.onSearchRobotChanged,
    required this.onSearchEnvChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '설정 프로필 목록'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      '추가'.tr,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: '로봇명 검색'.tr,
                        prefixIcon: Icon(
                          Icons.android,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: onSearchRobotChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: '환경 검색'.tr,
                        prefixIcon: Icon(
                          Icons.location_on,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: onSearchEnvChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: Theme.of(context).dividerColor, height: 1),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : configs.isEmpty
              ? Center(
                  child: Text(
                    '등록된 설정이 없습니다.'.tr,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : const Color(0xFF334155),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: configs.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final config = configs[index];
                    final isSelected = selectedConfig?.id == config.id;
                    return ConfigListItemCard(
                      config: config,
                      isSelected: isSelected,
                      onTap: () => onConfigSelected(config),
                      onActivate: () => onConfigActivated(config.id!),
                      onClone: () => onConfigCloned(config.id!),
                      onDelete: () => onConfigDeleted(config.id!),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
