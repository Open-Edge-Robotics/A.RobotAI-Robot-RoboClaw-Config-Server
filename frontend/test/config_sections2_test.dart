// frontend/test/config_sections2_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/config_camera_section.dart';
import 'package:frontend/widgets/config_dashboard_section.dart';
import 'package:frontend/widgets/config_http_sec_section.dart';
import 'package:frontend/widgets/config_mcp_section.dart';
import 'package:frontend/widgets/config_messenger_section.dart';
import 'package:frontend/widgets/config_path_section.dart';
import 'package:frontend/widgets/config_task_queue_section.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('MCP 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigMcpSection(
        isEditing: true,
        enableMcp: true,
        onEnableMcpChanged: (_) {},
        mcpServersJsonCtrl: TextEditingController(),
      ),
    );
    expect(find.text('10. MCP(Model Context Protocol) 서버 연동'), findsOneWidget);
  });

  testWidgets('경로 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigPathSection(
        isEditing: true,
        agentWorkspaceDirCtrl: TextEditingController(),
        butlerScriptsDirCtrl: TextEditingController(),
        butlerSourceDirCtrl: TextEditingController(),
        configDirCtrl: TextEditingController(),
        systemPromptFileCtrl: TextEditingController(),
        robotDescriptionFileCtrl: TextEditingController(),
      ),
    );
    expect(find.text('6. 로컬 환경 경로 및 리소스 설정'), findsOneWidget);
  });

  testWidgets('카메라 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigCameraSection(
        isEditing: true,
        cameraTopicCtrl: TextEditingController(),
        useVision: false,
        onUseVisionChanged: (_) {},
        visionModelPathCtrl: TextEditingController(),
        gripperCameraTopicCtrl: TextEditingController(),
        gripperDepthTopicCtrl: TextEditingController(),
        gripperCameraInfoTopicCtrl: TextEditingController(),
        gripperPointcloudTopicCtrl: TextEditingController(),
        useGripperVision: false,
        onUseGripperVisionChanged: (_) {},
        gripperVisionMaxInferenceHzCtrl: TextEditingController(),
        lidarTopicCtrl: TextEditingController(),
        imuTopicCtrl: TextEditingController(),
      ),
    );
    expect(find.text('7. 카메라 / 비전 / 센서 설정'), findsOneWidget);
  });

  testWidgets('태스크 큐 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigTaskQueueSection(
        isEditing: true,
        taskQueueMaxSizeCtrl: TextEditingController(),
        llmFailFast: false,
        onLlmFailFastChanged: (_) {},
        strictConfig: false,
        onStrictConfigChanged: (_) {},
        enableTaskDecomposition: true,
        onEnableTaskDecompositionChanged: (_) {},
        taskDecompositionMaxStepsCtrl: TextEditingController(),
        taskStepMaxRetriesCtrl: TextEditingController(),
        taskDecompositionWaitMarginCapSecCtrl: TextEditingController(),
      ),
    );
    expect(find.text('11. 태스크 큐 / 복합 명령 자동 분해 설정'), findsOneWidget);
  });

  testWidgets('HTTP 보안 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigHttpSecSection(
        isEditing: true,
        httpHostCtrl: TextEditingController(),
        httpPortCtrl: TextEditingController(),
        httpReadonlyTokenCtrl: TextEditingController(),
        httpControlTokenCtrl: TextEditingController(),
        httpAllowedCidrsCtrl: TextEditingController(),
        httpRateLimitCtrl: TextEditingController(),
        httpAllowedSkillsCtrl: TextEditingController(),
        httpBlockedSkillsCtrl: TextEditingController(),
      ),
    );
    expect(find.text('5. HTTP API 보안 설정'), findsOneWidget);
  });

  testWidgets('Dashboard 웹 노드 섹션 헤더와 필드가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigDashboardSection(
        isEditing: true,
        dashboardHostCtrl: TextEditingController(),
        dashboardPortCtrl: TextEditingController(),
      ),
    );
    expect(find.text('Dashboard 웹 노드 설정'), findsOneWidget);
    expect(
      find.text('Dashboard 바인딩 호스트 (RC_DASHBOARD_HOST, 기본: 127.0.0.1)'),
      findsOneWidget,
    );
    expect(
      find.text('Dashboard 포트 (RC_DASHBOARD_PORT, 기본: 9090)'),
      findsOneWidget,
    );
  });

  testWidgets('메신저 섹션 헤더가 표시된다', (tester) async {
    await pump(
      tester,
      ConfigMessengerSection(
        isEditing: true,
        enableDiscord: false,
        enableSlack: false,
        enableTelegram: false,
        enableGrpc: true,
        useGrpc: false,
        enableGrpcClient: false,
        onDiscordChanged: (_) {},
        onSlackChanged: (_) {},
        onTelegramChanged: (_) {},
        onGrpcChanged: (_) {},
        onUseGrpcChanged: (_) {},
        onGrpcClientChanged: (_) {},
        discordTokenCtrl: TextEditingController(),
        slackAppTokenCtrl: TextEditingController(),
        slackBotTokenCtrl: TextEditingController(),
        telegramTokenCtrl: TextEditingController(),
        grpcTargetHostCtrl: TextEditingController(),
        grpcTargetPortCtrl: TextEditingController(),
        grpcTargetPeersJsonCtrl: TextEditingController(),
        grpcPeerTokenCtrl: TextEditingController(text: 'test-token'),
        grpcPortCtrl: TextEditingController(text: '50052'),
      ),
    );
    expect(find.text('4. 메신저 & 통신 데몬'), findsOneWidget);
    // GRPC_PEER_TOKEN 입력이 없으면 외부 채팅이 불가하므로 반드시 노출돼야 한다.
    expect(
      find.widgetWithText(
        TextFormField,
        'gRPC Peer Token (GRPC_PEER_TOKEN — 외부 접속 시 필수)',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        TextFormField,
        'gRPC Server Port (ROBO_CLAW_GRPC_PORT)',
      ),
      findsOneWidget,
    );
  });
}
