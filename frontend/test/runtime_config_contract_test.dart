import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/config_model.dart';
import 'package:frontend/models/runtime_config_contract.g.dart';

void main() {
  test('RoboClawConfig serializes every generated runtime API field', () {
    final json = RoboClawConfig(
      name: 'contract',
      robotName: 'butler',
      environment: 'test',
    ).toJson();

    final missing = runtimeConfigFields.values
        .map((field) => field.apiJson)
        .where((field) => !json.containsKey(field))
        .toList();
    expect(
      missing,
      isEmpty,
      reason: 'Missing generated runtime fields: $missing',
    );
  });

  test('generated runtime contract exposes the current schema version', () {
    expect(runtimeConfigSchemaVersion, '2.0');
  });
}
