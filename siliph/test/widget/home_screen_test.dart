/// Widget tests for the Home screen (sections 47, 114).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:siliph/app/theme/siliph_theme.dart';
import 'package:siliph/features/home/home_screen.dart';
import 'package:siliph/features/tools/tools_screen.dart';

Widget _app(Widget home) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => home),
      GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
      GoRoute(path: '/tools/:toolId', builder: (_, state) => const Scaffold()),
      GoRoute(path: '/settings', builder: (_, _) => const Scaffold()),
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
  testWidgets('Home shows hero, search field and quick actions', (tester) async {
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Siliph'), findsOneWidget);
    expect(find.text('All-in-one File Tools'), findsOneWidget);
    expect(find.text('Private. Fast. On your device.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    // Recent section sits below the fold in the 800x600 test viewport.
    await tester.dragUntilVisible(
      find.text('Recent files'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('Recent files'), findsOneWidget);
  });

  testWidgets('Home search filters tools live', (tester) async {
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'compress');
    await tester.pumpAndSettle();

    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Compress Image'), findsOneWidget);
  });

  testWidgets('Home recent empty state offers actions', (tester) async {
    await tester.pumpWidget(_app(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Start with a file'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    expect(find.text('Start with a file'), findsOneWidget);
    expect(find.text('Scan'), findsWidgets);
  });
}
