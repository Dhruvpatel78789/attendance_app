import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_system/main.dart';

void main() {
  testWidgets('builds the attendance app shell', (WidgetTester tester) async {
    const testHome = Scaffold(
      body: Center(child: Text('Attendance test home')),
    );

    await tester.pumpWidget(const MyApp(home: testHome));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'Attendance System');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.text('Attendance test home'), findsOneWidget);
  });
}
