import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/sync/sync_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      observers: kDebugMode ? [_ProviderLogger()] : [],
      child: const _SyncInitializer(),
    ),
  );
}

/// Initializes the sync engine after first build.
class _SyncInitializer extends ConsumerStatefulWidget {
  const _SyncInitializer();

  @override
  ConsumerState<_SyncInitializer> createState() => _SyncInitializerState();
}

class _SyncInitializerState extends ConsumerState<_SyncInitializer> {
  @override
  void initState() {
    super.initState();
    // Eagerly create the sync provider so it starts its timer.
    Future.microtask(() {
      ref.read(syncProvider);
    });
  }

  @override
  Widget build(BuildContext context) => const App();
}

/// Simple debug observer that prints provider changes.
class _ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<dynamic> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (kDebugMode) {
      debugPrint('[Provider] ${provider.name ?? provider.runtimeType} updated');
    }
  }
}
