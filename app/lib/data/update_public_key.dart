/// The Ed25519 public key (base64, the raw 32 bytes) that signed installers
/// must verify against. Empty until the key pair of the project was created
/// (`node scripts/app-update-keygen.mjs`, docs/APP_UPDATES.md); with no key the
/// app never installs a payload and only points at the release page.
const updatePublicKeyBase64 = '';
