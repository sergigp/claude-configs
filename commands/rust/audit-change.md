---
name: "Audit Change"
description: "Audit an implemented OpenSpec change against its design contract, code conventions, correctness, and test strength — auto-fix what is behaviour-preserving, risk-assess the rest, route plan gaps to /opsx:update"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(cargo:*), Agent, Skill
category: "Workflow"
tags: ["workflow", "audit", "review", "experimental"]
---

Audit the code produced by an OpenSpec change against its own design contract, this
project's conventions, correctness, and test strength — after `apply` has produced
code, before (or instead of) `archive`.

**Goal: minimise the user's cognitive load.** Everything that can be fixed without
changing behaviour, and that tests protect, is fixed automatically. Only findings that
need a judgment call reach the user, each with a risk assessment that makes the
decision fast. Never pad the report: an honest short list beats a thorough-looking one.

**Input**: Optionally specify a change name after `/audit-change` (e.g.
`/audit-change add-auth`). If omitted, infer from conversation context; if only one
active change exists, use it; otherwise run `openspec list --json` and ask.

Always announce: "Auditing change: <name>" and how to override.

---

**Steps**

0. **Run all tests**
   Run all tests, including smoke/end-to-end suites if the project has them. All must
   pass to continue. If a test fails, investigate, stop the audit and ask the user. If
   the failing test is a smoke test, rerun it twice to rule out flakiness. A test that
   eventually passes is a `flaky-test` finding, severity `critical`, decide lane.

1. **Resolve the change and its artifacts**

   ```bash
   openspec status --change "<name>" --json
   ```

   Read `design.md`, `tasks.md`, and `proposal.md` from `artifactPaths.*.existingOutputPaths`.
   If `design.md` doesn't follow the `## Files` / `## Types & Signatures` /
   `## Call Stack` / `## Test Plan` structure (see `openspec/config.yaml`
   `rules.design`), record a `no-contract` finding (plan-gap lane) and skip step 3a —
   there's no contract to audit against.

2. **Determine the code in scope**
   - Start from `design.md`'s `## Files` list — that's the declared scope.
   - Determine the explicit diff range for this change and keep it — reuse it in step
     3, don't let each pass re-derive its own: if there's uncommitted work, that's
     `git status --porcelain`; otherwise find where the change's work branched from
     (e.g. `git merge-base main HEAD`) and use `git diff <merge-base>...HEAD`. By audit
     time the change may already be committed or merged, where "the current diff" is
     empty — never rely on that default.
   - Write the diff **once** to a patch file in the scratchpad directory
     (`git diff <range> > <scratchpad>/change.patch`, or `git diff HEAD` plus untracked
     files for uncommitted work). Every later step reads this file; nobody re-derives
     the range.
   - Any file touched by git but absent from `## Files`, or vice versa, is a
     `scope-drift` finding (decide lane).

3. **Run review passes in parallel.** Start the mutation run (e) as a background
   command first, then launch passes a–d as separate subagents in a single message.
   Give each subagent the change name, the artifact content already read in step 1,
   the file scope and the **patch file path** from step 2 — the patch is the review
   target, they must not run git to rediscover it.
   Every pass returns structured findings: `{file, line_or_area, category, summary}`.
   Passes a and c additionally fill the risk fields of step 4 for each finding
   (`trigger, likelihood, impact, self_heals, consequence`) — they have the context;
   `confidence` is set later by step 5, not self-reported.

   **Model and effort per subagent** (pass them explicitly on every `Agent` call;
   subagents otherwise inherit the parent model):

   | pass | model | effort | why |
   |---|---|---|---|
   | a contract | sonnet | medium | mechanical comparison against design.md |
   | b convention | sonnet | high | checklist against a long skill; attention, not insight |
   | c correctness | opus | high | where bugs are found |
   | d simplify | sonnet | medium | noisy suggestions are filtered by the gates |
   | 5 verify | opus | high | the false-positive filter |
   | 6 auto-test | opus | default | tests must follow the strict testing conventions |
   | 6 auto-fix | sonnet | default | mechanical edits, gate 4 catches breakage |

   a. **Contract-adherence** (sonnet, medium) — compare the actual code's types, method signatures,
   and call flow against `design.md`'s `## Types & Signatures` and `## Call Stack`.
   Flag: signatures that don't match, calls that don't happen, calls that happen
   but aren't in the call stack, types missing or renamed without the design being
   updated. `category: contract`.

   b. **Convention-adherence** (sonnet, high) — invoke the `/rust-architect` skill's rules and check
   the changed files against them (layering, naming, fn ordering, port/repository
   conventions, functional style, deliberate-deviations list). `category:
   convention`.

   c. **Correctness** (opus, high) — invoke the `/code-review` skill at high effort, targeting the
   explicit range from step 2 (e.g. `<merge-base>...HEAD`, or the uncommitted
   working tree) — never let it default to "the current diff," which is empty once
   the change is committed or merged. `category: correctness`.

   d. **Simplification / efficiency** (sonnet, medium) — invoke the `/simplify` skill, targeting the
   same explicit range from step 2, in review-only mode (do not let it apply fixes
   itself — step 6 owns the apply step and its gates). `category: simplification`.

   e. **Test strength (mutation testing)** — run as a background Bash command, not a
   subagent, so no agent idles on it:

   ```bash
   cargo mutants --in-diff <scratchpad>/change.patch --jobs <cores/2> --output <scratchpad>/mutants
   ```

   `--in-diff` restricts mutants to lines in the patch, which is the whole point —
   never run it on the full crate. Collect the result when a–d are back. Each surviving
   mutant is a finding with the function and the mutation. `category: test-gap`. Keep
   the full list: step 6 uses it as the coverage map.

