import { describe, expect, it } from "vitest";
import { setupRedirect } from "./setupWizard";

describe("setupRedirect", () => {
  it("sends a user who has not finished setup to the wizard", () => {
    expect(setupRedirect({ setupCompleted: false }, "/dashboard")).toBe(
      "/setup",
    );
    expect(setupRedirect({ setupCompleted: false }, "/account")).toBe("/setup");
  });

  it("keeps an unfinished user on the wizard", () => {
    expect(setupRedirect({ setupCompleted: false }, "/setup")).toBeNull();
  });

  it("sends a finished user away from the wizard", () => {
    expect(setupRedirect({ setupCompleted: true }, "/setup")).toBe(
      "/dashboard",
    );
  });

  it("leaves a finished user alone everywhere else", () => {
    expect(setupRedirect({ setupCompleted: true }, "/dashboard")).toBeNull();
  });
});
