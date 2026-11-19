import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import '../theme.dart';

/// Asks for the phone's own lock (fingerprint, face, PIN, pattern) before showing the app,
/// at every start and when coming back after more than [relockAfter] in the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  static const Duration relockAfter = Duration(seconds: 30);

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _checking = false;
  String? _message;
  bool _noLockSet = false;
  DateTime? _backgroundSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The fingerprint/PIN dialog itself pauses the app: ignore that.
    if (_checking) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundSince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      if (_unlocked && since != null && DateTime.now().difference(since) > LockGate.relockAfter) {
        // Close any open page, sheet or dialog so nothing stays visible above the lock screen.
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _unlocked = false);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_checking || _unlocked) return;
    setState(() {
      _checking = true;
      _message = null;
      _noLockSet = false;
    });
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        setState(() {
          _noLockSet = true;
          _message = 'For your security this app needs a screen lock. Set a PIN, pattern, password '
              'or fingerprint in your phone settings, then try again.';
        });
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock PEW Smart Home',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _message = ok ? null : 'Not unlocked. Tap Unlock to try again.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = e.code.toLowerCase();
      setState(() {
        if (code.contains('passcodenotset') || code.contains('notenrolled') || code.contains('notavailable')) {
          _noLockSet = true;
          _message = 'For your security this app needs a screen lock. Set a PIN, pattern, password '
              'or fingerprint in your phone settings, then try again.';
        } else if (code.contains('lockedout')) {
          _message = 'Too many attempts. Unlock your phone with its PIN/pattern first, then try again.';
        } else {
          _message = e.message ?? 'Could not unlock.';
        }
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Brand.hero),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 72),
                  const SizedBox(height: 22),
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
                  const SizedBox(height: 10),
                  const Text('PEW Smart Home is locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _message ?? 'Use your fingerprint, face, PIN or pattern to open the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fade(Colors.white, 0.8), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Brand.yellow, foregroundColor: Brand.navy),
                      onPressed: _checking ? null : _unlock,
                      icon: _checking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.navy))
                          : Icon(_noLockSet ? Icons.refresh_rounded : Icons.fingerprint_rounded),
                      label: Text(_noLockSet ? 'Try again' : 'Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