4. **Dedup, route every finding to a lane by category, and risk-assess the decide lane.**

   First merge duplicates: passes overlap (simplify and convention on the same code,
   a code-review finding and a surviving mutant on the same branch). Merge by
   file + area, keep the finding with the most information, and the highest-risk
   category if they differ (`correctness` > `contract` > `convention` > `simplification`).

   | category | lane |
   |---|---|
   | `correctness`, `contract`, `scope-drift`, `flaky-test` | **decide** — behaviour findings, the user judges |
   | `convention`, `simplification` | **auto-fix** — behaviour-preserving, applied if the gates pass |
   | `test-gap` | **auto-test** — a test is added if the behaviour matches the design |
   | `no-contract` | **plan-gap** — artifacts are stale, `/opsx:update` reconciles them |

   Every **decide** finding must carry this template. The aggregator rejects a
   finding whose fields are missing or contradict each other.

   ```
   what:        <defect>. Trigger: given <state>, when <event>, then <outcome>
   likelihood:  L3 routine | L2 realistic | L1 contrived
   impact:      I3 permanent/silent | I2 recoverable | I1 cosmetic
   self_heals:  auto (next run/retry) | manual (restart, re-create, delete) | never
   consequence: <max 2 sentences>
   confidence:  confirmed | plausible
   severity:    <derived, see matrix>
   action:      code-fix | plan-gap | undecided
   ```

   - **Trigger is mandatory.** It must be concrete enough to become a failing test. If
     the auditor can't write one, it's a smell, not a defect: cap severity at `medium`.
   - **Likelihood is expected frequency in a running deployment over its lifetime, not
     how hard it is to reproduce on purpose.** A race that needs several things to line
     up once per 100k runs is `L2` for a process that runs continuously; hostile input
     in a single-user tool is `L1`.
     - `L3 routine`: normal path, common input, every run/request.
     - `L2 realistic`: one specific but plausible condition (restart mid-task, upstream
       error, a particular state). Will happen over months.
     - `L1 contrived`: several independent unlikely conditions at once, or a state the
       code can't actually reach.
   - **Impact is about recoverability, not visibility.**
     - `I3 permanent/silent`: data loss or corruption, wrong state persisted, manual
       repair needed, or nobody is told.
     - `I2 recoverable`: visible error or failed task; a retry/restart fixes it, or it
       self-heals on the next run but is visibly wrong meanwhile.
     - `I1 cosmetic`: log noise, wasted work, ordering nit, nothing anyone acts on.
   - **Consistency rules**: `self_heals: auto` ⇒ impact ≤ `I2`. `self_heals: never`
     with persisted state ⇒ `I3`.
   - **Confidence**: set by step 5, never by the pass that found the issue.
     `plausible` caps severity at `medium`.
   - **Severity matrix** (likelihood × impact):

     | | I3 | I2 | I1 |
     |---|---|---|---|
     | L3 | critical | high | medium |
     | L2 | critical | high | low |
     | L1 | high | low | low |

   - **Drop `low` findings entirely** — do not list them; at most say "N low-severity
     items dropped."
   - **Action** is the proposed resolution: `code-fix` when the design is right and the
     code is wrong; `plan-gap` for `contract`/`scope-drift` findings where the
     deviation looks intentional or reasonable (the design missed a case) — the
     artifacts are stale, not the code; `undecided` when it could go either way. Never
     silently pick one.

5. **Verify the decide lane independently.** The pass that found an issue is the
   worst judge of whether it's real. For every decide finding (after dropping `low`),
   launch a fresh subagent (opus, high effort) in parallel, one per finding, with the
   finding, the patch file path and the artifacts, and this brief: *adversarially check the trigger —
   trace the actual code path from `given` to `then`, or write (not commit) a failing
   test; report `confirmed` with the evidence, or `plausible` with what you could not
   establish, or `false-positive` with why.* Apply the result: `false-positive` is
   dropped (count it), `plausible` re-derives severity with the cap, `confirmed`
   keeps it. Scratch tests written for verification are deleted afterwards.

