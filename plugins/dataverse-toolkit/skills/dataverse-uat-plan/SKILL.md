---
name: dataverse-uat-plan
description: Build a lean UAT / verification test plan for Dynamics 365 / Dataverse / Power Automate changes and track it honestly - design each test to prove several tracker items at once, write exact expected outcomes per flow action and per CRM record, cover failure paths, collect run-level evidence, and keep Verified / Pending / Stalled / Blocked status. Use when the user needs a UAT plan, test scripts, or a status report for fixes going to test.
---

# UAT plan and status

Prove the fixes with the **fewest tests**. One well-designed action should exercise several tracker items. A test that exposes a new fault is a **finding**, not a pass.

## 1. Map items to tests

Start from the tracker (PBIs, defects, requirements). Group them so each test proves as many as possible:

| Test | What you do | Items it proves | Status |
|---|---|---|---|

Cover at least:
- **Happy path** — the normal input end to end
- **Data shortfall** — one row deliberately wrong (e.g. pointing at a parent that does not exist) to prove validation and totals checks
- **Concurrency** — two inputs at once, to exercise trigger and loop concurrency
- **Broken input** — e.g. a text file renamed to the expected extension, to exercise the catch path, failed status and alerting
- **Scheduled / integration runs** — let the real schedule fire at least once
- **Non-admin user** — run user-facing tests as a normal user, not System Administrator

## 2. Write each test

For every test:
- **Proves:** item ids
- **Steps:** exact location and action. Name test data so it is obviously test data. Upload rather than move files (file-modified triggers ignore moved files).
- **Expected per action:** e.g. `Get file → Succeeded`, `Condition → true branch`, `Send alert → Skipped`
- **Expected in CRM:** records created, lookups set, status, notes text, totals
- **If it fails:** where the real logs are (flow run history, Application Insights, plugin trace log)

## 3. Run and collect evidence

Run tests in order. After each, check run history, function/plugin logs and CRM records **before** the next.

Evidence per test: run id and time · expected vs actual counts/totals · records created, traced back to their source rows · files archived/moved as expected.

To check flow actions quickly: list runs since the test start, then each run's actions, and print any action that is neither `Succeeded` nor `Skipped` with its error (Flow API: `.../flows/{id}/runs` and `.../runs/{runId}/actions`, api-version `2016-11-01`).

A branch counts as proven when its child actions ran.

## 4. Clean up

Deactivate or delete test records and duplicates; remove broken test files from archives. List what was cleaned.

## 5. Status — keep it honest

- ✅ **Verified** — observed working with evidence
- ⏳ **Pending** — not yet run
- ⚠️ **Stalled** — the test exposed a new fault; log it as a finding
- ❌ **Blocked** — external dependency missing (access, token, data, another team)

**Open findings:** Finding | Where | Severity | Owner

## Gotchas

- Trigger concurrency of 1 may not serialise runs that start in the same millisecond — check run start times.
- A connector without a timeout hangs on a broken file, so a failure-path test **stalls** instead of failing.
- Turn alerting off in test environments (environment variable) so tests cannot email production support — and note that it must be **on** in production.
- HTTP-triggered functions return a bare 500; read Application Insights for the cause.
- A green result where the component never received data (empty token, no input) is **not** a pass.

## Output

Overview table, then one section per test (Proves / Steps / Expected / Evidence / Result), then open findings. Offer to render it as a shareable page or document if the user wants to send it to testers.
