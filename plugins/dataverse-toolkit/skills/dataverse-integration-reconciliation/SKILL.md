---
name: dataverse-integration-reconciliation
description: Reconcile an external system (payment platform, API feed, import file, queue) against Dataverse record by record - rebuild the source list from Power Automate run history, match each item to its Dataverse record, classify it (automatic, re-keyed by hand, by design, not recorded), find the per-item cause of every failure, and produce an evidence report. Use when someone asks "did everything from X reach CRM", totals don't match, or an integration may have been silently dropping records.
---

# Integration reconciliation

Goal: for **every** item the external system reported, prove whether it reached Dataverse and how. Evidence per item, not run-level guesses. Read-only throughout.

## Method

1. **Fix the window — and do it fast.** Power Automate keeps run history for about 28 days; action input/output links expire sooner. Capture evidence now and state in the report that nothing earlier can be examined.
2. **Rebuild the source list** from the integration flow's runs (or from the source file/API if you have it): external ref, type, amount, timestamp, flags. Save it as JSON — this is the source of truth for the rest of the work.
3. **Match each item** in Dataverse on the column holding the external reference (escape `'` as `''`).
4. **If found**, read `createdon` and `createdby` (formatted). Integration/service account → *automatic*; named person → *re-keyed by hand*. Delay = createdon − source timestamp.
5. **If not found, search exhaustively before calling it missing:**
   - by the reference in any other source column
   - same amount, date within ±2 days
   - anything from that channel created since the source date (late arrival)
   Write down why each near-match is **not** this item.
6. **Check child records separately** (consents, declarations, mandates, lines). A manual re-key often restores the parent but not its children.
7. **By-design paths** (e.g. a recurring sign-up creates a mandate, not a payment) are matched through the related record, not reported as missing.
8. **Find the cause per item:** locate that item's iteration in the run (action repetitions), read the action error and any platform reference number. Never attach a run-level error to an item.
9. **Batch totals:** compare the header's expected count/value with an aggregate over the children. Verdict MATCH or SHORTFALL.
10. **Re-verify every figure live on the day you publish.**

## Queries

Dataverse (token: `az account get-access-token --resource https://<org>.crm.dynamics.com`), with header `Prefer: odata.include-annotations="*"` for formatted values:

```
GET /api/data/v9.2/<entityset>?$filter=<sourceRefColumn> eq 'REF'&$select=createdon,_createdby_value
```

Batch aggregate (send as `?fetchXml=` URL-encoded):

```xml
<fetch aggregate="true"><entity name="<childtable>">
  <attribute name="<childtable>id" aggregate="countcolumn" alias="c"/>
  <attribute name="<amountcolumn>" aggregate="sum" alias="s"/>
  <filter><condition attribute="<batchlookup>" operator="eq" value="{batch-id}"/></filter>
</entity></fetch>
```
MATCH when `count == expected` and `|expected − actual| < 0.005`.

Flow runs (token resource `https://service.flow.microsoft.com/`):

```
GET https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/{envId}/flows/{flowId}/runs?api-version=2016-11-01&$top=100
GET .../runs/{runId}/actions?api-version=2016-11-01
GET .../runs/{runId}/actions/{actionName}/repetitions?api-version=2016-11-01
```
Flow id from Dataverse: `workflows?$filter=category eq 5 and name eq '<flow name>'&$select=workflowid`.

## Gotchas

- **A run can be "Succeeded" while writes inside it failed** (swallowed by run-after or a scope). Check action status, never run status.
- Transient platform errors (sandbox/host unavailable, 429, 503) with **no retry** and a moving date window give an item exactly one chance — it is simply lost.
- Prove whether the source API's end date is inclusive or exclusive (same start and end → 0 rows means exclusive). Overlap = duplicates; off-by-one = gaps.
- One failed call early in a chain silently skips everything after it.
- Parallel *Apply to each* (default concurrency 20) incrementing a shared variable loses updates — totals understated.
- A summary status written as "Completed" even with a shortfall — put the verdict in its own field.
- Lookups by `begins-with`/name without `statecode eq 0` hit the wrong or inactive record.
- Re-running a file creates duplicates when the reference column holds a constant.
- Say UTC or local in every table heading.

## Report

1. **Summary:** Outcome | Count | Value | Share
2. **Ledger:** Source time (UTC) | External ref | Type | Amount | Dataverse record | Outcome (automatic / by hand / by design / NOT RECORDED) | Children OK?
3. **Per failure:** External ref | Run id | Failed action | HTTP code | Error | Platform ref | Searches done | Recovered? (by whom, delay)
4. **Batches:** Batch | Expected n / value | Actual n / value | Verdict
5. **Root causes and fixes** — e.g. add retry policy, overlapping-but-idempotent window, alert on failed actions.

Never paste personal data from the records into chat; use references and counts.
