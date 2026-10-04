import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { compareVersions, nextReleaseVersion, parseVersion } from "./release-version.mjs";

describe("parseVersion", () => {
  it("parses plain X.Y.Z", () => {
    assert.deepEqual(parseVersion("0.9.0"), [0, 9, 0]);
    assert.deepEqual(parseVersion("12.0.31"), [12, 0, 31]);
  });

  it("rejects everything that is not exactly three numeric parts", () => {
    for (const bad of ["", "1", "1.2", "1.2.3.4", "1.2.x", "v1.2.3", "1.2.3-rc1", " 1.2.3", "01.2.3", "1.02.3"]) {
      assert.equal(parseVersion(bad), null, bad);
    }
  });
});

describe("compareVersions", () => {
  it("orders numerically, not as text", () => {
    assert.ok(compareVersions("0.9.0", "0.1.3") > 0);
    assert.ok(compareVersions("0.10.0", "0.9.0") > 0);
    assert.ok(compareVersions("1.0.0", "0.99.99") > 0);
    assert.ok(compareVersions("0.1.3", "0.1.10") < 0);
    assert.equal(compareVersions("1.2.3", "1.2.3"), 0);
  });
});

describe("nextReleaseVersion", () => {
  it("bumps the patch of the latest tag when no version is requested", () => {
    assert.deepEqual(nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: "" }), {
      version: "0.1.4",
      tag: "v0.1.4",
    });
  });

  it("bumps numerically across two-digit patches", () => {
    assert.equal(nextReleaseVersion({ latestTag: "v0.1.9", packageVersion: "0.1.0", requested: "" }).version, "0.1.10");
  });

  it("uses the package version while no tag exists", () => {
    assert.deepEqual(nextReleaseVersion({ latestTag: "", packageVersion: "0.1.0", requested: "" }), {
      version: "0.1.0",
      tag: "v0.1.0",
    });
  });

  it("uses a requested version that is greater than the latest tag", () => {
    assert.deepEqual(nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: "0.9.0" }), {
      version: "0.9.0",
      tag: "v0.9.0",
    });
  });

  it("accepts a leading v and surrounding whitespace on the requested version", () => {
    assert.equal(nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: " v0.9.0 " }).version, "0.9.0");
  });

  it("treats a whitespace-only request as no request", () => {
    assert.equal(nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: "   " }).version, "0.1.4");
  });

  it("accepts any requested version when no tag exists yet", () => {
    assert.equal(nextReleaseVersion({ latestTag: "", packageVersion: "0.1.0", requested: "0.9.0" }).version, "0.9.0");
  });

  it("rejects a requested version that is not plain X.Y.Z", () => {
    for (const bad of ["0.9", "latest", "0.9.0-rc1", "0.9.0.1"]) {
      assert.throws(
        () => nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: bad }),
        /X\.Y\.Z/,
        bad,
      );
    }
  });

  it("rejects a requested version equal to or older than the latest tag", () => {
    for (const bad of ["0.1.3", "0.1.2", "0.0.9"]) {
      assert.throws(
        () => nextReleaseVersion({ latestTag: "v0.1.3", packageVersion: "0.1.0", requested: bad }),
        /greater than/,
        bad,
      );
    }
  });

  it("continues the automatic bump from a requested version after it was tagged", () => {
    assert.equal(nextReleaseVersion({ latestTag: "v0.9.0", packageVersion: "0.1.0", requested: "" }).version, "0.9.1");
  });

  it("rejects a latest tag that is not a plain version", () => {
    assert.throws(
      () => nextReleaseVersion({ latestTag: "v0.1.3-rc1", packageVersion: "0.1.0", requested: "" }),
      /latest tag/,
    );
  });
});
