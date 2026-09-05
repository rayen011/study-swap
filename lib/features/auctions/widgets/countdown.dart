import 'dart:async';

import 'package:flutter/material.dart';

/// How long is left, written the way somebody deciding whether to bid reads it.
///
/// The precision changes with the urgency, which is the point: "6d 20h" is all
/// anybody needs a week out, and "48s" is the only thing that matters at the
/// end. A seconds counter on a seven-day auction is noise that also forces a
/// rebuild every second for no reason.
String formatCountdown(Duration left) {
  if (left <= Duration.zero) return 'Closed';

  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  final seconds = left.inSeconds % 60;

  if (days > 0) return '${days}d ${hours}h';
  if (left.inHours > 0) return '${left.inHours}h ${minutes}m';
  if (left.inMinutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

/// How often the countdown needs redrawing to stay honest.
///
/// Under an hour it ticks every second; above that the minute is the smallest
/// thing on screen, so once a minute is enough. A list of twenty auctions
/// rebuilding every second would be twenty rebuilds a second to change nothing.
Duration countdownTick(Duration left) {
  return left.inHours > 0
      ? const Duration(minutes: 1)
      : const Duration(seconds: 1);
}

/// A live countdown to [endsAt].
///
/// Owns its own timer rather than taking one from a parent so a screen can
/// show several at once without coordinating them, and stops itself the moment
/// the time runs out — a closed auction has nothing left to count.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.endsAt,
    required this.builder,
    this.now,
  });

  final DateTime? endsAt;

  /// Rebuilt on every tick with the remaining time.
  final Widget Function(BuildContext context, Duration left) builder;

  /// Fixes "now" for tests. Live, the clock is the real one.
  final DateTime Function()? now;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _schedule();
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A bid near the end moves the closing time; the countdown has to follow
    // it rather than keep counting to the old one.
    if (oldWidget.endsAt != widget.endsAt) {
      _left = _remaining();
      _schedule();
    }
  }

  Duration _remaining() {
    final end = widget.endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference((widget.now ?? DateTime.now)());
    return left.isNegative ? Duration.zero : left;
  }

  void _schedule() {
    _timer?.cancel();
    if (_left <= Duration.zero) return;

    _timer = Timer(countdownTick(_left), () {
      if (!mounted) return;
      setState(() => _left = _remaining());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}
