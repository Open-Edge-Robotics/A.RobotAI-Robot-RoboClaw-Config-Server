import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/configs/runtime_config_validator.dart';

void main() {
  test('validates enum and numeric range from generated contract', () {
    expect(
      validateRuntimeConfigJson({
        'llm_provider': 'invalid',
        'ros_domain_id': 300,
      }),
      isNotEmpty,
    );
  });

  test('accepts a valid runtime configuration subset', () {
    expect(
      validateRuntimeConfigJson({
        'llm_provider': 'ollama',
        'ros_domain_id': 10,
        'http_port': 8080,
        'grpc_port': 50052,
      }),
      isEmpty,
    );
  });

  test('rejects incorrect field types', () {
    final errors = validateRuntimeConfigJson({'http_port': '8080'});
    expect(errors, contains('http_port must be integer'));
  });

  test('validates System 1 settings from generated contract', () {
    expect(
      validateRuntimeConfigJson({
        'system1_router': 'laya',
        'system1_shadow': true,
        'system1_shadow_log': '/tmp/system1.jsonl',
        'system1_scope': 'navigation',
        'system1_endpoint': 'http://laya:8000',
        'system1_provider': 'laya',
        'system1_timeout_ms': 300.0,
        'system1_conf_thresholds_json': '{"skill":0.8}',
        'system1_skills': 'get_status,identify_location',
        'system1_max_options': 12,
        'system1_api_key': 'masked-or-secret',
      }),
      isEmpty,
    );
    expect(
      validateRuntimeConfigJson({
        'system1_router': 'invalid',
        'system1_scope': 'unsafe',
        'system1_timeout_ms': 0,
        'system1_conf_thresholds_json': '[1,2]',
        'system1_max_options': 1,
      }),
      isNotEmpty,
    );
  });

  test('validates dashboard node fields from generated contract', () {
    expect(
      validateRuntimeConfigJson({
        'dashboard_host': '127.0.0.1',
        'dashboard_port': 9090,
      }),
      isEmpty,
    );
    expect(
      validateRuntimeConfigJson({'dashboard_port': 70000}),
      contains('dashboard_port must be <= 65535'),
    );
    expect(
      validateRuntimeConfigJson({'dashboard_port': 0}),
      contains('dashboard_port must be >= 1'),
    );
  });
}
