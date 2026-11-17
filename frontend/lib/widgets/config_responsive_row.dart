import 'package:material_ui/material_ui.dart';

/// Lays out related form fields in a row when there is room and stacks them
/// vertically on narrow screens.
class ConfigResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double breakpoint;

  const ConfigResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.breakpoint = 680,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
