/// How the animations are put together. Every form shares these definitions,
/// because faces are redrawn from the anchors in `sprites.dart`.
enum Expression { normal, blink, happy, sad, sleeping, sick, shout, chew }

class AnimFrame {
  const AnimFrame(this.expression,
      {this.dx = 0, this.dy = 0, this.flip = false, this.prop, this.px = 0, this.py = 0});

  final Expression expression;
  final int dx;
  final int dy;
  final bool flip;

  /// Prop drawn at screen position ([px], [py]) relative to the pet.
  final String? prop;
  final int px;
  final int py;
}

enum AfterAnim { loop, returnToIdle, hold }

class AnimState {
  const AnimState(this.name, this.frames, this.frameMs, this.after, this.trigger);

  final String name;
  final List<AnimFrame> frames;
  final int frameMs;
  final AfterAnim after;

  /// What in the game starts this animation.
  final String trigger;

  bool get oneShot => after != AfterAnim.loop;
}

const _n = Expression.normal;
const _h = Expression.happy;
const _c = Expression.chew;
const _s = Expression.sad;

const Map<String, AnimState> animationManifest = {
  'idle': AnimState('idle', [
    AnimFrame(_n),
    AnimFrame(_n, dx: 1),
    AnimFrame(_n, dx: 2, dy: -1),
    AnimFrame(Expression.blink, dx: 2),
    AnimFrame(_n, dx: 1, flip: true),
    AnimFrame(_n, flip: true, dy: -1),
    AnimFrame(_n, dx: -1, flip: true),
    AnimFrame(Expression.blink, dx: -2, flip: true),
    AnimFrame(_n, dx: -2, dy: -1),
    AnimFrame(_n, dx: -1),
  ], 500, AfterAnim.loop, 'Awake with nothing else happening'),
  'call': AnimState('call', [
    AnimFrame(Expression.shout, dy: -1, prop: 'sweat', px: 15, py: -3),
    AnimFrame(_n),
    AnimFrame(Expression.shout, dy: -1, flip: true, prop: 'sweat', px: -5, py: -3),
    AnimFrame(_n, flip: true),
  ], 350, AfterAnim.loop, 'An attention call is active'),
  'eatMeal': AnimState('eatMeal', [
    AnimFrame(Expression.shout, prop: 'meal', px: -10, py: 8),
    AnimFrame(_c, prop: 'meal', px: -10, py: 8),
    AnimFrame(Expression.shout, prop: 'meal_half', px: -10, py: 8),
    AnimFrame(_c, prop: 'meal_half', px: -10, py: 8),
    AnimFrame(Expression.shout, prop: 'crumb', px: -6, py: 12),
    AnimFrame(_c),
    AnimFrame(_h, dy: -1),
  ], 300, AfterAnim.returnToIdle, 'FedMeal'),
  'eatSnack': AnimState('eatSnack', [
    AnimFrame(Expression.shout, prop: 'snack', px: -10, py: 8),
    AnimFrame(_c, prop: 'snack', px: -10, py: 8),
    AnimFrame(Expression.shout, prop: 'snack_half', px: -10, py: 8),
    AnimFrame(_c, prop: 'snack_half', px: -10, py: 8),
    AnimFrame(_h, dy: -2, prop: 'heart', px: -7, py: 0),
    AnimFrame(_h, prop: 'heart', px: -7, py: -2),
  ], 300, AfterAnim.returnToIdle, 'FedSnack'),
  'happy': AnimState('happy', [
    AnimFrame(_h, dy: -3, prop: 'spark', px: -7, py: 1),
    AnimFrame(_h, prop: 'spark', px: 18, py: 1),
    AnimFrame(_h, dy: -3, flip: true, prop: 'spark', px: -7, py: 3),
    AnimFrame(_h, flip: true, prop: 'spark', px: 18, py: 3),
    AnimFrame(_h, dy: -2),
  ], 220, AfterAnim.returnToIdle, 'GameWon, WasCured, Scolded pet recovers'),
  'sad': AnimState('sad', [
    AnimFrame(_s, dx: -1),
    AnimFrame(_s, dx: 1),
    AnimFrame(_s, dx: -1, dy: 1, prop: 'sweat', px: 15, py: 0),
    AnimFrame(_s, dy: 1, prop: 'sweat', px: 15, py: 2),
  ], 320, AfterAnim.returnToIdle, 'GameLost, refused action, Scolded'),
  'dance': AnimState('dance', [
    AnimFrame(_h, dx: -2, dy: -1, prop: 'note', px: 18, py: 0),
    AnimFrame(_n, dy: 0),
    AnimFrame(_h, dx: 2, dy: -1, flip: true, prop: 'note', px: -7, py: 0),
    AnimFrame(_n, flip: true),
  ], 260, AfterAnim.loop, 'Waiting in a game'),
  'poop': AnimState('poop', [
    AnimFrame(_c, dy: 1),
    AnimFrame(Expression.blink, dy: 0),
    AnimFrame(_c, dy: 1),
    AnimFrame(_h, dx: -3),
  ], 280, AfterAnim.returnToIdle, 'Pooped'),
  'sleep': AnimState('sleep', [
    AnimFrame(Expression.sleeping, dy: 1, prop: 'zed', px: 17, py: 0),
    AnimFrame(Expression.sleeping, dy: 1, prop: 'zed', px: 19, py: -3),
    AnimFrame(Expression.sleeping, prop: 'zed', px: 21, py: -6),
    AnimFrame(Expression.sleeping),
  ], 800, AfterAnim.loop, 'FellAsleep'),
  'wake': AnimState('wake', [
    AnimFrame(Expression.sleeping, dy: 1),
    AnimFrame(Expression.blink),
    AnimFrame(_n, dy: -1),
    AnimFrame(_h),
  ], 320, AfterAnim.returnToIdle, 'Woke'),
  'sick': AnimState('sick', [
    AnimFrame(Expression.sick, prop: 'sick', px: 17, py: -2),
    AnimFrame(Expression.sick, dx: 1, dy: 1, prop: 'sick', px: 17, py: -2),
  ], 700, AfterAnim.loop, 'Sick and not doing anything else'),
  'medicine': AnimState('medicine', [
    AnimFrame(Expression.sick, prop: 'pill', px: -10, py: 2),
    AnimFrame(Expression.shout, prop: 'pill', px: -7, py: 4),
    AnimFrame(_c, prop: 'pill', px: -4, py: 6),
    AnimFrame(_c),
    AnimFrame(Expression.blink, dy: -1),
  ], 300, AfterAnim.returnToIdle, 'Dosed'),
  'evolve': AnimState('evolve', [
    AnimFrame(_n),
    AnimFrame(Expression.blink, dy: -1, prop: 'spark', px: -7, py: 2),
    AnimFrame(_h, dy: -2, prop: 'spark', px: 18, py: 4),
    AnimFrame(_h, dy: -3, prop: 'spark', px: -7, py: 0),
  ], 180, AfterAnim.returnToIdle, 'Evolved'),
  'departedA': AnimState('departedA', [
    AnimFrame(Expression.sleeping, prop: 'halo', px: 4, py: -5),
    AnimFrame(Expression.sleeping, dy: -1, prop: 'halo', px: 4, py: -6),
  ], 800, AfterAnim.loop, 'Departed, Classic A'),
  'departedB': AnimState('departedB', [
    AnimFrame(Expression.sleeping, prop: 'saucer', px: 1, py: -7),
    AnimFrame(Expression.sleeping, dy: -1, prop: 'saucer', px: 1, py: -8),
  ], 800, AfterAnim.loop, 'Departed, Classic B'),
};

/// Falls back to idle so a missing name can never blank the screen.
AnimState animationFor(String name) =>
    animationManifest[name] ?? animationManifest['idle']!;
