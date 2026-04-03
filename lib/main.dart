// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GetItApp());
}

class GetItApp extends StatelessWidget {
  const GetItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: MaterialApp.router(
        title: 'Get It',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          return _ResponsiveWrapper(child: child!);
        },
      ),
    );
  }
}

class _ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const _ResponsiveWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    if (isMobile) return child;

    // On tablets/desktop — show app centered like a phone
    // with a subtle background
    const appWidth = 420.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Center(
        child: Container(
          width: appWidth,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
