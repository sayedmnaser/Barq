import 'package:flutter_test/flutter_test.dart';
import 'package:barq/main.dart';
import 'package:barq/services/pocketbase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Barq app boots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await PocketBaseService.init();

    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
