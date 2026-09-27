// 仕様(shop.qnt)の性質と，要求文(requirements.md)が参照する性質名を集める．
import { readFileSync } from "node:fs";
import path from "node:path";
import { declarations } from "./quint.ts";

export type Properties = { invariants: string[]; temporals: string[] };

// 不変条件は`inv`，時相論理の性質は`live`で始まる名前にする．
export function specProperties(dir: string): Properties {
  const decls = declarations(path.join(dir, "shop.qnt"), "shop");
  const names = (qualifiers: string[], prefix: string) =>
    decls
      .filter((d) => d.kind === "def" && qualifiers.includes(d.qualifier ?? ""))
      .map((d) => d.name)
      .filter((name) => new RegExp(`^${prefix}[A-Z]`).test(name))
      .sort();
  return {
    invariants: names(["val"], "inv"),
    temporals: names(["temporal"], "live"),
  };
}

// 決定事項の行末に`(性質：invA，liveB)`の形で書かれた性質名を集める．
export function referencedProperties(dir: string): string[] {
  const text = readFileSync(path.join(dir, "requirements.md"), "utf8");
  const names = new Set<string>();
  for (const match of text.matchAll(/\(性質：([^)]*)\)/g)) {
    for (const name of match[1].split(/[,，]/)) {
      names.add(name.trim());
    }
  }
  return [...names].sort();
}

// 仕様と要求文の性質名が過不足なく一致しなければ，食い違いを返す．
export function compareProperties(dir: string): string[] {
  const { invariants, temporals } = specProperties(dir);
  const inSpec = new Set([...invariants, ...temporals]);
  const inRequirements = new Set(referencedProperties(dir));
  const problems: string[] = [];
  for (const name of inRequirements) {
    if (!inSpec.has(name)) {
      problems.push(`requirements.mdが参照する${name}が，shop.qntにない．`);
    }
  }
  for (const name of inSpec) {
    if (!inRequirements.has(name)) {
      problems.push(`shop.qntの${name}を，requirements.mdのどの決定事項も参照していない．`);
    }
  }
  return problems;
}
