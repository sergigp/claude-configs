---
name: "Audit Change"
description: "Audit an implemented OpenSpec change against its design contract, code conventions, correctness, and test strength — then route findings to a code fix or /opsx:update"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(cargo:*), Agent, Skill
category: "Workflow"
tags: ["workflow", "audit", "review", "experimental"]
---

Audit the code produced by an OpenSpec change against its own design contract, this
project's conventions, correctness, and test strength — after `apply` has produced
code, before (or instead of) `archive`.

**This is read-only investigation until step 6.** Never edit code or artifacts before
the user has seen the findings and told you how to proceed.

**Input**: Optionally specify a change name after `/audit-change` (e.g.
`/audit-change add-auth`). If omitted, infer from conversation context; if only one
active change exists, use it; otherwise run `openspec list --json` and ask.

Always announce: "Auditing change: <name>" and how to override.

---

**Steps**

0. **Run all tests**
   Run all tests, including smoke tests. All tests should pass to continue to step one. If some test is failing investigate what is failing and stop the audit and ask for user input on what to do. If the test that fails is a smoke test, rerun them twice, just to make sure it's not a flaky one. If there is a flaky test that eventually pass mention it in the report as CRITICAL.

1. **Resolve the change and its artifacts**

   ```bash
   openspec status --change "<name>" --json
   ```

   Read `design.md`, `tasks.md`, and `proposal.md` from `artifactPaths.*.existingOutputPaths`.
   If `design.md` doesn't follow the `## Files` / `## Types & Signatures` /
   `## Call Stack` / `## Test Plan` structure (see `openspec/config.yaml`
   `rules.design`), note that as a finding itself — there's no contract to audit
   against — and skip step 3a for this run.

2. **Determine the code in scope**
   - Start from `design.md`'s `## Files` list — that's the declared scope.
   - Determine the explicit diff range for this change and keep it — reuse it in step
     3, don't let each pass re-derive its own: if there's uncommitted work, that's
     `git status --porcelain`; otherwise find where the change's work branched from
     (e.g. `git merge-base main HEAD`) and use `git diff <merge-base>...HEAD`. By audit
     time the change may already be committed or merged, where "the current diff" is
     empty — never rely on that default.
   - Any file touched by git but absent from `## Files`, or vice versa, is itself a
     **contract-drift finding** — the code and the design have already diverged.

