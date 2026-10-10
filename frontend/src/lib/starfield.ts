export interface Star {
  x: number;
  y: number;
  size: number;
  speed: number;
}

const STARS_PER_PIXEL = 200 / (1920 * 1080);
const MAX_STARS = 600;

export function starCountFor(width: number, height: number): number {
  return Math.min(MAX_STARS, Math.round(width * height * STARS_PER_PIXEL));
}

export function createStars(
  count: number,
  width: number,
  height: number,
  random: () => number = Math.random,
): Star[] {
  return Array.from({ length: count }, () => ({
    x: random() * width,
    y: random() * height,
    size: random() * 1.5 + 0.5,
    speed: random() * 2 + 0.1,
  }));
}

export function rescaleStars(
  stars: Star[],
  fromWidth: number,
  fromHeight: number,
  toWidth: number,
  toHeight: number,
): Star[] {
  if (fromWidth <= 0 || fromHeight <= 0) return stars;
  return stars.map((star) => ({
    ...star,
    x: (star.x / fromWidth) * toWidth,
    y: (star.y / fromHeight) * toHeight,
  }));
}

export function advanceStars(stars: Star[], height: number): void {
  for (const star of stars) {
    star.y -= star.speed;
    if (star.y < 0) star.y = height;
  }
}
