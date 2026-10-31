import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../art/sticker.dart';
import '../art/manifest.dart';
import '../domain/pet_state.dart';
import '../domain/reminders.dart';
import '../domain/rules.dart';
import '../game/game_controller.dart';

/// The real adapter: wall clock, native widget channel, notifications, sound.
class DevicePlatform implements GamePlatform {
  DevicePlatform();

  static const _widget = MethodChannel('eggling/widget');
  final _notifications = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer();
  bool _notificationsReady = false;

  @override
  int get now => DateTime.now().millisecondsSinceEpoch;

  @override
  int get offsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  @override
  Future<List<String>> readWidgetActions() async {
    try {
      final lines = await _widget.invokeListMethod<String>('readActions');
      return lines ?? const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<void> ackWidgetActions(int count) async {
    if (count == 0) return;
    try {
      await _widget.invokeMethod<void>('ackActions', count);
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> publishWidget(String json, String? formId, PetState? pet) async {
    try {
      final sprites = formId == null || pet == null ? null : await _sprites(formId, pet);
      await _widget.invokeMethod<void>(
          'publish', {'snapshot': json, 'sprites': sprites});
    } on MissingPluginException {
      return;
    }
  }

  Future<Map<String, Uint8List>> _sprites(String formId, PetState pet) async {
    final classicA = pet.profile == RuleProfile.classicA;
    return {
      'idle': await creaturePng(formId, Expression.normal),
      'happy': await creaturePng(formId, Expression.happy,
          prop: 'heart', px: 16, py: 0),
      'call': await creaturePng(formId, Expression.shout,
          prop: 'sweat', px: 16, py: -3),
      'sick': await creaturePng(formId, Expression.sick,
          prop: 'sick', px: 13, py: -5),
      'sleep': await creaturePng(formId, Expression.sleeping,
          prop: 'zed', px: 16, py: -4),
      'egg': await creaturePng('egg', Expression.normal),
      'departed': await creaturePng(formId, Expression.sleeping,
          prop: classicA ? 'halo' : 'saucer', px: classicA ? 4 : 1, py: -5),
    };
  }

  Future<void> _ensureNotifications() async {
    if (_notificationsReady) return;
    tzdata.initializeTimeZones();
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_egg'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _notificationsReady = true;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    await _ensureNotifications();
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, sound: true) ??
        await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Replaces all pending reminders. Fixed slots keep this idempotent.
  /// Set by the app so reminders can use the pet's name.
  String petName = 'Your pet';

  @override
  Future<void> scheduleReminders(List<Reminder> plan) async {
    try {
      await _ensureNotifications();
      await _notifications.cancelAll();
      for (final r in plan) {
        await _notifications.zonedSchedule(
          id: r.slot,
          title: 'Eggling',
          body: reminderText(r.reason, petName),
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, r.at),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('care', 'Care reminders',
                channelDescription: 'When your pet calls for attention',
                importance: Importance.defaultImportance),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (e) {
      // Reminders are a courtesy: the simulation never depends on them.
      debugPrint('Reminders not scheduled: $e');
    }
  }

  @override
  void play(Cue cue) {
    _player
      ..stop()
      ..play(AssetSource('sounds/${cue.name}.wav'));
  }
}

