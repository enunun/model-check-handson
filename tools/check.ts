// 使い方: node tools/check.ts [ディレクトリ...]
// 仕様のディレクトリ(shop.qntのある場所)を検査する．
// ディレクトリを指定しなければ，すべてのIterationのexercise/とsolution/を検査する．
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { checkQuintDeps } from "./lib/deps.ts";
import { renderDiagram } from "./lib/diagram.ts";
import { compareProperties, specProperties } from "./lib/properties.ts";
import { runQuint } from "./lib/quint.ts";

const repoRoot = path.resolve(import.meta.dirname, "..");

function allSpecDirs(): string[] {
  const iterations = path.join(repoRoot, "iterations");
  if (!existsSync(iterations)) {
    return [];
  }
  return readdirSync(iterations)
    .filter((name) => /^iteration-\d+$/.test(name))
    .sort((a, b) => Number(a.split("-")[1]) - Number(b.split("-")[1]))
    .flatMap((name) => ["exercise", "solution"].map((kind) => path.join(iterations, name, kind)));
}

type Step = { name: string; run: () => string[] };

// Quintのコマンドを実行し，失敗したら出力を問題として返す．
// 反例があれば，Apalacheの経過のログを省き，反例から後だけを返す．
function quint(args: string[], dir: string): string[] {
  const { status, output } = runQuint(args, dir);
  if (status === 0) {
    return [];
  }
  const start = output.indexOf("An example execution:");
  const shown = start >= 0 ? output.slice(start) : output;
  return [
    shown
      .split("\n")
      .filter((line) => !/^(Picked up JAVA_TOOL_OPTIONS|WARNING: |As of 20|[A-Z][a-z]{2} \d+, \d{4})/.test(line))
      .join("\n")
      .trimEnd(),
  ];
}

function steps(dir: string): Step[] {
  return [
    { name: "quint typecheck", run: () => quint(["typecheck", "shop_test.qnt"], dir) },
    { name: "quint test", run: () => quint(["test", "shop_test.qnt"], dir) },
    { name: "性質名の照合", run: () => compareProperties(dir) },
    {
      name: "quint verify",
      run: () => {
        const { invariants, temporals } = specProperties(dir);
        if (invariants.length === 0 && temporals.length === 0) {
          return [];
        }
        // すべての注文が決まり，動けるアクションがなくなった状態は誤りとして扱わない．
        const args = ["verify", "shop.qnt", `--apalache-config=${path.join(repoRoot, "tools/apalache.json")}`];
        if (invariants.length > 0) args.push("--invariants", ...invariants);
        if (temporals.length > 0) args.push(`--temporal=${temporals.join(",")}`);
        return quint(args, dir);
      },
    },
    {
      name: "状態遷移図",
      run: () => {
        const file = path.join(dir, "state-diagram.md");
        const committed = existsSync(file) ? readFileSync(file, "utf8") : "";
        return committed === renderDiagram(dir)
          ? []
          : [`${path.relative(repoRoot, file)}が仕様と一致しない．mise run diagram ${path.relative(repoRoot, dir)}で生成し直す．`];
      },
    },
  ];
}

let failed = false;
function report(name: string, problems: string[]) {
  console.log(`${problems.length === 0 ? "ok  " : "NG  "}${name}`);
  for (const problem of problems) {
    console.log(problem.replace(/^/gm, "      "));
  }
  failed ||= problems.length > 0;
}

report("Quintの評価器とApalache", checkQuintDeps());
const dirs = process.argv.length > 2 ? process.argv.slice(2).map((d) => path.resolve(d)) : allSpecDirs();
for (const dir of dirs) {
  console.log(`\n${path.relative(repoRoot, dir)}`);
  for (const step of steps(dir)) {
    report(step.name, step.run());
  }
}
process.exit(failed ? 1 : 0);
