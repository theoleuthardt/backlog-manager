/**
 * Generates the Ed25519 key pair of the in-place updater.
 *
 * Usage: node scripts/app-update-keygen.mjs
 *
 * The private line goes into the repository secret APP_UPDATE_PRIVATE_KEY
 * and nowhere else; the public line goes into
 * app/lib/data/update_public_key.dart. See docs/APP_UPDATES.md.
 */
import { generateKeyPairSync } from "node:crypto";

const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const seed = privateKey.export({ format: "der", type: "pkcs8" }).subarray(-32);
const raw = publicKey.export({ format: "der", type: "spki" }).subarray(-32);

console.log(`private (APP_UPDATE_PRIVATE_KEY): ${seed.toString("base64")}`);
console.log(`public (update_public_key.dart):  ${raw.toString("base64")}`);