3. **Run review passes in parallel.** Launch these as separate subagents in a single
   message (they don't depend on each other). Give each one the change name, the
   relevant artifact content already read in step 1, and the file scope from step 2.
   Ask each to return structured findings: `{file, line_or_area, summary,
category, verdict: wrong|improvement, severity: high|medium|low}` — see step 4
   for what verdict and severity mean.

   a. **Contract-adherence** — compare the actual code's types, method signatures,
   and call flow against `design.md`'s `## Types & Signatures` and `## Call Stack`.
   Flag: signatures that don't match, calls that don't happen, calls that happen
   but aren't in the call stack, types missing or renamed without the design being
   updated. `category: contract`.

   b. **Convention-adherence** — invoke the `/rust-architect` skill's rules and check
   the changed files against them (layering, naming, fn ordering, port/repository
   conventions, functional style, deliberate-deviations list). `category:
   convention`.

   c. **Correctness** — invoke the `/code-review` skill at high effort, targeting the
   explicit range from step 2 (e.g. `<merge-base>...HEAD`, or the uncommitted
   working tree) — never let it default to "the current diff," which is empty once
   the change is committed or merged. `category: correctness`.

   d. **Simplification / efficiency** — invoke the `/simplify` skill, targeting the
   same explicit range from step 2, in review-only mode (do not let it apply fixes
   itself — this command owns the apply step). `category: simplification`.

   e. **Test strength (mutation testing)** — run `cargo mutants` scoped to the
   changed package/files (check `cargo mutants --help` for scoping flags such as
   `--file`). Report surviving mutants as findings: a mutant that survives means
   no test caught that behavior change. `category: test-gap`.

4. **Aggregate and classify every finding — twice, on two independent axes.**

   **Axis 1 — verdict (mandatory, exactly one per finding):**
   - **Wrong** — the code misbehaves: it violates the design contract, produces
     incorrect behavior, or has a test gap that lets a real behavior change ship
     undetected (a surviving mutant on meaningful logic counts). "Wrong" means the
     current code can do the wrong thing, not that it's merely unidiomatic.
   - **Improvement** — the code behaves correctly today but could be better
     (convention deviations, simplifications, efficiency, style). Each improvement
     gets a severity:
     - **HIGH** — likely to cause a real bug or significant friction soon (e.g. a
       trap the next contributor will fall into, a convention break that hides
       logic, a test so weak it will rot immediately).
     - **MEDIUM** — worth fixing when touching this code; low risk if deferred.
     - **LOW** — cosmetic or taste-level. **Drop LOW findings entirely — do not
       list them in the report**; at most mention "N low-severity items dropped."

   **Axis 2 — lane (routing, exactly one per finding):**
   - **Code-fix** — `correctness`, `convention`, `simplification`, `test-gap`
     findings, and any `contract` finding where the code is simply wrong relative to
     an unchanged, still-correct design.
   - **Plan-gap** — any `contract` finding where the code's deviation looks
     _intentional or reasonable_ (the design missed a case, or an edge case forced a
     different shape than planned). These mean the artifacts are stale, not the code.

   When a finding's lane could go either way, say so explicitly in the report and
   let the user decide — do not silently pick one.

5. **Present the report. Stop here and wait for direction.**

   ```markdown
   ## Audit: <change-name>

   ### Wrong (N)

   1. [correctness · code-fix] <file>:<line> — <summary>
      **What**: <one or two sentences of plain english — no jargon dumps>
      **If we don't fix it**: <the concrete tradeoff: what can break, when, and
      how visible it would be — so the user can judge whether fixing pays off>

   ### Improvements — HIGH (M)

   1. [convention · code-fix] <file>:<line> — <summary>
      **What**: <plain english>
      **If we don't fix it**: <concrete tradeoff, same as above>

   ### Improvements — MEDIUM (K)

   1. [simplification · code-fix] <file>:<line> — <summary>

   _(P low-severity items dropped.)_
   ```

   The **What** / **If we don't fix it** lines are mandatory for every Wrong and
   every HIGH item — that pair is the point of the report: it lets the user judge
   whether the fix pays off. MEDIUM items stay one-liners. Plan-gap findings appear
   in whichever verdict section they earned, tagged `· plan-gap`.

   Ask: "Apply the code-fix findings directly? Hand the plan-gap findings to
   `/opsx:update` to reconcile the artifacts?" Offer both, together or separately.

6. **On confirmation, act per lane:**
   - **Code-fix**: apply directly, minimal and scoped to each finding, same
     discipline as `/opsx:apply` (don't drift into unrelated cleanup).
   - **Plan-gap**: invoke `/opsx:update <name>` inline, passing the plan-gap findings
     as the description of what changed. Let `update` do its normal
     read-reconcile-confirm flow — this command does not edit `design.md`/`tasks.md`/
     specs itself.
   - If `update` ends up changing `tasks.md` (new or revised tasks), tell the user to
     re-run `/opsx:apply "<name>"` to implement the delta, then suggest re-running
     `/audit-change "<name>"` afterward if the change is nontrivial.

**Guardrails**

- Never edit code or artifacts before the user has seen the report (steps 0-5 are
  read-only).
- Plan-gap findings are never applied to code directly by this command — only by
  `/opsx:update` reconciling artifacts, followed by a normal `/opsx:apply` pass.
- If `design.md` isn't in the four-section contract format, say so and don't fabricate
  a contract comparison — report it as a finding instead.
- Keep findings concrete (file + line/area), not vague prose.
- Don't inflate severity to make the report look thorough — an honest MEDIUM beats
  a padded HIGH, and dropping LOW items is the intended behavior, not a loss.
- This command is new/experimental — its subagent prompts and lane classification are
  a first cut; expect to tune them after seeing real output.
