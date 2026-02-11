import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/layouts/MainLayout.dart';
import 'package:hindsightchat/pages/auth/login_page.dart';
import 'package:hindsightchat/pages/main/MainPage.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/providers/SidebarProvider.dart';
import 'package:hindsightchat/providers/MobileNavigationProvider.dart';
import 'package:provider/provider.dart';

// window
import 'package:window_manager/window_manager.dart';
import 'package:hindsightchat/components/DesktopTitlebar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: "/",
  routes: [
    ShellRoute(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const MainPage()),
      ],
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainLayout(child: child),
    ),

    GoRoute(path: "/login", builder: (context, state) => LoginPage()),
  ],
);

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  GoRouter.optionURLReflectsImperativeAPIs =
      true; // enable URL updates on context.go()

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(100, 100),
      center: true,
      backgroundColor: DarkBackgroundColor,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: "Hindsight Chat",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const Application());
}

class SadPageTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppWrapper extends StatefulWidget {
  final Widget child;
  const AppWrapper({super.key, required this.child});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      authProvider.setDataProvider(dataProvider);
      authProvider.init();

      // wait until authProvider.isLoading is false, then set _isInitialized to true

      Future.doWhile(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return authProvider.isLoading;
      }).then((_) {
        setState(() => _isInitialized = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: DarkBackgroundColor,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      return widget.child;
    }
  }
}

class Application extends StatelessWidget {
  const Application({super.key});

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => DataProvider()),
      ChangeNotifierProvider(create: (_) => SidebarProvider()),
      ChangeNotifierProvider(create: (_) => MobileNavigationProvider()),
    ],
    child: Builder(
      builder: (context) {
        final theme = FThemes.zinc.dark;

        return MaterialApp.router(
          routerConfig: _router,
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...FLocalizations.localizationsDelegates,
          ],
          title: "Hindsight Chat",
          debugShowCheckedModeBanner: false,
          theme: theme.toApproximateMaterialTheme().copyWith(
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                TargetPlatform.android: SadPageTransition(),
                TargetPlatform.iOS: SadPageTransition(),
                TargetPlatform.linux: SadPageTransition(),
                TargetPlatform.macOS: SadPageTransition(),
                TargetPlatform.windows: SadPageTransition(),
              },
            ),
          ),
          builder: (_, child) => AppWrapper(
            child: Material(
              child: FAnimatedTheme(
                data: theme,
                child: _isDesktop
                    ? Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (context) => Column(
                              children: [
                                const DesktopTitlebar(),
                                Expanded(child: child!),
                              ],
                            ),
                          ),
                        ],
                      )
                    : child!,
              ),
            ),
          ),
        );
      },
    ),
  );
}
