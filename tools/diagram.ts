// 使い方: node tools/diagram.ts <ディレクトリ>
// 指定したディレクトリのstate-diagram.mdを，仕様のトレースから生成し直す．
import { writeFileSync } from "node:fs";
import path from "node:path";
import { renderDiagram } from "./lib/diagram.ts";

const dir = process.argv[2];
if (!dir) {
  console.error("使い方: node tools/diagram.ts <ディレクトリ>");
  process.exit(2);
}
const file = path.join(dir, "state-diagram.md");
writeFileSync(file, renderDiagram(dir));
console.log(`${file}を生成した．`);
