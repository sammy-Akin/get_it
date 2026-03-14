import 'package:flutter/material.dart';
import 'package:get_it/auth/login_screen.dart';
import 'package:get_it/auth/register_screen.dart';
import 'package:get_it/screens/cart_screen.dart';
import 'package:get_it/screens/checkout_screen.dart';
import 'package:get_it/screens/home_screen.dart';
import 'package:get_it/screens/order_tracking_screen.dart';
import 'package:get_it/screens/orders_screen.dart';
import 'package:get_it/screens/profile_screen.dart';
import 'package:get_it/screens/search_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';

import '../screens/vendor/vendor_home_screen.dart';
import '../screens/picker/picker_home_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _authStream = FirebaseAuth.instance.authStateChanges();

  static final _authPaths = ['/login', '/register'];
  static final _publicPaths = ['/', '/onboarding'];

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(_authStream),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;

      if (_publicPaths.contains(loc)) return null;
      if (user == null) return _authPaths.contains(loc) ? null : '/login';
      if (_authPaths.contains(loc)) return null;

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(
        path: '/order/:orderId',
        builder: (_, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(
        path: '/vendor-home',
        builder: (_, __) => const VendorHomeScreen(),
      ),
      GoRoute(
        path: '/picker-home',
        builder: (_, __) => const PickerHomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: const Center(
        child: Text('Page not found', style: TextStyle(color: Colors.white)),
      ),
    ),
  );
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
