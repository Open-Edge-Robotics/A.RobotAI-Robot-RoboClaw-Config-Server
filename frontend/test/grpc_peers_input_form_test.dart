// frontend/test/grpc_peers_input_form_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/grpc_peers_input_form.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrpcPeersInputForm(controller: controller, isEditing: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('피어가 없으면 빈 상태를 표시한다', (tester) async {
    await pumpForm(tester, TextEditingController(text: '[]'));
    expect(find.text('등록된 동료 로봇이 없습니다.'), findsOneWidget);
  });

  testWidgets('피어 목록을 표시한다', (tester) async {
    await pumpForm(
      tester,
      TextEditingController(
        text: '[{"name":"robot_a","host":"192.168.1.100","port":50051}]',
      ),
    );
    expect(find.text('robot_a'), findsOneWidget);
  });

  testWidgets('잘못된 JSON 은 빈 상태로 처리한다', (tester) async {
    await pumpForm(tester, TextEditingController(text: '{bad'));
    expect(find.text('등록된 동료 로봇이 없습니다.'), findsOneWidget);
  });

  testWidgets('동료 로봇 추가 버튼으로 폼을 추가한다', (tester) async {
    final controller = TextEditingController(text: '[]');
    await pumpForm(tester, controller);

    await tester.tap(find.text('동료 로봇 추가'));
    await tester.pumpAndSettle();

    expect(find.text('로봇 이름'), findsWidgets);
  });
}
