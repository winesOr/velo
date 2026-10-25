/// A completed batch whose individual rejected writes are still observable.
/// Values and native diagnostic text are deliberately excluded from errors.
class PlayerPropertyBatchException implements Exception {
  PlayerPropertyBatchException(Map<String, Object> failures) : failures = Map.unmodifiable(failures);

  final Map<String, Object> failures;

  @override
  String toString() => 'Player properties rejected: ${failures.keys.join(', ')}';
}
