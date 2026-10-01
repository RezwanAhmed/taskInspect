import 'package:flutter/material.dart';

/// Colors for task statuses (badges, list markers), available through
/// `Theme.of(context).extension<StatusColors>()`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.draft,
    required this.open,
    required this.assigned,
    required this.inProgress,
    required this.submitted,
    required this.approved,
    required this.rejected,
    required this.correctionRequested,
    required this.cancelled,
  });

  static const light = StatusColors(
    draft: Color(0xFF616161),
    open: Color(0xFF00838F),
    assigned: Color(0xFF1565C0),
    inProgress: Color(0xFFB26A00),
    submitted: Color(0xFF6A1B9A),
    approved: Color(0xFF2E7D32),
    rejected: Color(0xFFC62828),
    correctionRequested: Color(0xFFD84315),
    cancelled: Color(0xFF757575),
  );

  static const dark = StatusColors(
    draft: Color(0xFFBDBDBD),
    open: Color(0xFF80DEEA),
    assigned: Color(0xFF90CAF9),
    inProgress: Color(0xFFFFCC80),
    submitted: Color(0xFFCE93D8),
    approved: Color(0xFFA5D6A7),
    rejected: Color(0xFFEF9A9A),
    correctionRequested: Color(0xFFFFAB91),
    cancelled: Color(0xFF9E9E9E),
  );

  final Color draft;
  final Color open;
  final Color assigned;
  final Color inProgress;
  final Color submitted;
  final Color approved;
  final Color rejected;
  final Color correctionRequested;
  final Color cancelled;

  @override
  StatusColors copyWith({
    Color? draft,
    Color? open,
    Color? assigned,
    Color? inProgress,
    Color? submitted,
    Color? approved,
    Color? rejected,
    Color? correctionRequested,
    Color? cancelled,
  }) {
    return StatusColors(
      draft: draft ?? this.draft,
      open: open ?? this.open,
      assigned: assigned ?? this.assigned,
      inProgress: inProgress ?? this.inProgress,
      submitted: submitted ?? this.submitted,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
      correctionRequested: correctionRequested ?? this.correctionRequested,
      cancelled: cancelled ?? this.cancelled,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) {
      return this;
    }
    return StatusColors(
      draft: Color.lerp(draft, other.draft, t)!,
      open: Color.lerp(open, other.open, t)!,
      assigned: Color.lerp(assigned, other.assigned, t)!,
      inProgress: Color.lerp(inProgress, other.inProgress, t)!,
      submitted: Color.lerp(submitted, other.submitted, t)!,
      approved: Color.lerp(approved, other.approved, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      correctionRequested: Color.lerp(correctionRequested, other.correctionRequested, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
    );
  }
}
