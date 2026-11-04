---
name: dataverse-import-rca
description: Root-cause analysis for a failed or partial data import into Dataverse (Azure Function, plugin, flow, or custom integration) - test the existing diagnosis at runtime, trace the full exception chain, eliminate hypotheses one by one, map what the import reads, writes and drops, and write an RCA with a sized fix. Use when an import stopped working, loads only some rows, or the accepted explanation hasn't been proven.
---

# Data import root-cause analysis

The first explanation is usually plausible and often wrong — especially "the secret expired". Prove the cause with runtime evidence before anyone spends time fixing it.

## Method

1. **Restate the current diagnosis and test it.** If it says "credential expired", fix the credential in a non-prod environment and rerun. Failure persists → the diagnosis is wrong.
2. **Capture a controlled run.** Trigger one import with a small known file while watching logs. For Azure Functions, Application Insights:
   ```kql
   dependencies
   | where timestamp between (datetime(<start>) .. datetime(<end>))
   | project timestamp, type, target, name, resultCode
   | order by timestamp asc

   exceptions
   | where operation_Id == "<operation id>"
   | project outerType, innermostMessage, details
   ```
   The caller often sees a bare 500. The real cause (e.g. a 401 from a downstream service) is deeper in the chain — read it to the innermost exception.
3. **Read the deployed code**, not only the repo. If source is missing, download the deployed package and decompile (ILSpy) — find the actual auth and API calls.
4. **Eliminate every hypothesis** in a table: hypothesis, test applied, result. Typical rows: expired secret · Key Vault reference pinned to an old version · missing app permission · tenant setting · fallback credential · source file format changed.
5. **Timeline** of changes and failures. Flag coincidences (a credential expiring the same week the real cause appeared).
6. **Field map from the code:** source column (letter/index) → field read → target table.column → status (mapped / dropped / unused / hard-coded). Note guard clauses that skip rows silently.
7. **Fix, effort and preconditions**, plus any **other consumers** affected by the same cause.

## Common real causes

- **Retired authentication model.** E.g. SharePoint app-only via ACS (`GetACSAppOnlyContext`) is retired: the token endpoint returns 200, then SharePoint returns 401. No credential rotation fixes it — move to Entra ID app-only with a certificate.
- Key Vault secret expiry metadata ≠ the real Entra credential expiry. Monitor the Entra app registration, not Key Vault.
- Version-pinned Key Vault reference (`.../secrets/name/<version>`) ignores rotation.
- **Positional column readers** with no header matching mis-map silently when someone reorders columns.
- `if (a && b && c) { create }` with no `else` — rows dropped with no log or count.
- Missing parent lookup (matched by name or year substring) cascades into every child row failing.
- Reference data looked up by **display name** breaks on rename; lookup caches hide new records for their TTL.
- Hard-coded values (country, source, owner) in code.
- A connector with no timeout hangs on a malformed file, so the catch never runs.
- A "file modified" trigger ignores files that were **moved** in (they keep their old Modified time) — upload instead.
- Fixed-position substring date parsing; case-sensitive comparisons after an upstream lowercase.

## RCA document

1. **Summary** — one paragraph: what failed, real cause, fix, effort.
2. **Existing diagnosis vs verified:** Cause | Remedy | Effort | Precondition
3. **Evidence sequence:** Time | Method | Endpoint | Result
4. **Exception chain:** # | Exception | Origin
5. **Eliminated hypotheses:** # | Hypothesis | Test | Result
6. **Timeline:** Date | Event
7. **Field map:** Column | Index | Source field | Target | Status
8. **Work required:** Task | Owner | Estimate
9. **Other affected consumers:** Component | Credential/dependency | Status

Do not change production configuration during the RCA; test in non-prod or get approval first.
