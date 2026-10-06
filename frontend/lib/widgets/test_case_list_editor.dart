// frontend/lib/widgets/test_case_list_editor.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scenario_model.dart';
import '../utils/localization.dart';
import 'test_case_params_editor.dart';
import 'test_case_templates.dart';

class TestCaseListEditor extends StatefulWidget {
  final List<TestCase> testCases;
  final ValueChanged<List<TestCase>> onChanged;
  final bool isEditing;

  const TestCaseListEditor({
    super.key,
    required this.testCases,
    required this.onChanged,
    required this.isEditing,
  });

  @override
  State<TestCaseListEditor> createState() => _TestCaseListEditorState();
}

class _TestCaseListEditorState extends State<TestCaseListEditor> {
  // 접혀있는(collapsed) 카드들의 인덱스를 관리하는 Set
  final Set<String> _collapsedIds = {};

  @override
  Widget build(BuildContext context) {
    if (widget.testCases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                '정의된 테스트 케이스가 없습니다.'.tr,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (widget.isEditing) _buildAddTemplateButtonsDropdown(),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isEditing) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '※ 항목 왼쪽의 아이콘을 드래그하여 순서를 변경할 수 있습니다.'.tr,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : const Color(0xFF334155),
                  fontSize: 14,
                ),
              ),
              _buildAddTemplateButtonsDropdown(),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.transparent, // 드래그 시 배경 투명화
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.testCases.length,
            onReorderItem: _handleReorderItem,
            itemBuilder: (context, index) {
              final testCase = widget.testCases[index];
              final key = ValueKey(
                testCase.id.isNotEmpty ? testCase.id : 'index_$index',
              );
              return _buildTestCaseCard(testCase, index, key);
            },
          ),
        ),
      ],
    );
  }

  // 순서 드래그 앤 드롭 핸들링
  void _handleReorderItem(int oldIndex, int newIndex) {
    if (!widget.isEditing) return;
    setState(() {
      final List<TestCase> newList = List.from(widget.testCases);
      final item = newList.removeAt(oldIndex);
      newList.insert(newIndex, item);
      widget.onChanged(newList);
    });
  }

  // 템플릿 생성 드롭다운/팝업 메뉴 버튼
  Widget _buildAddTemplateButtonsDropdown() {
    return PopupMenuButton<String>(
      tooltip: '템플릿 테스트 케이스 추가'.tr,
      onSelected: _addTestCaseFromTemplate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '테스트 케이스 추가'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => testCaseTypeDescriptions.entries.map((entry) {
        return PopupMenuItem<String>(
          value: entry.key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                entry.value.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 템플릿 항목 추가 구현
  void _addTestCaseFromTemplate(String type) {
    final suffix = widget.testCases.length + 1;
    final newCase = createTestCaseTemplate(type, suffix);

    final newList = List<TestCase>.from(widget.testCases)..add(newCase);
    widget.onChanged(newList);
  }

  // 개별 테스트케이스 카드 UI 구성
  Widget _buildTestCaseCard(TestCase testCase, int index, Key key) {
    final isCollapsed = _collapsedIds.contains(testCase.id);
    final cardColor = testCase.enabled
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF252525)
              : const Color(0xFFF1F5F9))
        : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E).withValues(alpha: 0.6)
              : Colors.grey.shade200);
    final borderColor = testCase.enabled
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFE2E8F0))
        : Theme.of(context).dividerColor;

    return Card(
      key: key,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: testCase.enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : borderColor,
          width: testCase.enabled ? 1.0 : 0.8,
        ),
      ),
      child: Column(
        children: [
          // 1. 카드 헤더 부분 (한 줄로 간략 표시)
          ListTile(
            dense: true,
            leading: widget.isEditing
                ? ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  )
                : Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : const Color(0xFF334155),
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testCase.name.isNotEmpty ? testCase.name : '(이름 없음)'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: testCase.enabled
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF0F172A))
                          : Colors.grey,
                      decoration: testCase.enabled
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypeChip(testCase.type),
              ],
            ),
            subtitle: Text(
              'ID: ${testCase.id} | Step: ${testCase.step}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : const Color(0xFF334155),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 활성화 토글 스위치
                Switch(
                  value: testCase.enabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: widget.isEditing
                      ? (val) {
                          _updateTestCase(index, testCase..enabled = val);
                        }
                      : null,
                ),
                // 접기 / 펼치기 버튼
                IconButton(
                  icon: Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isCollapsed) {
                        _collapsedIds.remove(testCase.id);
                      } else {
                        _collapsedIds.add(testCase.id);
                      }
                    });
                  },
                ),
                // 삭제 버튼
                if (widget.isEditing)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _removeTestCase(index),
                  ),
              ],
            ),
          ),

          // 2. 카드 바디 부분 (상세 입력창 - 펼쳐졌을 때만 렌더링)
          if (!isCollapsed) ...[
            const Divider(color: Color(0xFF3A3A3A), height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기본 스펙 입력 그리드
                  _buildBasicFieldsGrid(testCase, index),
                  const SizedBox(height: 16),

                  // 파라미터(params) 입력 폼 섹션
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '테스트 매개변수 (Params)'.tr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black12
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: TestCaseParamsEditor(
                      testCase: testCase,
                      isEditing: widget.isEditing,
                      onChanged: (updated) => _updateTestCase(index, updated),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Type Chip 위젯
  Widget _buildTypeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 0.8,
        ),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 기본 정보 필드 입력 폼 (ID, Name, Step, Timeout, Type)
  Widget _buildBasicFieldsGrid(TestCase testCase, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // 화면 크기에 맞게 2열 또는 1열 배치
        final int crossAxisCount = width > 600 ? 2 : 1;

        Widget col1 = Column(
          children: [
            _buildTextFormField(
              labelText: '테스트 ID *'.tr,
              initialValue: testCase.id,
              enabled: widget.isEditing,
              onChanged: (val) {
                // ID 수정 시 collapsed Set의 키도 매칭 필요
                final oldId = testCase.id;
                testCase.id = val;
                if (_collapsedIds.contains(oldId)) {
                  _collapsedIds.remove(oldId);
                  _collapsedIds.add(val);
                }
                _updateTestCase(index, testCase);
              },
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              labelText: '테스트 이름 *'.tr,
              initialValue: testCase.name,
              enabled: widget.isEditing,
              onChanged: (val) {
                _updateTestCase(index, testCase..name = val);
              },
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              labelText: '수행 단계 (Step) *'.tr,
              initialValue: testCase.step,
              enabled: widget.isEditing,
              onChanged: (val) {
                _updateTestCase(index, testCase..step = val);
              },
            ),
          ],
        );

        Widget col2 = Column(
          children: [
            // Type Dropdown 선택창
            DropdownButtonFormField<String>(
              initialValue: testCaseTypeDescriptions.containsKey(testCase.type)
                  ? testCase.type
                  : 'custom',
              decoration: InputDecoration(
                labelText: '테스트 유형 (Type) *'.tr,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.white,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
              ),
              items: testCaseTypeDescriptions.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    '${entry.key} (${entry.value.tr.split(" ").first})',
                  ),
                );
              }).toList(),
              onChanged: widget.isEditing
                  ? (val) {
                      if (val != null) {
                        // 유형이 바뀌면 params도 초기화하거나 템플릿 값으로 채워줌
                        final Map<String, dynamic> newParams =
                            defaultParamsForTestCaseType(val);
                        _updateTestCase(
                          index,
                          testCase
                            ..type = val
                            ..params = newParams,
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _buildTextFormField(
              labelText: '타임아웃 (ms) *'.tr,
              initialValue: testCase.timeoutMs.toString(),
              enabled: widget.isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (val) {
                final intVal = int.tryParse(val) ?? 5000;
                _updateTestCase(index, testCase..timeoutMs = intVal);
              },
            ),
          ],
        );

        if (crossAxisCount == 2) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: col1),
              const SizedBox(width: 16),
              Expanded(child: col2),
            ],
          );
        } else {
          return Column(children: [col1, const SizedBox(height: 12), col2]);
        }
      },
    );
  }

  // 텍스트 폼 필드 헬퍼 위젯
  Widget _buildTextFormField({
    required String labelText,
    required String initialValue,
    required bool enabled,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      initialValue: initialValue,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  // 상태 업데이트 및 알림
  void _updateTestCase(int index, TestCase updated) {
    final List<TestCase> newList = List.from(widget.testCases);
    newList[index] = updated;
    widget.onChanged(newList);
  }

  // 항목 삭제
  void _removeTestCase(int index) {
    final deletedItem = widget.testCases[index];
    setState(() {
      _collapsedIds.remove(deletedItem.id);
      final List<TestCase> newList = List.from(widget.testCases)
        ..removeAt(index);
      widget.onChanged(newList);
    });
  }
}
