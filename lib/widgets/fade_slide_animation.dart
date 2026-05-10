import 'package:flutter/material.dart';

class FadeSlideAnimation extends StatelessWidget {
  final Widget child;
  final AnimationController controller;
  final double delay;

  const FadeSlideAnimation({
    super.key,
    required this.child,
    required this.controller,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
  opacity: controller,
  child: SlideTransition(
    position: animation,
    child: ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0).animate(controller),
      child: child,
    ),
  ),
);
  }
}