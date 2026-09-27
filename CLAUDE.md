# model-check-handson

A Japanese hands-on course on model checking with Quint. Learners turn incomplete requirements for an EC shop into Quint specs, find gaps through counterexamples, decide the behavior, and feed it back into the requirements. `COURSE.md` holds the course plan and conventions; `docs/ROADMAP.md` defines what each Iteration builds.

# RTK (Rust Token Killer)

Prefix every shell command with `rtk`, including each command in an `&&` chain — it is always safe (a dedicated filter cuts noisy output for tests, builds, git, and more; anything without one passes through unchanged). The full command reference is in the global `~/.claude/RTK.md` (already loaded, if set up). Meta commands: `rtk gain` (savings so far), `rtk discover` (missed opportunities in past sessions), `rtk proxy <cmd>` (run unfiltered, for debugging).

## Working conventions

- `git commit` runs the lefthook hooks. If they fail, fix the reported issues. Do not use `--no-verify`.

- Run `mise run check` after making changes.

## Code map

- `COURSE.md`: course plan for builders (audience, file conventions, model answers, pitfalls).
- `docs/`: learner guides (`ROADMAP.md`, `method.md`), formal-methods basics (`concepts/`), Quint syntax notes per Iteration (`quint/`).
- `iterations/iteration-N/{exercise,solution}/`: `requirements.md`, `shop.qnt`, `shop_test.qnt`, generated `state-diagram.md`, and the Iteration's `README.md` and `docs/`.
- `tools/`: TypeScript check scripts run by Node directly (`check.ts`, `diagram.ts`, `check-mermaid.ts`).

# Artifact Cleanup

## Golden Rule

**Whenever you produce an artifact, always run the `system-development-skills:finalize-artifacts` skill to clean it up before reporting the work as done.**

An artifact is any deliverable you create or substantially rewrite: documents, READMEs, code and code comments, config files, scripts, commit messages, PR descriptions, and so on.

- Invoke the skill via the Skill tool (`system-development-skills:finalize-artifacts`) after the artifact is written and before the final reply.
- The skill edits the artifact files in place. Do not append a changelog of the cleanup to the artifact; in the final reply, mention what changed in a sentence or two at most unless the user asks for a full report.
- Skip it only for replies that produce no artifact (answering questions, explaining code, running read-only commands).
- Provided by the `enunun/system-development-skills` plugin (see `extraKnownMarketplaces`/`enabledPlugins` in `.claude/settings.json`).
