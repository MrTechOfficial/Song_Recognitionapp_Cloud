import 'package:flutter/material.dart';

/// Only route content changes opacity. The single scene outside Navigator
/// keeps its camera, clock and texture while pages enter or leave.
class SeasonalPageTransitionsBuilder extends PageTransitionsBuilder {
  const SeasonalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final incoming = animation.drive(
        CurveTween(curve: const Interval(.30, 1, curve: Curves.easeOutCubic)));
    final outgoing = secondaryAnimation.drive(
        CurveTween(curve: const Interval(0, .65, curve: Curves.easeInCubic)));
    return FadeTransition(
        opacity: incoming,
        child:
            FadeTransition(opacity: ReverseAnimation(outgoing), child: child));
  }
}
