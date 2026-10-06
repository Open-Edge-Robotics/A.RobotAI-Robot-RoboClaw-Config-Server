// frontend/lib/models/scenario_model.dart

class TestCase {
  String id;
  String name;
  String step;
  String type;
  int timeoutMs;
  bool enabled;
  Map<String, dynamic> params;

  TestCase({
    required this.id,
    required this.name,
    required this.step,
    required this.type,
    this.timeoutMs = 5000,
    this.enabled = true,
    this.params = const {},
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      step: json['step'] ?? '',
      type: json['type'] ?? '',
      timeoutMs: json['timeout_ms'] ?? 5000,
      enabled: json['enabled'] ?? true,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'])
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'step': step,
      'type': type,
      'timeout_ms': timeoutMs,
      'enabled': enabled,
      if (params.isNotEmpty) 'params': params,
    };
  }

  TestCase clone() {
    return TestCase.fromJson(toJson());
  }
}

class TestScenario {
  final int? id;
  String name;
  String description;
  String robotName;
  String environment;
  bool isActive;
  List<TestCase> testCases;

  TestScenario({
    this.id,
    required this.name,
    this.description = '',
    required this.robotName,
    required this.environment,
    this.isActive = false,
    required this.testCases,
  });

  factory TestScenario.fromJson(Map<String, dynamic> json) {
    var list = json['test_cases'] as List?;
    List<TestCase> testCasesList = list != null
        ? list
              .map((i) => TestCase.fromJson(Map<String, dynamic>.from(i)))
              .toList()
        : [];

    return TestScenario(
      id: json['ID'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      robotName: json['robot_name'] ?? '',
      environment: json['environment'] ?? '',
      isActive: json['is_active'] ?? false,
      testCases: testCasesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'ID': id,
      'name': name,
      'description': description,
      'robot_name': robotName,
      'environment': environment,
      'is_active': isActive,
      'test_cases': testCases.map((tc) => tc.toJson()).toList(),
    };
  }

  TestScenario clone() {
    return TestScenario.fromJson(toJson());
  }
}
