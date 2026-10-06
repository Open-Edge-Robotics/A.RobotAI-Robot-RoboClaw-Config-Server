// frontend/lib/widgets/scenario_list_panel.dart

import 'package:flutter/material.dart';
import '../models/scenario_model.dart';
import '../utils/localization.dart';
import 'scenario_card.dart';

class ScenarioListPanel extends StatelessWidget {
  final List<TestScenario> scenarios;
  final bool isLoadingScenarios;
  final TestScenario? selectedScenario;
  final ValueChanged<TestScenario> onScenarioSelected;
  final ValueChanged<int> onScenarioActivated;
  final ValueChanged<int> onScenarioCloned;
  final ValueChanged<int> onScenarioDeleted;
  final ValueChanged<String> onSearchRobotChanged;
  final ValueChanged<String> onSearchEnvChanged;
  final VoidCallback onAddPressed;

  const ScenarioListPanel({
    super.key,
    required this.scenarios,
    required this.isLoadingScenarios,
    this.selectedScenario,
    required this.onScenarioSelected,
    required this.onScenarioActivated,
    required this.onScenarioCloned,
    required this.onScenarioDeleted,
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
                    '테스트 시나리오 목록'.tr,
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
          child: isLoadingScenarios
              ? const Center(child: CircularProgressIndicator())
              : scenarios.isEmpty
              ? Center(
                  child: Text(
                    '등록된 시나리오가 없습니다.'.tr,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : const Color(0xFF334155),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: scenarios.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final sc = scenarios[index];
                    final isSelected = selectedScenario?.id == sc.id;
                    return ScenarioListItemCard(
                      scenario: sc,
                      isSelected: isSelected,
                      onTap: () => onScenarioSelected(sc),
                      onActivate: () => onScenarioActivated(sc.id!),
                      onClone: () => onScenarioCloned(sc.id!),
                      onDelete: () => onScenarioDeleted(sc.id!),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
