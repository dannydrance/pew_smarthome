import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/lock_gate.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/devices_state.dart';
import 'state/notifications_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final auth = AuthState()..init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<DevicesState>(create: (_) => DevicesState(auth.api)),
        ChangeNotifierProvider<NotificationsState>(create: (_) => NotificationsState(auth.api)),
      ],
      child: const PewApp(),
    ),
  );
}

class PewApp extends StatelessWidget {
  const PewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Shows the sign-in screen or the app, depending on the session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthState, AuthStatus>((a) => a.status);
    return switch (status) {
      AuthStatus.loading => const SplashScreen(),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => const LockGate(child: HomeShell()),
    };
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.hero),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 76),
              SizedBox(height: 18),
              Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 24),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Brand.yellow, strokeWidth: 3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// App logo: yellow tile with a house and a chip.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Brand.yellow,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: fade(Brand.yellow, 0.4), blurRadius: size * 0.4)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.home_rounded, color: Brand.navy, size: size * 0.62),
          Positioned(
            bottom: size * 0.2,
            child: Icon(Icons.memory_rounded, color: Brand.yellow, size: size * 0.24),
          ),
        ],
      ),
    );
  }
}
