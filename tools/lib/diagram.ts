// 仕様のトレースから，注文の状態(変数orderStatus)の状態遷移図を作る．
import { mkdtempSync, readdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { declarations, runQuintOrThrow } from "./quint.ts";

const STATUS_VAR = "orderStatus";

// トレースの本数と長さ．遷移を取りこぼさないよう，十分に大きく取る．
const SAMPLES = 300;
const MAX_STEPS = 20;
const SEED = "1";

const HEADER = `# 状態遷移図

注文の状態(\`${STATUS_VAR}\`)がどのアクションでどう変わるかを示す．
このファイルは，仕様のトレースから\`mise run diagram\`で生成する．手で編集しない．
`;

type ItfValue = unknown;
type ItfState = Record<string, ItfValue>;

// バリアント型の値はタグ名，それ以外はJSONの文字列で表す．
function label(value: ItfValue): string {
  if (typeof value === "object" && value !== null && "tag" in value) {
    return String((value as { tag: unknown }).tag);
  }
  return JSON.stringify(value);
}

// ITF形式の#mapを，キーの文字列から状態名への対応にする．
function statusMap(state: ItfState): Map<string, string> {
  const raw = state[STATUS_VAR] as { "#map": [ItfValue, ItfValue][] };
  return new Map(raw["#map"].map(([key, value]) => [JSON.stringify(key), label(value)]));
}

function collectTransitions(traceDir: string): string[] {
  const edges = new Set<string>();
  for (const file of readdirSync(traceDir)) {
    const trace = JSON.parse(readFileSync(path.join(traceDir, file), "utf8")) as {
      states: ItfState[];
    };
    for (const status of statusMap(trace.states[0]).values()) {
      edges.add(`[*] --> ${status}`);
    }
    for (let i = 1; i < trace.states.length; i++) {
      const before = statusMap(trace.states[i - 1]);
      const after = statusMap(trace.states[i]);
      const action = String(trace.states[i]["mbt::actionTaken"]);
      for (const [key, status] of after) {
        const previous = before.get(key);
        if (previous === undefined) {
          edges.add(`[*] --> ${status} : ${action}`);
        } else if (previous !== status) {
          edges.add(`${previous} --> ${status} : ${action}`);
        }
      }
    }
  }
  // 始点([*])からの遷移を先に並べる．
  const start = (edge: string) => (edge.startsWith("[*]") ? 0 : 1);
  return [...edges].sort((a, b) => start(a) - start(b) || a.localeCompare(b));
}

// 生成したファイルの内容を返す．orderStatusのない仕様では，図の説明だけを返す．
export function renderDiagram(dir: string): string {
  const hasStatus = declarations(path.join(dir, "shop.qnt"), "shop").some(
    (d) => d.kind === "var" && d.name === STATUS_VAR,
  );
  if (!hasStatus) {
    return `${HEADER}
仕様に変数\`${STATUS_VAR}\`(注文から状態への対応)を定義すると，ここに図が生成される．
`;
  }
  const traceDir = mkdtempSync(path.join(tmpdir(), "quint-traces-"));
  runQuintOrThrow(
    [
      "run",
      "shop.qnt",
      "--mbt",
      `--max-samples=${SAMPLES}`,
      `--n-traces=${SAMPLES}`,
      `--max-steps=${MAX_STEPS}`,
      `--seed=${SEED}`,
      `--out-itf=${path.join(traceDir, "{seq}.itf.json")}`,
    ],
    dir,
  );
  const lines = collectTransitions(traceDir).map((edge) => `  ${edge}`);
  return `${HEADER}
\`\`\`mermaid
stateDiagram-v2
${lines.join("\n")}
\`\`\`
`;
}
