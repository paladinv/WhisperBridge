import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import { dataDirectory } from "../src/modelStore";

test("uses the explicit data directory for development and tests", () => {
  assert.equal(
    dataDirectory({ WHISPERBRIDGE_DATA_DIR: "./.build-artifacts/plugin-data" }),
    path.resolve("./.build-artifacts/plugin-data")
  );
});
