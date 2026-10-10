import 'dart:math';

/// A width and a height; the domain layer has no Flutter types.
class Size2 {
  const Size2(this.width, this.height);

  final double width;
  final double height;
}

const orbCount = 28;

/// A drifting, pulsing orb of the Freaky theme.
class Orb {
  Orb({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.useGlow,
  });

  double x;
  double y;
  final double radius;
  final double speedX;
  final double speedY;
  final double phase;

  /// Tinted with the glow colour of the theme, otherwise with its accent.
  final bool useGlow;

  /// Moves the orb one frame; an orb that left the window by its own radius
  /// comes back on the opposite side.
  void step(Size2 size) {
    x += speedX;
    y += speedY;
    if (x < -radius) x = size.width + radius;
    if (x > size.width + radius) x = -radius;
    if (y < -radius) y = size.height + radius;
    if (y > size.height + radius) y = -radius;
  }
}

/// The orbs of the Freaky theme, spread over [size] with [random].
List<Orb> createOrbs(Size2 size, Random random) {
  return [
    for (var index = 0; index < orbCount; index++)
      Orb(
        x: random.nextDouble() * size.width,
        y: random.nextDouble() * size.height,
        radius: 40 + random.nextDouble() * 120,
        speedX: (random.nextDouble() - 0.5) * 0.6,
        speedY: (random.nextDouble() - 0.5) * 0.6,
        phase: random.nextDouble() * pi * 2,
        useGlow: index.isEven,
      ),
  ];
}

/// How much of its radius an orb has in [frame]: between 50 and 100 percent.
double orbPulse(int frame, double phase) =>
    0.75 + 0.25 * sin(frame / 40 + phase);
