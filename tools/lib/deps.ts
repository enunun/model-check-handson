// Quint本体が使う評価器とApalacheが，QUINT_HOMEに置かれているかを確かめる．
// 版はQuint本体に埋め込まれているので，Quintの版を上げたらDockerfileの版も上げる．
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import path from "node:path";

const require = createRequire(import.meta.url);

export function checkQuintDeps(): string[] {
  const quintDist = path.dirname(require.resolve("@informalsystems/quint/dist/src/config.js"));
  const { QUINT_EVALUATOR_VERSION } = require(path.join(quintDist, "rust/binaryManager.js")) as {
    QUINT_EVALUATOR_VERSION: string;
  };
  const { DEFAULT_APALACHE_VERSION_TAG } = require(path.join(quintDist, "apalache.js")) as {
    DEFAULT_APALACHE_VERSION_TAG: string;
  };
  const quintHome = process.env.QUINT_HOME ?? path.join(homedir(), ".quint");
  const expected = [
    path.join(quintHome, `rust-evaluator-${QUINT_EVALUATOR_VERSION}`, "quint_evaluator"),
    path.join(quintHome, `apalache-dist-${DEFAULT_APALACHE_VERSION_TAG}`, "apalache", "lib", "apalache.jar"),
  ];
  return expected
    .filter((file) => !existsSync(file))
    .map(
      (file) =>
        `${file}がない．Dockerfileの版(評価器${QUINT_EVALUATOR_VERSION}，Apalache ${DEFAULT_APALACHE_VERSION_TAG})を確かめる．`,
    );
}
