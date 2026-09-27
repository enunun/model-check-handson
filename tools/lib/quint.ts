// Quintのコマンドを，リポジトリに固定した版で実行する．
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const repoRoot = path.resolve(import.meta.dirname, "../..");
const quintBin = path.join(repoRoot, "node_modules/.bin/quint");

export type RunResult = { status: number; output: string };

export function runQuint(args: string[], cwd: string): RunResult {
  const result = spawnSync(quintBin, args, { cwd, encoding: "utf8" });
  if (result.error) {
    throw result.error;
  }
  return {
    status: result.status ?? 1,
    output: `${result.stdout}${result.stderr}`,
  };
}

// 失敗したら，Quintの出力を添えて例外にする．
export function runQuintOrThrow(args: string[], cwd: string): string {
  const { status, output } = runQuint(args, cwd);
  if (status !== 0) {
    throw new Error(`quint ${args.join(" ")} が失敗した．\n${output}`);
  }
  return output;
}

export type Declaration = { kind: string; qualifier?: string; name: string };

// `quint parse`の結果から，指定したモジュールの宣言を取り出す．
export function declarations(specFile: string, moduleName: string): Declaration[] {
  const outDir = mkdtempSync(path.join(tmpdir(), "quint-parse-"));
  const outFile = path.join(outDir, "parsed.json");
  runQuintOrThrow(["parse", path.basename(specFile), "--out", outFile], path.dirname(specFile));
  const parsed = JSON.parse(readFileSync(outFile, "utf8")) as {
    modules: { name: string; declarations: Declaration[] }[];
  };
  const found = parsed.modules.find((m) => m.name === moduleName);
  if (!found) {
    throw new Error(`${specFile}にモジュール${moduleName}がない．`);
  }
  return found.declarations;
}
