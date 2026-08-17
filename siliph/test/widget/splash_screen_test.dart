import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:siliph/app/router.dart';
import 'package:siliph/features/settings/settings_provider.dart';
import 'package:siliph/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays brand and subtitle',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: SiliphRoutes.splash,
      routes: [
        GoRoute(
          path: SiliphRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: SiliphRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Initial frame
    expect(find.text('Siliph'), findsOneWidget);
    expect(find.text('PDF & File Tools'), findsOneWidget);
    expect(find.text('Private. Fast. On your device.'), findsOneWidget);

    // Animate forward and complete navigation
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Siliph'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('SplashScreen respects reduced motion setting',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    container.read(settingsProvider.notifier).setReducedMotion(true);

    final router = GoRouter(
      initialLocation: SiliphRoutes.splash,
      routes: [
        GoRoute(
          path: SiliphRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: SiliphRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Siliph'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Home Screen'), findsOneWidget);
  });
}