6. **Execute the automatic lanes, before the report.** These only ever produce
   behaviour-preserving, test-protected diffs, which is why they don't wait for the
   user. Do not commit anything; the user reviews with `git diff`.

   **Auto-test first** (it raises the coverage the auto-fix gates rely on). Delegate
   the test writing to an opus subagent with `/rust-architect` loaded. For each
   `test-gap` finding:
   - Mutants on logging, trivial getters or similar non-behaviour: drop.
   - Check the behaviour the mutant touches against `design.md`. Matches → write a test
     that kills the mutant, following `/rust-architect` testing conventions.
   - Doesn't match → do **not** pin it: reclassify as `correctness`, fill the risk
     template, decide lane.

   **Auto-fix next.** Delegate the edits to a sonnet subagent with `/rust-architect`
   loaded; the orchestrator runs the gates. Each `convention` / `simplification`
   finding is applied only if all four gates pass; the first failing gate is recorded
   and the finding is skipped:
   1. **Protected by tests**: no surviving mutant (from step 3e, before the auto-tests
      above) in the code being changed. Unprotected code is never refactored
      automatically.
   2. **No existing test edited**: the fix may add tests but must not change an
      existing assertion. Needing to means behaviour changed → skip, and reclassify as
      a decide-lane finding.
   3. **Not a decision**: not on `/rust-architect`'s deliberate-deviations list, not a
      type/signature named in `design.md` (that's `plan-gap`, not a fix), and the
      resulting code itself follows `/rust-architect` conventions.
   4. **Still green**: `cargo test`, `cargo clippy --all-targets --all-features -- -D
      warnings` and `cargo fmt --check` pass after the fix.

   Gates 1–3 are checked per finding. Gate 4 is **batched**: apply every finding that
   passed 1–3 (sequentially, one editor, no parallel agents in the working tree), run
   the checks once. Green → all applied. Red → revert all, re-apply one at a time with
   the checks after each, skipping the ones that fail. Most batches are green, so
   this is one test run instead of one per finding.

7. **Present the report. Stop here and wait for direction.**

   ```markdown
   ## Audit: <change-name>

   ### Needs your decision (N) — critical first

   1. [correctness · critical · code-fix] <file>:<line> — <summary>
      **What**: <defect>. Trigger: given <state>, when <event>, then <outcome>.
      **Risk**: L2 realistic · I3 permanent · self-heals: never · confirmed
      **If we don't fix it**: <max 2 sentences>

   2. [contract · high · plan-gap] <file>:<line> — <summary>
      ...

   ### Plan gaps (K)

   - [no-contract] design.md has no `## Types & Signatures` section

   ### Auto-fixed (M)

   - [convention] <file> — <one line>
   - [test-gap] <file> — added `it_should_<...>`

   ### Skipped (S) — failed a gate

   - [simplification] <file> — <one line> · gate 1: `fn foo` has surviving mutants

   _(P low-severity items dropped, F false positives discarded by verification.)_
   ```

   Ask: "Apply the `code-fix` items? Hand the `plan-gap` items to `/opsx:update`?
   Accept any as deliberate?" Offer all, together or separately.

8. **On confirmation, act per action:**
   - **code-fix**: apply directly, minimal and scoped to each finding, same discipline
     as `/opsx:apply` (don't drift into unrelated cleanup). Run the gate-4 checks.
   - **plan-gap**: invoke `/opsx:update <name>` inline, passing the plan-gap findings
     as the description of what changed. Let `update` do its normal
     read-reconcile-confirm flow — this command does not edit `design.md`/`tasks.md`/
     specs itself. If `update` changes `tasks.md`, tell the user to re-run
     `/opsx:apply "<name>"`, then suggest re-running `/audit-change "<name>"`.
   - **accept** (the user rejects a finding as a deliberate choice): record it so it is
     never re-flagged — a decision note in `design.md` for change-specific choices, or
     the project's `/rust-architect` deliberate-deviations section for project-wide
     ones. Confirm the wording with the user before writing.

**Guardrails**

- Steps 0–5 are read-only (step 5's scratch tests are removed before step 6). Step 6
  edits code but only through the automatic lanes and their gates; never apply a
  decide-lane finding before the user has seen the report.
- Compute the diff once (step 2) and pass the patch file around; a subagent that
  runs its own `git diff` is a bug in the prompt you gave it.
- Never commit. The user reviews automatic fixes with `git diff`.
- Plan-gap findings are never applied to code directly by this command — only by
  `/opsx:update` reconciling artifacts, followed by a normal `/opsx:apply` pass.
- If `design.md` isn't in the four-section contract format, say so and don't fabricate
  a contract comparison — report it as a `no-contract` finding instead.
- Keep findings concrete (file + line/area + trigger), not vague prose.
- Severity is derived from the matrix, never assigned by feel. A technically-true
  defect with a contrived trigger and no lasting damage is `low` and dropped — that
  is the intended behaviour, not a loss.
- Keep this command project-agnostic: no references to a specific project's domain,
  only to `/rust-architect`, OpenSpec and cargo.
