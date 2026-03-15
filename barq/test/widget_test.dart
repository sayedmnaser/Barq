import 'package:flutter_test/flutter_test.dart';
import 'package:barq/main.dart';

void main() {
  testWidgets('Barq app boots', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
