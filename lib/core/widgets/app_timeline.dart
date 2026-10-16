import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum TimelineState { done, active, upcoming }

class TimelineStep {
  const TimelineStep({required this.label, this.caption, this.state = TimelineState.upcoming, this.icon});

  final String label;
  final String? caption;
  final TimelineState state;
  final IconData? icon;
}

/// Riwayat langkah (padanan `Perjalanan pesanan` di desain).
///
/// Di layar lebar tampil mendatar, di HP tampil menurun sebagai daftar.
class AppTimeline extends StatelessWidget {
  const AppTimeline({super.key, required this.steps, this.vertical});

  final List<TimelineStep> steps;

  /// `null` berarti otomatis: menurun bila lebar < 700, mendatar bila lebih.
  final bool? vertical;

  @override
  Widget build(BuildContext context) {
    final isVertical = vertical ?? MediaQuery.sizeOf(context).width < 700;
    return isVertical ? _vertical(context) : _horizontal(context);
  }

  Widget _horizontal(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 12));
      children.add(Expanded(child: _StepColumn(step: steps[i])));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _vertical(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
            child: _StepRow(step: steps[i], isLast: i == steps.length - 1),
          ),
      ],
    );
  }
}

class _StepColumn extends StatelessWidget {
  const _StepColumn({required this.step});

  final TimelineStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorOf(context, step.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        _StepIcon(step: step, size: 22),
        Text(
          step.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: step.state == TimelineState.upcoming ? context.tokens.muted : color,
          ),
        ),
        if (step.caption != null)
          Text(step.caption!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Column(
          children: [
            _StepIcon(step: step, size: 20),
            if (!isLast)
              Container(
                width: 2,
                height: 26,
                margin: const EdgeInsets.only(top: 4),
                color: context.tokens.line,
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  step.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: step.state == TimelineState.upcoming ? context.tokens.muted : context.tokens.ink,
                  ),
                ),
                if (step.caption != null)
                  Text(step.caption!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step, required this.size});

  final TimelineStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = _colorOf(context, step.state);
    final isDone = step.state == TimelineState.done;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: step.state == TimelineState.upcoming ? tokens.canvas : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: step.state == TimelineState.upcoming ? tokens.line : color,
        ),
      ),
      child: Icon(
        step.icon ?? (isDone ? Icons.check : Icons.circle),
        size: size * 0.55,
        color: step.state == TimelineState.upcoming ? tokens.muted : Colors.white,
      ),
    );
  }
}

Color _colorOf(BuildContext context, TimelineState state) {
  final tokens = context.tokens;
  return switch (state) {
    TimelineState.done => tokens.success,
    TimelineState.active => Theme.of(context).colorScheme.primary,
    TimelineState.upcoming => tokens.muted,
  };
}
