import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import 'kit.dart';
import 'pet_stage.dart';
import 'strings.dart';

class DepartedScreen extends StatelessWidget {
  const DepartedScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.pet!;
    return Scaffold(
      body: SkyBackdrop(
        hourOverride: 23,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 280, child: PetStage(controller: controller)),
                  const SizedBox(height: 12),
                  Chunk(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('bye, ${p.name}', style: title.copyWith(fontSize: 24)),
                      const SizedBox(height: 6),
                      Text(S.departure(p), textAlign: TextAlign.center, style: body),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: Cta('hatch a new egg', onTap: () async {
                          await controller.clearPet();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        }),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
