import 'package:material_ui/material_ui.dart';

import '../utils/localization.dart';

class ConfigFormGroup {
  final String title;
  final IconData icon;
  final List<Widget> sections;

  const ConfigFormGroup({
    required this.title,
    required this.icon,
    required this.sections,
  });
}

class ConfigGroupNavigator extends StatefulWidget {
  final List<ConfigFormGroup> groups;

  const ConfigGroupNavigator({super.key, required this.groups});

  @override
  State<ConfigGroupNavigator> createState() => _ConfigGroupNavigatorState();
}

class _ConfigGroupNavigatorState extends State<ConfigGroupNavigator> {
  late final _groupKeys = List.generate(
    widget.groups.length,
    (_) => GlobalKey(),
  );

  Future<void> _scrollToGroup(int index) async {
    final targetContext = _groupKeys[index].currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < widget.groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: ActionChip(
                        label: Text('${i + 1}. ${widget.groups[i].title.tr}'),
                        onPressed: () => _scrollToGroup(i),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.groups.length; i++) ...[
                  _ConfigFormGroupCard(
                    key: _groupKeys[i],
                    group: widget.groups[i],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfigFormGroupCard extends StatelessWidget {
  final ConfigFormGroup group;

  const _ConfigFormGroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(group.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.title.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 16),
            for (var i = 0; i < group.sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 24),
              group.sections[i],
            ],
          ],
        ),
      ),
    );
  }
}
