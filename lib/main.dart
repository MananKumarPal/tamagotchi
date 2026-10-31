import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/save_store.dart';
import 'game/game_controller.dart';
import 'platform/device_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final controller = GameController(SaveStore(dir), DevicePlatform());
  runApp(EgglingApp(controller: controller));
  await controller.boot();
}
