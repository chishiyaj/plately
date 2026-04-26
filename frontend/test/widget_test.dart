import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plately_v2/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlatelyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
