---
name: dataverse-log-capacity
description: Measure Dataverse log/audit storage (audit, plugin trace, async operations, workflow logs), export audit history as tamper-evident evidence before deleting it, and prove how much capacity a cleanup reclaimed with before/after snapshots. Use when a Dataverse environment is over its log capacity, someone plans an audit-log deletion or retention change, or asks "what is eating our log storage".
---

# Dataverse log capacity

Log capacity fills up quietly, mostly from audit. Deleting audit data cannot be undone, so the order is always: **measure → preserve → get sign-off → delete → measure again**.

Everything in `scripts/` is **read-only**. This skill never deletes anything. The deletion itself (audit log deletion in Power Platform admin center, or a bulk delete job) is done by a human after sign-off.

## Prerequisites

- Azure CLI signed in to the tenant: `az login --tenant <tenant> --allow-no-subscriptions`
- A user with read access to `audit` (System Administrator or System Customizer in practice)
- PowerShell 5.1+ or 7+

## Workflow

### 1. Baseline snapshot

```powershell
./scripts/Measure-DataverseLogCapacity.ps1 -Url https://<org>.crm.dynamics.com
```

Writes `snapshots/logcap-<host>-<timestamp>.json` and prints:
- audit storage (GB) and row count, oldest audit record
- org audit settings: audit on/off, user access audit, retention (`null` = forever), plugin trace setting
- row counts for `asyncoperation`, `plugintracelog`, `workflowlog`
- top 10 tables by audit storage (from `GetAuditStorageDetails`, which is async and can take minutes)

Read the result for the user. Common findings:
- **Retention = forever** — the root cause in most cases. Recommend a retention period.
- **One or two tables hold most of the audit** — usually an integration updating records on a schedule with auditing on high-churn columns. Recommend turning audit off on those columns, not the whole table.
- **Plugin trace setting = All (2)** left on in production — recommend Exception (1) or Off (0).
- **Large `asyncoperation` count** — completed system jobs never cleaned; a bulk delete job on succeeded jobs fixes it.

### 2. Preserve evidence for the tables being deleted

```powershell
./scripts/Export-DataverseAuditTable.ps1 -Url https://<org>.crm.dynamics.com -Table account -Before 2025-01-01
```

Writes one JSON line per audit row (including `changedata`, the old/new values) plus a `.manifest.json` with record count, filter and SHA-256. The hash lets anyone later show the export is complete and unchanged. Run it once per table in scope. For big tables, run it in the background — it pages 5,000 rows at a time.

### 3. Sign-off

Draft a short sign-off request for the data owner. Include: environment, tables and date range in scope, row counts and GB from the baseline, where the exports are stored with their hashes, and the statement that deleted audit cannot be restored. **Do not proceed past this point yourself.**

### 4. Re-measure after deletion

```powershell
./scripts/Measure-DataverseLogCapacity.ps1 -Url https://<org>.crm.dynamics.com -CompareWith ./snapshots/<baseline>.json
```

Run at T+0, T+24h and T+72h. **Capacity figures in the admin center can lag up to 72 hours** after a delete job finishes — a flat number at T+0 is normal, not a failure.

## Rules

- Never delete, change retention or change audit settings yourself. Recommend; a human does it.
- Never paste exported audit content into chat — it contains personal data. Report counts and hashes only.
- Measure the same environment with the same script before and after; compare like with like.
