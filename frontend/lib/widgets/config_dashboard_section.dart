import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

/// Dashboard 웹 노드(RC_DASHBOARD_HOST / RC_DASHBOARD_PORT) 설정 섹션.
/// HTTP API 채널(8080)과는 별개의 바인딩 주소/포트를 지정한다.
class ConfigDashboardSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController dashboardHostCtrl;
  final TextEditingController dashboardPortCtrl;

  const ConfigDashboardSection({
    super.key,
    required this.isEditing,
    required this.dashboardHostCtrl,
    required this.dashboardPortCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('Dashboard 웹 노드 설정'),
        const SizedBox(height: 12),
        Text(
          'HTTP API 채널 포트(8080)와 별개로 동작하는 Dashboard 웹 노드 주소입니다.'.tr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: dashboardHostCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText:
                      'Dashboard 바인딩 호스트 (RC_DASHBOARD_HOST, 기본: 127.0.0.1)'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: dashboardPortCtrl,
                enabled: isEditing,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Dashboard 포트 (RC_DASHBOARD_PORT, 기본: 9090)'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
