import 'pet_state.dart';
import 'rules.dart';

const int reminderSlots = 8;
const int _mergeWindowMs = 30 * minuteMs;

class UpcomingCallAt {
  const UpcomingCallAt(this.at, this.reason);
  final int at;
  final CallReason reason;
}

class Reminder {
  const Reminder(this.slot, this.at, this.reason);

  /// Notification id. Reusing fixed slots means rescheduling replaces rather
  /// than stacks, so reminders can never duplicate.
  final int slot;
  final int at;
  final CallReason reason;
}

bool inQuietHours(int at, int start, int end, int offsetMinutes) {
  if (start == end) return false;
  final hour = ((at ~/ minuteMs + offsetMinutes) % 1440) ~/ 60;
  return start < end
      ? hour >= start && hour < end
      : hour >= start || hour < end;
}

List<Reminder> planReminders(
  List<UpcomingCallAt> calls, {
  required bool enabled,
  required int quietStartHour,
  required int quietEndHour,
  required int offsetMinutes,
}) {
  if (!enabled) return const [];
  final sorted = [...calls]..sort((a, b) => a.at.compareTo(b.at));
  final plan = <Reminder>[];
  for (final c in sorted) {
    if (inQuietHours(c.at, quietStartHour, quietEndHour, offsetMinutes)) continue;
    if (plan.isNotEmpty && c.at - plan.last.at < _mergeWindowMs) continue;
    plan.add(Reminder(plan.length, c.at, c.reason));
    if (plan.length == reminderSlots) break;
  }
  return plan;
}

String reminderText(CallReason r, String name) => switch (r) {
      CallReason.hunger => '$name is hungry.',
      CallReason.happiness => '$name wants some attention.',
      CallReason.lights => '$name fell asleep. Turn the light off.',
      CallReason.misbehave => '$name is acting up.',
    };
