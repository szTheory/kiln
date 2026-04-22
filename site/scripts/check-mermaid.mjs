#!/usr/bin/env node
/**
 * Syntax-only Mermaid validation (no headless Chrome).
 * Fails the process if any fenced ```mermaid block in src/content/docs is invalid.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><html><body></body></html>", { url: "http://localhost" });
globalThis.window = dom.window;
globalThis.document = dom.window.document;

const { default: mermaid } = await import("mermaid");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const docsRoot = path.join(root, "src", "content", "docs");

function* walkMarkdownFiles(dir) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) yield* walkMarkdownFiles(p);
    else if (ent.isFile() && ent.name.endsWith(".md")) yield p;
  }
}

mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });

let count = 0;
const blockRe = /^```mermaid\n(.*?)\n```/gms;

for (const file of walkMarkdownFiles(docsRoot)) {
  const text = fs.readFileSync(file, "utf8");
  for (const m of text.matchAll(blockRe)) {
    const block = m[1].trim();
    if (!block) continue;
    count++;
    try {
      await mermaid.mermaidAPI.getDiagramFromText(block);
    } catch (e) {
      console.error(`Invalid Mermaid in ${path.relative(root, file)}:\n${e?.message || e}`);
      process.exit(1);
    }
  }
}

console.log(`check-mermaid: validated ${count} diagram block(s)`);
