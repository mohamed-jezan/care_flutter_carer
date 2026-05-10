import 'package:flutter/material.dart';

class ThreeDotLoader extends StatefulWidget {
  final Color color;
  final double size;

  const ThreeDotLoader({
    super.key,
    this.color = const Color(0xFFFF6F6F),
    this.size = 10,
  });

  @override
  State<ThreeDotLoader> createState() => _ThreeDotLoaderState();
}

class _ThreeDotLoaderState extends State<ThreeDotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        double value = (_controller.value - delay) % 1.0;
        double opacity = value < 0.5 ? value * 2 : (1 - value) * 2;

        return Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0.0),
        _buildDot(0.2),
        _buildDot(0.4),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}