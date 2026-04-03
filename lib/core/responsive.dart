// lib/core/responsive.dart

import 'package:flutter/material.dart';

class Responsive {
  // Breakpoints
  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMax;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMax &&
      MediaQuery.of(context).size.width < tabletMax;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMax;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMax;

  // Returns different values based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  // Max content width for wide screens
  static double maxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletMax) return 900;
    if (width >= mobileMax) return 700;
    return width;
  }

  // Horizontal padding that scales with screen
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletMax) return (width - 900) / 2;
    if (width >= mobileMax) return (width - 700) / 2;
    return 0;
  }
}

// Widget that centers and constrains content on wide screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= Responsive.mobileMax;

    if (!isWide) return child;

    final containerWidth = maxWidth ?? Responsive.maxWidth(context);

    return Container(
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(child: Container(color: backgroundColor)),
          SizedBox(width: containerWidth, child: child),
          Expanded(child: Container(color: backgroundColor)),
        ],
      ),
    );
  }
}

// Wraps a Scaffold to be responsive — centers content on web
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= Responsive.mobileMax;

    if (!isWide) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        backgroundColor: backgroundColor,
      );
    }

    // On wide screens — center content with max width
    const maxContentWidth = 500.0;

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.black,
      body: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: maxContentWidth,
            child: Scaffold(
              appBar: appBar,
              body: body,
              bottomNavigationBar: bottomNavigationBar,
              floatingActionButton: floatingActionButton,
              backgroundColor: backgroundColor,
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
