import 'package:flutter/material.dart';

import 'art/shells.dart';
import 'game/game_controller.dart';
import 'ui/kit.dart';
import 'ui/onboarding_screen.dart';
import 'ui/room_screen.dart';

/// Dismisses the keyboard on every navigation change.
class KeyboardObserver extends NavigatorObserver {
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _unfocus();
}

class EgglingApp extends StatefulWidget {
  const EgglingApp({super.key, required this.controller});

  final GameController controller;

  @override
  State<EgglingApp> createState() => _EgglingAppState();
}

class _EgglingAppState extends State<EgglingApp> with WidgetsBindingObserver {
  Shell? _draftShell;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Widgets open eggling://open/feed and similar. No extra native code.
  void _openLink(String? path) {
    final parts = Uri.tryParse(path ?? '')?.pathSegments ?? const <String>[];
    if (parts.isNotEmpty && parts.last != 'room') c.setRoute(parts.last);
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    _openLink(info.uri.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final shell = c.pet != null ? shellById(c.pet!.shell) : (_draftShell ?? shells.first);
        final reduced = c.settings.reducedMotion ||
            WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
        return VibeTheme(
          shell: shell,
          reduced: reduced,
          child: MaterialApp(
            title: 'Eggling',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: shell.accent,
              scaffoldBackgroundColor: shell.soft,
              splashFactory: NoSplash.splashFactory,
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: ink,
                selectionColor: shell.accent.withValues(alpha: 0.5),
                selectionHandleColor: ink,
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: ink,
                contentTextStyle: const TextStyle(color: paper, fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            navigatorObservers: [KeyboardObserver()],
            onGenerateRoute: (settings) {
              _openLink(settings.name);
              return MaterialPageRoute<void>(builder: (_) => _Root(controller: c, onShell: (s) => setState(() => _draftShell = s)));
            },
            onGenerateInitialRoutes: (name) {
              _openLink(name);
              return [MaterialPageRoute<void>(builder: (_) => _Root(controller: c, onShell: (s) => setState(() => _draftShell = s)))];
            },
            builder: (context, child) => VibeTheme(
              shell: shell,
              reduced: reduced,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                // Honour large text, up to where the chunky layout still holds.
                child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: child!),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.controller, required this.onShell});

  final GameController controller;
  final ValueChanged<Shell> onShell;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final problem = controller.loadProblem;
        if (problem != null) return _Recovery(controller: controller, problem: problem);
        if (!controller.ready) {
          return const ColoredBox(color: ink);
        }
        if (controller.pet == null) {
          return OnboardingScreen(controller: controller, onShell: onShell);
        }
        return RoomScreen(key: ValueKey(controller.pet!.id), controller: controller);
      },
    );
  }
}

class _Recovery extends StatelessWidget {
  const _Recovery({required this.controller, required this.problem});

  final GameController controller;
  final String problem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Chunk(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('your save could not be opened', style: title),
                  const SizedBox(height: 6),
                  const Text('your pet has not been deleted. try again, and if this keeps happening, restart your phone.', style: body),
                  const SizedBox(height: 14),
                  Cta('try again', onTap: () {
                    controller.loadProblem = null;
                    controller.boot();
                  }),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
