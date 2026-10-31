import 'package:flutter/material.dart';

import '../art/sprites.dart';
import '../art/sticker.dart';
import '../game/game_controller.dart';
import 'kit.dart';
import 'sheets.dart';
import 'strings.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return SoftPage(
      heading: 'HELP',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Cta('replay the tutorial', onTap: () => showTutorial(context, controller)),
          const SizedBox(height: 14),
          for (final (icon, name, text) in S.glossary)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Chunk(
                padding: const EdgeInsets.all(12),
                radius: 18,
                shadow: 3,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ExcludeSemantics(child: PixelIcon(menuIconArt[icon]!, size: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: title.copyWith(fontSize: 17)),
                      Text(text, style: body.copyWith(fontSize: 15)),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class TextPage extends StatelessWidget {
  const TextPage({super.key, required this.heading, required this.text});

  final String heading;
  final String text;

  @override
  Widget build(BuildContext context) => SoftPage(
        heading: heading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Chunk(child: Text(text, style: body.copyWith(height: 1.4))),
        ),
      );
}
