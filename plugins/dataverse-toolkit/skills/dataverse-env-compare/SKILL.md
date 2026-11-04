---
name: dataverse-env-compare
description: Compare two or more Dataverse / Power Platform environments (dev, test, prod) - cloud flow definitions, connection references, environment variables, solutions and versions, column existence and owners - to find real drift before promoting a fix or when something works in one environment and not another. Read-only; produces side-by-side and literal-diff tables.
---

# Environment compare

A solution export carries the **current state** of every component in it — including unfinished work and environment-specific values — not just "your change". Know what differs before you move anything.

Read-only. Snapshot every definition to disk before anyone changes one.

## Method

1. **Solutions:** name, version, managed/unmanaged in each environment.
   ```
   solutions?$select=uniquename,version,ismanaged,installedon&$filter=isvisible eq true
   ```
2. **Flows:** for each flow in scope, in each environment:
   ```
   workflows?$filter=category eq 5 and name eq '<flow>'&$select=name,workflowid,statecode,clientdata,ismanaged,modifiedon,_ownerid_value
   ```
   Compare the same `workflowid` across environments: on/off, owner, last modified, definition size, action count (count `"operationMetadataId"` in `clientdata`), byte-identical or not. Same id with different names = drift.
3. **Structural diff of the definition:** parse `clientdata` → `properties.definition`, walk `actions` recursively (including nested `actions`, `else.actions`, cases), and compare literals: table names, child-flow ids, queue/folder names, FetchXML filters, URLs, email addresses, culture. Output a literal diff table.
4. **Trigger and loop settings:** `definition.triggers.*.runtimeConfiguration` (concurrency), `actions.<loop>.runtimeConfiguration.concurrency.repetitions`, retry policies.
5. **Environment variables:** definition default vs current value per environment, and which solution owns each.
   ```
   environmentvariabledefinitions?$select=schemaname,defaultvalue,type&$expand=environmentvariabledefinition_environmentvariablevalue($select=value)
   ```
6. **Connection references:** connector, whether a connection is bound, and **who** it runs as (a disabled or unlicensed owner is a common cause of flows silently off).
   ```
   connectionreferences?$select=connectionreferencelogicalname,connectorid,connectionid,_ownerid_value
   ```
7. **Schema presence:** `EntityDefinitions(LogicalName='<table>')/Attributes(LogicalName='<column>')?$select=LogicalName` — 404 means absent.
8. **Defect presence:** before claiming an environment is "ahead", check the defect or fix in each environment.
9. **What would travel** if you export from the source: component | change | wanted? Then options: remove the unfinished work first, patch the target directly (note: an unmanaged change over a managed component blocks future managed updates), or go through the owning solution.

## Gotchas

- Pasting one environment's flow definition into another can point it at the wrong data source (`InvalidOpenApiFlow: Bad Data Source`).
- Connection reference keys inside `connectionReferences` can differ between environments (e.g. a `_1` suffix).
- An **empty** environment variable value silently falls back to the solution default, which may be stale.
- Environment variable **values** must stay environment-specific — keep them out of the solution, set them via deployment settings.
- Guards that compare the environment's **display** name break when it is renamed. Check the real value.
- Conditions comparing two literals are always true or always false — look for them in the diff.
- Hard-coded feature switches in an *Initialize variable*.
- Trailing slash in a base-URL variable → `//` in every call.
- OAuth connections often cannot be shared; they must be recreated as the service account.
- A lower environment receiving no data because a token was rotated only in prod — compare the last-received date per environment.

## Output

1. **Side by side:** Property | Env A | Env B | Env C (id, managed, owning solution, owner, state, last modified, size, action count)
2. **Literal diff:** Location | Literal | Env A | Env B | Same / DIFFERENT
3. **Env variables:** Variable | Default | A | B | Owning solution
4. **Connection refs:** Reference | Connector | A (bound, owner) | B (bound, owner)
5. **Defect presence:** Defect | A | B | C
6. **Would travel:** Component | Change | Wanted?
7. **Options** with trade-offs, and **blockers:** Item | Evidence | What is needed | Owner
