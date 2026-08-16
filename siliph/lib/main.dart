import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'domain/providers.dart';
import 'domain/services/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Attach the native -> Flutter event router before any gateway can be
  // used (section 5 bridge contract).
  final bridgeRouter = BridgeEventRouter()..attach();
  runApp(
    ProviderScope(
      overrides: [bridgeEventRouterProvider.overrideWithValue(bridgeRouter)],
      child: const SiliphApp(),
    ),
  );
}
