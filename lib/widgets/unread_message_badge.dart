import 'package:flutter/material.dart';

class UnreadMessageBadge extends StatefulWidget {
  final Widget child;
  final bool hasUnreadMessages;

  const UnreadMessageBadge({
    Key? key,
    required this.child,
    required this.hasUnreadMessages,
  }) : super(key: key);

  @override
  State<UnreadMessageBadge> createState() => _UnreadMessageBadgeState();
}

class _UnreadMessageBadgeState extends State<UnreadMessageBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });
  }

  @override
  void didUpdateWidget(UnreadMessageBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasUnreadMessages && !_controller.isAnimating) {
      _controller.forward();
    } else if (!widget.hasUnreadMessages && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasUnreadMessages) {
      return widget.child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScaleTransition(
          scale: _animation,
          child: widget.child,
        ),
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 10,
              minHeight: 10,
            ),
          ),
        ),
      ],
    );
  }
} 