// 使い方: node tools/check-mermaid.ts [ファイル...]
// Markdownの中のMermaidの図を構文解析し，壊れた図を報告する．
// ファイルを指定しなければ，Gitが管理するすべてのMarkdownを検査する．
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><html><body></body></html>");
Object.assign(globalThis, { window: dom.window, document: dom.window.document });
const { default: mermaid } = await import("mermaid");

const files =
  process.argv.length > 2
    ? process.argv.slice(2)
    : execFileSync("git", ["ls-files", "*.md"], { encoding: "utf8" }).split("\n").filter(Boolean);

let failures = 0;
for (const file of files) {
  const text = readFileSync(file, "utf8");
  for (const match of text.matchAll(/^```mermaid\n([\s\S]*?)^```/gm)) {
    const line = text.slice(0, match.index).split("\n").length;
    try {
      await mermaid.parse(match[1]);
    } catch (error) {
      failures++;
      console.error(`${file}:${line}: ${(error as Error).message.split("\n")[0]}`);
    }
  }
}
process.exit(failures === 0 ? 0 : 1);
