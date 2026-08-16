/// Widget tests for the Tools catalog screen (section 48).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/features/tools/tools_screen.dart';

Widget _app() {
  final router = GoRouter(
    initialLocation: '/tools',
    routes: [
      GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
      GoRoute(path: '/tools/:toolId', builder: (_, state) => const Scaffold()),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(
      theme: SiliphTheme.build(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('Tools shows title, search field and category chips', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Tools'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('PDF'), findsWidgets);
  });

  testWidgets('Tools search narrows the grid', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'signature');
    await tester.pumpAndSettle();

    expect(find.text('Signature Maker'), findsOneWidget);
    // Unrelated tools should not be shown for this query.
    expect(find.text('Storage Analyzer'), findsNothing);
  });

  testWidgets('Tools shows no-results empty state', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'qqqzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching tools'), findsOneWidget);
  });
}
