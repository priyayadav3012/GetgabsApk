import 'package:flutter_test/flutter_test.dart';
import 'package:getgabs/domain/services/whtasapp_calling_service.dart';

void main() {
  test('normalizeCallKitId returns a valid stable UUID for non-UUID strings',
      () {
    const rawId = 'incoming-call-123';

    final first = normalizeCallKitId(rawId);
    final second = normalizeCallKitId(rawId);

    expect(
        first,
        matches(RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')));
    expect(first, second);
  });

  test('normalizeCallKitId preserves valid UUID strings', () {
    const rawId = '123e4567-e89b-12d3-a456-426614174000';

    final normalized = normalizeCallKitId(rawId);

    expect(normalized, rawId.toLowerCase());
  });
}
