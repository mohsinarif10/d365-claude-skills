---
name: dataverse-pre-pr
description: Pre-pull-request check for Dynamics 365 / Dataverse repos that keep unpacked solutions in source control. Exports and unpacks every solution from the dev environment so configuration built in the maker is not left out, packs the zips, accounts for every changed file, and checks code conventions, then shows a status table. Use before raising a PR on a Dataverse repo, or when the user says "pre-PR check" or "did I export everything".
---

# Dataverse pre-PR check

The most common Dataverse PR defect is not bad code: it is **configuration built in Dev that never reached the repo**. New columns, renamed choices, status reasons, BPFs, security role privileges, app components and views do not appear in source by writing code. A PR that ships plugins without their schema installs fine and then fails in test.

Run the checks below, **show the table, and stop**. Do not push, raise the PR or touch work items until the user says so.

## First, learn the repo

Look before assuming. Find:
- the solutions folder and every solution in it (`**/Other/Solution.xml`, or `*.cdsproj`)
- any existing export tasks or scripts (`.vscode/tasks.json`, `build/`, `pipelines/`) — reuse their exact `pac` arguments
- the branch naming and commit message convention (read `git log --oneline -20` and any CONTRIBUTING/README)
- the publisher prefix (from `Solution.xml` → `CustomizationPrefix`)

## Checks

1. **Branch** — not the default/integration branch. Name follows the repo's convention. Integration branch fetched and merged recently.
2. **pac auth** — `pac org who` points at the **dev** environment, not test or prod. Tokens can expire under conditional access; re-run `pac auth create --environment <url>` if needed.
3. **Export every solution**, not just the obvious one:
   ```
   pac solution export --name <Solution> --path <tmp>/<Solution>.zip --managed false
   pac solution unpack --zipfile <tmp>/<Solution>.zip --folder <repo>/<Solution> --allowDelete true
   ```
   Skip version bumps when the goal is only to sync source with Dev.
4. **Pack** — if the repo commits packed zips, `pac solution pack` for each changed solution so they match the unpacked source.
5. **Account for every file in `git status`.** Expected churn: `Other/Relationships*`, `Customizations.xml`, `Solution.xml`, canvas app files whose hashed names change on every export (one delete + one add). Anything else must map to this work. **Flag files that look like someone else's Dev work** — never silently include or revert them.
6. **Duplicate ids** in unpacked XML after a merge (app module and sitemap files are prone to doubled components).
7. **Which solution holds what** — confirm each change landed in the solution the team expects (e.g. tables/forms/views vs. flows/BPFs vs. plugin steps vs. security roles vs. app modules). A component added to the wrong solution deploys in the wrong order.
8. **New table or BPF?** Run the `dataverse-new-component-checklist` skill — security role privileges and app components are the usual misses.
9. **Code conventions** in the diff:
   - no hand-written logical-name string constants where the repo uses early-bound classes — regenerate the early-bound model instead
   - new schema names follow the repo convention (check existing ones; schema names **cannot be renamed** after creation)
   - plugin step registration changes are in the solution's `SdkMessageProcessingSteps`, not only in a code attribute
   - no ticket numbers or TODOs left in code comments unless the repo does that
10. **Commits** — follow the repo's message format; everything on the feature branch.

## Output

| Check | Status | Detail |
|---|---|---|

✅ ok · ⚠️ look at this · ❌ must fix before PR · ⏳ needs the user

Then a short draft PR description: what changed, per work item, one line each.
