---
name: power-automate-solution-flow-standards
description: Standards for building Power Automate cloud flows that live in a Dataverse solution and are deployed through ALM - naming, connection references, trigger filtering, a reusable try/catch error-handling pattern, child flows, deployment settings and turning flows on after import. Use when designing, building, reviewing or editing a solution-aware cloud flow, or when a flow breaks after deployment.
---

# Solution cloud flow standards

**First rule: mirror the repo.** If the solution already has flows, open the closest existing flow of the same trigger type and copy its naming, connection references and error handling. Only use the defaults below where the project has no convention of its own.

## 1. Where flows live

An unpacked solution stores each flow as a pair under `Workflows/`:
- `<Name>-<GUID>.json` — definition (triggers and actions)
- `<Name>-<GUID>.json.data.xml` — metadata (display name, state, owner)

The GUID is the flow's identity. **Never regenerate it** for an existing flow — a new GUID deploys as a second flow next to the old one.

## 2. Naming

A predictable default: `Table-Trigger-ShortDescription`
- **Table** — primary table, or `Multitable` for shared/child flows
- **Trigger** — `Create`, `Update`, `CreateOrUpdate`, `Scheduled`, `ChildFlow`, `HttpRequest`
- Action names: readable, intent-describing (`Get_Manager_of_Employee`, not `Get_a_row_by_ID_3`). Rename actions **before** other actions reference them.

## 3. Connection references (never direct connections)

- Every connector the flow uses goes through a **connection reference that is in the same solution** as the flow.
- Reuse the solution's existing reference for that connector. One reference per connector per solution is the norm.
- **Do not "fix connections" in the designer** on a flow whose reference points at a connection you cannot use. The designer quietly creates a **new** connection reference, binds the flow to it, and it ships with the next export. Get the connection shared with you, or have its owner turn the flow on.
- Repointing a reference to a different connection re-saves the flows that use it. Diff the next export and restore anything that changed by accident (retry policies, concurrency).

**Which identity owns the connection**
- Connectors that support a service principal → service principal.
- Otherwise → a dedicated **service account** (licensed for premium connectors if the flow uses any). Never a developer's personal account in test or production.

## 4. Triggers

- Filter at the trigger, not with a Condition afterwards. For the Dataverse "When a row is added, modified or deleted" trigger set:
  - **Change type** and **Scope** (Organization unless there is a reason)
  - **Select columns** — only the columns that should start the flow; without it every update fires it
  - **Filter rows** — OData, e.g. `statuscode eq 1 and _parentaccountid_value ne null`
- A flow that updates the same row it triggers on needs Select columns that exclude what it writes, or it loops.

## 5. Error handling — try/catch pattern

Three root-level actions:

1. **Initialize variable** `FlowDetails` (Object) = `@workflow()`
2. **Scope `Try`** — all business logic inside.
3. **Scope `Catch`** — *Configure run after*: `Try` **has failed** (add **has timed out** too). Inside:
   - **Filter array**: from `@result('Try')` where `@equals(item()?['status'], 'Failed')`
   - **Compose `ErrorMessage`**:
     ```
     @coalesce(
       first(body('Filter_array'))?['outputs']?['body']?['error']?['message'],
       first(body('Filter_array'))?['outputs']?['body']?['message'],
       first(body('Filter_array'))?['error']?['message'],
       'Unknown error')
     ```
   - **Notify** — call one shared child flow (email/Teams/log table) with environment `@variables('FlowDetails')?['tags']?['environmentName']`, flow name `@variables('FlowDetails')?['tags']?['flowDisplayName']`, run id `@variables('FlowDetails')?['run']?['name']`, and the error message. Build a run link from these so support can click straight to the failed run.
   - **Terminate** — status **Failed**, message `@{outputs('ErrorMessage')}`. Without this the run shows as *Succeeded* because the Catch succeeded, and nobody looks at it.

Build the notifier once as a child flow and reuse it everywhere instead of sending ad-hoc emails from every flow.

## 6. Child flows

- Put repeated logic in a child flow (manual trigger "When a flow is run from a parent", ends with **Respond to a Power App or flow**).
- **Look for an existing child flow before writing new logic.**
- Child flows called from solution flows must be in a solution and use connection references; set "Run only users" to use the embedded connections.
- If the parent must not retry a failed child (e.g. it sends email), set the child action's retry policy to **None** explicitly.

## 7. Deployment

- Generate per-environment settings: `pac solution create-settings --solution-zip <zip> --settings-file <env>.json`, fill in the connection ids (and environment variable values) for each target, commit the files, and pass them to the import/pipeline task.
- The connections must exist in the target environment and be **shared with the identity that runs the import**.
- **Flows can arrive turned off** after first import, or when their connections were not resolved. The connection owner (service account) turns them on. Check after every release: flows off in the target → list them in the release notes.

## 8. Review checklist

- [ ] Name follows convention; actions have readable names
- [ ] Every connector via a connection reference in the same solution; no new stray references in the diff
- [ ] Trigger has Select columns and Filter rows
- [ ] Try / Catch / Terminate-as-Failed present
- [ ] No hard-coded environment URLs, emails or GUIDs — use environment variables
- [ ] `.json` and `.json.data.xml` pair consistent; GUID unchanged for existing flows
- [ ] Pagination/threshold set on List rows if the result can exceed 5,000
