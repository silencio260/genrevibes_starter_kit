import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  group('KitResult', () {
    test('maps successful values', () {
      const result = KitSuccess<int>(2);

      final mapped = result.map((value) => value * 3);

      expect(mapped.isSuccess, isTrue);
      expect(
        mapped.fold(onSuccess: (value) => value, onFailure: (_) => -1),
        6,
      );
    });

    test('preserves failures when mapping', () {
      const error = KitError(
        code: KitErrorCode.network,
        message: 'offline',
      );
      const result = KitFailure<int>(error);

      final mapped = result.map((value) => value * 3);

      expect(mapped.isFailure, isTrue);
      expect(
        mapped.fold(onSuccess: (_) => null, onFailure: (value) => value),
        same(error),
      );
    });
  });
}
