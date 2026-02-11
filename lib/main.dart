import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:hindsightchat/pages/auth/login_page.dart';
import 'package:hindsightchat/providers/AuthProvider.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:provider/provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: "/",
  routes: [
    GoRoute(path: '/', builder: (context, state) => const Example()),
    GoRoute(path: "/login", builder: (context, state) => LoginPage()),
  ],
);

void main() {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
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
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      authProvider.setDataProvider(dataProvider);
      authProvider.init();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => DataProvider()),
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
              child: FAnimatedTheme(data: theme, child: child!),
            ),
          ),
        );
      },
    ),
  );
}

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (auth.isAuthenticated) ...[
              Text('Welcome ${auth.user?.username ?? ""}'),
              Text('Friends: ${data.friends.length}'),
              Text('Conversations: ${data.conversations.length}'),
              Text('Servers: ${data.servers.length}'),
              Text('Incoming requests: ${data.incomingRequests.length}'),
              Text(
                'Presence details: ${data.currentActivity?.details ?? "None"}',
              ),
              Text('Presence state: ${data.currentActivity?.state ?? "None"}'),
              Text(
                "Presence small text: ${data.currentActivity?.smallText ?? "None"}",
              ),
              Text(
                "Presence large text: ${data.currentActivity?.largeText ?? "None"}",
              ),

              FButton(onPress: auth.logout, child: const Text('Logout')),
            ] else ...[
              const Text('Not logged in'),
              FButton(
                onPress: () {
                  GoRouter.of(context).go("/login");
                },
                child: const Text('Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
