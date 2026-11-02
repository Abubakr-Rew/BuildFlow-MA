/// Parsers for RPC answers: a JSON object or a list of them.
library;

/// `json` as one object of `fromJson`.
T Function(Object? json) one<T>(T Function(Map<String, dynamic>) fromJson) =>
    (json) => fromJson(json! as Map<String, dynamic>);

/// `json` as a list of `fromJson` objects.
List<T> Function(Object? json) listOf<T>(
  T Function(Map<String, dynamic>) fromJson,
) =>
    (json) => [
          for (final item in json! as List<dynamic>)
            fromJson(item as Map<String, dynamic>),
        ];
