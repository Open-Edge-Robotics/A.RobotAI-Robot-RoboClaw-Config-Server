import 'package:flutter/material.dart';
import '../utils/localization.dart';

class ConfigSectionHeader extends StatelessWidget {
  final String title;

  const ConfigSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Theme.of(context).dividerColor, height: 1),
      ],
    );
  }
}
