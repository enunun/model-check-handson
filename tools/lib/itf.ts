// Quintのトレース(ITF形式)を生成し，TypeScriptの値に変換する．
// モデルベーステストで，トレースを実装に流すときに使う．
import { mkdtempSync, readdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { runQuintOrThrow } from "./quint.ts";

// ITFの値をTypeScriptの値に変換したもの．
// 整数はnumber，マップはMap，集合はSet，タプルは配列，バリアントは{ tag, value }になる．
export type Value =
  | number
  | string
  | boolean
  | Value[]
  | Map<Value, Value>
  | Set<Value>
  | { tag: string; value: Value };

export type TraceState = {
  // このステップで起きたアクションの名前．
  action: string;
  // アクションで非決定的に選ばれた値．選ばれなかった名前は含まない．
  picks: Record<string, Value>;
  // 状態変数の値．
  vars: Record<string, Value>;
};

export function decode(raw: unknown): Value {
  if (typeof raw === "string" || typeof raw === "boolean") {
    return raw;
  }
  if (typeof raw === "number") {
    return raw;
  }
  if (Array.isArray(raw)) {
    return raw.map(decode);
  }
  const obj = raw as Record<string, unknown>;
  if ("#bigint" in obj) {
    return Number(obj["#bigint"]);
  }
  if ("#map" in obj) {
    return new Map((obj["#map"] as [unknown, unknown][]).map(([k, v]) => [decode(k), decode(v)]));
  }
  if ("#set" in obj) {
    return new Set((obj["#set"] as unknown[]).map(decode));
  }
  if ("#tup" in obj) {
    return (obj["#tup"] as unknown[]).map(decode);
  }
  if ("tag" in obj) {
    return { tag: String(obj.tag), value: decode(obj.value) };
  }
  throw new Error(`ITFの値を変換できない：${JSON.stringify(raw)}`);
}

// mbt::nondetPicksの値はOption型(Some/None)なので，選ばれた値だけを取り出す．
function decodePicks(raw: unknown): Record<string, Value> {
  const picks: Record<string, Value> = {};
  for (const [name, option] of Object.entries(raw as Record<string, { tag: string; value: unknown }>)) {
    if (option.tag === "Some") {
      picks[name] = decode(option.value);
    }
  }
  return picks;
}

export function readTrace(file: string): TraceState[] {
  const trace = JSON.parse(readFileSync(file, "utf8")) as { states: Record<string, unknown>[] };
  return trace.states.map((state) => {
    const vars: Record<string, Value> = {};
    for (const [name, value] of Object.entries(state)) {
      if (!name.startsWith("#") && !name.startsWith("mbt::")) {
        vars[name] = decode(value);
      }
    }
    return {
      action: String(state["mbt::actionTaken"]),
      picks: decodePicks(state["mbt::nondetPicks"]),
      vars,
    };
  });
}

export type TraceOptions = { traces: number; maxSteps: number; seed: string };

// 仕様からランダムシミュレーションでトレースを生成し，読み込む．
export function generateTraces(specFile: string, options: TraceOptions): TraceState[][] {
  const outDir = mkdtempSync(path.join(tmpdir(), "quint-mbt-"));
  runQuintOrThrow(
    [
      "run",
      path.basename(specFile),
      "--mbt",
      `--max-samples=${options.traces}`,
      `--n-traces=${options.traces}`,
      `--max-steps=${options.maxSteps}`,
      `--seed=${options.seed}`,
      `--out-itf=${path.join(outDir, "{seq}.itf.json")}`,
    ],
    path.dirname(specFile),
  );
  return readdirSync(outDir)
    .sort()
    .map((file) => readTrace(path.join(outDir, file)));
}
