import 'dart:convert';

import '../../models/runtime_config_contract.g.dart';

List<String> validateRuntimeConfigJson(Map<String, dynamic> json) {
  final errors = <String>[];
  for (final field in runtimeConfigFields.values) {
    final value = json[field.apiJson];
    if (value == null) continue;
    if (value is String && value.isEmpty) continue;
    var normalized = value;
    if ((field.type == 'array' || field.type == 'object') && value is String) {
      try {
        normalized = jsonDecode(value);
      } catch (_) {
        errors.add('${field.apiJson} must contain valid JSON');
        continue;
      }
    }
    if (!_matchesType(field.type, normalized)) {
      errors.add('${field.apiJson} must be ${field.type}');
      continue;
    }
    if (field.enumValues.isNotEmpty && !field.enumValues.contains(normalized)) {
      errors.add('${field.apiJson} must be one of ${field.enumValues}');
    }
    if (normalized is num) {
      if (field.minimum != null && normalized < field.minimum!) {
        errors.add('${field.apiJson} must be >= ${field.minimum}');
      }
      if (field.maximum != null && normalized > field.maximum!) {
        errors.add('${field.apiJson} must be <= ${field.maximum}');
      }
    }
  }
  return errors;
}

bool _matchesType(String type, Object value) {
  switch (type) {
    case 'boolean':
      return value is bool;
    case 'integer':
      return value is int;
    case 'number':
      return value is num;
    case 'array':
      return value is List;
    case 'object':
      return value is Map;
    case 'string':
    case 'path':
      return value is String;
    default:
      return false;
  }
}
