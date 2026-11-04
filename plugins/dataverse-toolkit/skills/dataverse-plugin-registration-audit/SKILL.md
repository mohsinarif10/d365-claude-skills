---
name: dataverse-plugin-registration-audit
description: Audit what plugin steps are actually registered in a live Dataverse environment - builds a plugin x table x message matrix from sdkmessageprocessingsteps, compares it with source control and across sibling tables, and explains each gap. Use when a plugin "doesn't fire", behaves differently between environments, a new table joins a family of similar tables, or before claiming a step is or isn't registered.
---

# Plugin registration audit

**The repo is not evidence of what an environment holds.** Registration attributes in code are often documentation only, unpacked solutions go stale, and steps get added in the Plugin Registration Tool without being exported. Query the environment.

## 1. Pull the live registration matrix

Web API (token: `az account get-access-token --resource https://<org>.crm.dynamics.com`):

```
GET /api/data/v9.2/sdkmessageprocessingsteps
  ?$select=name,stage,mode,rank,filteringattributes,statecode,asyncautodelete
  &$filter=ishidden/Value eq false and customizationlevel eq 1
  &$expand=plugintypeid($select=typename,assemblyname),
           sdkmessageid($select=name),
           sdkmessagefilterid($select=primaryobjecttypecode),
           impersonatinguserid($select=fullname)
```

- `stage`: 10 PreValidation · 20 PreOperation · 40 PostOperation
- `mode`: 0 Synchronous · 1 Asynchronous
- `statecode`: 0 Enabled · 1 **Disabled** (a disabled step looks registered at a glance)
- Narrow with `plugintypeid/assemblyname eq '<Assembly>'` for one assembly.
- Images: `sdkmessageprocessingstepimages?$filter=_sdkmessageprocessingstepid_value eq <id>&$select=name,imagetype,attributes,entityalias`

Build a table: **Plugin type × Table × Message → stage / mode / filtering attributes / enabled / images**.

## 2. Compare against source

- Unpacked solution: `SdkMessageProcessingSteps/*.xml` in the plugins solution. Steps live there — not in a code attribute, unless your build tool (e.g. spkl, PAC plugin init with registration) actually reads it.
- Report each difference: in env but not in source (someone registered by hand — needs export), in source but not in env (deployment gap), or **different** stage/mode/filtering attributes (the most dangerous — behaviour differs silently).

## 3. Compare across siblings

When tables form a family (several similar request types, several BPF backing tables, several child records of one parent), list every plugin registered on **any** member and show which members have it. Build the coverage table for **all** siblings, not just the one in the current task.

## 4. Explain every gap before calling it a bug

A missing step is not automatically a defect:
- The plugin may **self-gate** — read its code: does it return early for this table or this record type?
- The table may lack a precondition the plugin needs (a stage, a column, a status).
- Filtering attributes may legitimately differ.

For each gap give: **missing / intentional (why) / needs a decision**. Never report an absence without the reason.

## 5. Common causes of "the plugin doesn't fire"

| Symptom | Check |
|---|---|
| Fires on create, not on update | Update step's filtering attributes don't include the changed column |
| Works in Dev, not in test | Step not in the solution / assembly in test is older |
| Fires but sees old values | PreOperation vs PostOperation, or missing pre/post image |
| Runs twice | Two steps (often one sync, one async, or registered on both Create and a later Update the plugin itself triggers) — check `depth` handling |
| Only fails for non-admins | Plugin runs as calling user and the user lacks privileges on a table the plugin touches |
| PRT "Update Assembly" changed nothing | You must browse to the DLL and **Load Assembly** first; Update never creates new steps |

## Output

The matrix, then a gap table:

| Plugin | Table | Message | Env | Source | Verdict | Reason |
|---|---|---|---|---|---|---|

Read-only: never register, disable or delete steps as part of this audit.
