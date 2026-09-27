// 使い方: node tools/check.ts [ディレクトリ...]
// 仕様のディレクトリ(shop.qntのある場所)を検査する．
// ディレクトリを指定しなければ，すべてのIterationのexercise/とsolution/を検査する．
import { spawnSync } from "node:child_process";
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

// runがnullを返した検査は，対象がないので表示しない．
type Step = { name: string; run: () => string[] | null };

// 反例の始まりを示す行．Apalacheとシミュレーションは前者，TLCは後者を出す．
const COUNTEREXAMPLE_MARKERS = ["An example execution:", "Error: The following behavior constitutes a counter-example:"];

// Quintのコマンドを実行し，失敗したら出力を問題として返す．
// 反例があれば，経過のログを省き，反例から後だけを返す．
function quint(args: string[], dir: string): string[] {
  const { status, output } = runQuint(args, dir);
  if (status === 0) {
    return [];
  }
  const starts = COUNTEREXAMPLE_MARKERS.map((marker) => output.indexOf(marker)).filter((i) => i >= 0);
  const shown = starts.length > 0 ? output.slice(Math.min(...starts)) : output;
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
      // 不変条件は，すべての状態を調べるTLCで検査する．Apalacheより速い．
      // QuintはTLCを呼ぶときにデッドロックの検査を切るので，すべての注文が決まった状態は誤りにならない．
      name: "quint verify",
      run: () => {
        const { invariants } = specProperties(dir);
        if (invariants.length === 0) {
          return [];
        }
        return quint(["verify", "shop.qnt", "--backend=tlc", "--invariants", ...invariants], dir);
      },
    },
    {
      // 時相論理の性質は，すべての状態を調べるTLCで検査する．
      name: "quint verify(時相論理の性質)",
      run: () => {
        const { temporals } = specProperties(dir);
        if (temporals.length === 0) {
          return null;
        }
        return quint(["verify", "shop.qnt", "--backend=tlc", `--temporal=${temporals.join(",")}`], dir);
      },
    },
    {
      // 実装(impl/)があれば，仕様のトレースを流すテストを実行する．
      name: "実装のテスト(Vitest)",
      run: () => {
        const impl = path.join(dir, "impl");
        if (!existsSync(impl)) {
          return null;
        }
        const vitest = path.join(repoRoot, "node_modules/.bin/vitest");
        const result = spawnSync(vitest, ["run", path.relative(repoRoot, impl)], { cwd: repoRoot, encoding: "utf8" });
        return result.status === 0 ? [] : [`${result.stdout}${result.stderr}`.trimEnd()];
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
    const problems = step.run();
    if (problems !== null) {
      report(step.name, problems);
    }
  }
}
process.exit(failed ? 1 : 0);
