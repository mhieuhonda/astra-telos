import 'package:astra_telos/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Astra Telos khoi dong', (tester) async {
    await tester.pumpWidget(const AstraTelos());
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('ASTRA TELOS'), findsWidgets);
  });
}
