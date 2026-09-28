import { describe, expect, it } from "vitest";
import { youtubeEmbedUrl } from "~/lib/trailer";

describe("youtubeEmbedUrl", () => {
  it("turns a YouTube watch link into a privacy-friendly embed url", () => {
    expect(youtubeEmbedUrl("https://www.youtube.com/watch?v=abc123DEF45")).toBe(
      "https://www.youtube-nocookie.com/embed/abc123DEF45",
    );
  });

  it("accepts ids containing dashes and underscores", () => {
    expect(youtubeEmbedUrl("https://www.youtube.com/watch?v=a-b_c1D2e3F")).toBe(
      "https://www.youtube-nocookie.com/embed/a-b_c1D2e3F",
    );
  });

  it("returns null when there is no link", () => {
    expect(youtubeEmbedUrl(undefined)).toBeNull();
    expect(youtubeEmbedUrl(null)).toBeNull();
    expect(youtubeEmbedUrl("")).toBeNull();
  });

  it("returns null for anything that is not a canonical YouTube watch link", () => {
    expect(youtubeEmbedUrl("javascript:alert(1)")).toBeNull();
    expect(
      youtubeEmbedUrl("https://example.com/watch?v=abc123DEF45"),
    ).toBeNull();
    expect(
      youtubeEmbedUrl(
        "https://www.youtube.com.evil.example/watch?v=abc123DEF45",
      ),
    ).toBeNull();
    expect(
      youtubeEmbedUrl("https://www.youtube.com/watch?v=tooshort"),
    ).toBeNull();
    expect(
      youtubeEmbedUrl("https://www.youtube.com/watch?v=abc123DEF45&autoplay=1"),
    ).toBeNull();
  });
});
