// frontend/test/config_fleet_section_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/widgets/config_fleet_section.dart';

void main() {
  Widget buildSection({bool isEditing = true, String policy = 'complete'}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfigFleetSection(
            isEditing: isEditing,
            maestroIpCtrl: TextEditingController(text: '10.0.0.5'),
            robotPortCtrl: TextEditingController(text: '50053'),
            robotIdCtrl: TextEditingController(text: 'butler-01'),
            robotSiteIdCtrl: TextEditingController(text: 'site-a'),
            robotMapIdCtrl: TextEditingController(text: '1f'),
            robotMapVersionCtrl: TextEditingController(text: 'v3'),
            robotMapFrameIdCtrl: TextEditingController(text: 'map'),
            disconnectPolicy: policy,
            onDisconnectPolicyChanged: (_) {},
            heartbeatSecCtrl: TextEditingController(text: '1.0'),
            commandJournalPathCtrl: TextEditingController(
              text: '/tmp/robo_claw_fleet_commands.sqlite3',
            ),
            skillsGuideFileCtrl: TextEditingController(text: ''),
            controlTls: true,
            onControlTlsChanged: (_) {},
            controlCaCertCtrl: TextEditingController(text: '/etc/robo/ca.pem'),
            controlClientCertCtrl: TextEditingController(
              text: '/etc/robo/client.pem',
            ),
            controlClientKeyCtrl: TextEditingController(
              text: '/etc/robo/client.key',
            ),
          ),
        ),
      ),
    );
  }

  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Fleet 섹션 헤더와 contract env 라벨이 표시된다', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(find.text('Maestro FleetControl 연동'), findsOneWidget);
    expect(find.text('Maestro 서버 IP (MAESTRO_IP)'), findsOneWidget);
    expect(find.text('로봇 ID (ROBOT_ID)'), findsOneWidget);
    expect(find.text('클라이언트 키 (FLEET_CONTROL_CLIENT_KEY)'), findsOneWidget);
  });

  testWidgets('편집 중이 아니면 입력 필드가 비활성화된다', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(buildSection(isEditing: false));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Maestro 서버 IP (MAESTRO_IP)'),
    );
    expect(field.enabled, isFalse);
  });

  test('RoboClawConfig가 fleet contract 필드를 JSON 직렬화에서 보존한다', () {
    final config = RoboClawConfig(
      name: 'fleet',
      robotName: 'butler',
      environment: 'office',
      maestroIp: '10.0.0.5',
      robotPort: 50053,
      robotId: 'butler-01',
      robotSiteId: 'site-a',
      robotMapId: '1f',
      robotMapVersion: 'v3',
      robotMapFrameId: 'map',
      maestroDisconnectPolicy: 'finish_atomic',
      fleetHeartbeatSec: 2.5,
      fleetCommandJournalPath: '/var/lib/fleet.sqlite3',
      fleetSkillsGuideFile: '/etc/robo/skills.md',
      fleetControlTls: true,
      fleetControlCaCert: '/etc/robo/ca.pem',
      fleetControlClientCert: '/etc/robo/client.pem',
      fleetControlClientKey: '/etc/robo/client.key',
    );

    final decoded = RoboClawConfig.fromJson(config.toJson());

    expect(decoded.maestroIp, '10.0.0.5');
    expect(decoded.robotPort, 50053);
    expect(decoded.robotId, 'butler-01');
    expect(decoded.robotSiteId, 'site-a');
    expect(decoded.robotMapId, '1f');
    expect(decoded.robotMapVersion, 'v3');
    expect(decoded.robotMapFrameId, 'map');
    expect(decoded.maestroDisconnectPolicy, 'finish_atomic');
    expect(decoded.fleetHeartbeatSec, 2.5);
    expect(decoded.fleetCommandJournalPath, '/var/lib/fleet.sqlite3');
    expect(decoded.fleetSkillsGuideFile, '/etc/robo/skills.md');
    expect(decoded.fleetControlTls, isTrue);
    expect(decoded.fleetControlCaCert, '/etc/robo/ca.pem');
    expect(decoded.fleetControlClientCert, '/etc/robo/client.pem');
    expect(decoded.fleetControlClientKey, '/etc/robo/client.key');
  });

  test('RoboClawConfig fleet 기본값이 contract 기본값과 일치한다', () {
    final config = RoboClawConfig(
      name: 'd',
      robotName: 'butler',
      environment: 'e',
    );

    expect(config.robotPort, 50053);
    expect(config.robotMapFrameId, 'map');
    expect(config.maestroDisconnectPolicy, 'complete');
    expect(config.fleetHeartbeatSec, 1.0);
    expect(
      config.fleetCommandJournalPath,
      '/tmp/robo_claw_fleet_commands.sqlite3',
    );
    expect(config.fleetControlTls, isFalse);
  });
}
