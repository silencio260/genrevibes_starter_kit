import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_smoke_app/main.dart';

void main() {
  testWidgets('lists every native adapter', (tester) async {
    await tester.pumpWidget(const SmokeApp());

    expect(find.text('GenRevibes native smoke app'), findsOneWidget);
    expect(adapterTypes, hasLength(21));
  });
}
