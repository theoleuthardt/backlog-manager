#!/usr/bin/env node
/**
 * Prepares the Tauri build by copying the Next.js standalone server
 * to the resources directory for bundling
 */

import { cpSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = join(__dirname, '..');

const sourceDir = join(rootDir, '.next/standalone');
const staticDir = join(rootDir, '.next/static');
const publicDir = join(rootDir, 'public');
const targetDir = join(rootDir, 'src-tauri/resources/server');

console.log('📦 Preparing Tauri build...');

mkdirSync(targetDir, { recursive: true });
console.log('✓ Created resources directory');

if (existsSync(sourceDir)) {
  console.log('📋 Copying standalone server...');
  cpSync(sourceDir, targetDir, { recursive: true });
  console.log('✓ Copied standalone server');
} else {
  console.error('❌ Standalone build not found. Run `npm run build` first.');
  process.exit(1);
}

if (existsSync(staticDir)) {
  const targetStatic = join(targetDir, '.next/static');
  console.log('📋 Copying static files...');
  cpSync(staticDir, targetStatic, { recursive: true });
  console.log('✓ Copied static files');
}

if (existsSync(publicDir)) {
  const targetPublic = join(targetDir, 'public');
  console.log('📋 Copying public files...');
  cpSync(publicDir, targetPublic, { recursive: true });
  console.log('✓ Copied public files');
}

console.log('✅ Tauri build preparation complete!');