---
name: dataverse-new-component-checklist
description: Checklist for adding a new Dataverse table, column, business process flow (BPF), view, or solution cloud flow without the silent failures that only show up in test or for non-admin users. Includes a symptom-to-cause table for "BPF bar missing", "duplicate BPF instances", "view not in selector", "works for admins only", and privileges lost on import. Use when creating any of these components, or when one works in Dev but not in test.
---

# New Dataverse component checklist

Each item below **fails silently**: the import reports success, Dev looks fine (because everyone testing in Dev is a System Administrator), and the problem surfaces in test as a "new defect".

## Symptom → cause (start here when debugging)

| What you see | Likely cause |
|---|---|
| Works for admins, fails or is hidden for normal users | Missing privileges on the table (or the BPF's backing table) in the users' security role |
| Privileges were set but are missing after deployment | Set by hand in Dev and never exported, **or** the security solution imported **before** the solution that creates the table — Dataverse silently drops privileges for tables that do not exist yet |
| Plugin fails for normal users on a table they never open | Plugin runs as the calling user, so the user needs privileges on every table the plugin writes |
| BPF instance exists at the right stage but **no process bar** | BPF not added to the **model-driven app's** components |
| **Two** instances of the same BPF on one record | Both client script (`setActiveProcess`) and server code create one; nothing reconciles them |
| New view **not in the view selector** | View is not an app module component (the app only surfaces views it lists) |
| `pac solution export` fails: "solution does not include corresponding Business Process entity" | BPF process is in the solution but its backing table is not — they are two separate components |
| Save error "Saving in Progress" (`0x83215603`) | Client script switches process or saves while the form is dirty / mid-save |

## New table

- [ ] Schema name follows the repo's convention (check existing tables). **It cannot be renamed later** — a PUT with a new SchemaName returns 204 and silently does nothing; fixing means delete and recreate.
- [ ] Description filled in.
- [ ] Added to the right solution.
- [ ] Privileges (Create, Read, Write, Delete, Append, Append To) granted on the role normal users actually hold — including roles held through a **team**, which do not show on the user's own role list.
- [ ] Tables written by plugins or flows running as the user are covered too.
- [ ] Security solution **re-exported** from Dev after granting (never hand-edit role XML).
- [ ] Deployment imports the security solution **after** the solution that creates the table.
- [ ] Early-bound classes regenerated if the codebase uses them.

## New column

- [ ] Schema name convention, description, correct solution.
- [ ] Added to the forms and views it belongs on (in the same solution as those forms/views).
- [ ] If a plugin step should react to it, the step's **filtering attributes** include it.
- [ ] Auditing deliberately on or off — high-churn integration columns with audit on are a common cause of log-capacity problems.

## New business process flow

- [ ] Created on the right table, stages and steps added, then **activated** (activation creates the backing table).
- [ ] **Both** the process and its backing table added to the solution.
- [ ] Privileges on the backing table for normal users' role (Business Process Flows tab of the role).
- [ ] BPF ticked in the model-driven app's components. If the modern app designer has no BPF section, use the classic app designer (… → Switch to classic → Components → Business Process Flows).
- [ ] If code switches or creates BPF instances, exactly one place does it, and a Create step on the backing table cleans up any extra instance.
- [ ] To get the process and stage GUIDs: export, `pac solution unpack`, then read `Workflows/<name>.xaml.data.xml` (`WorkflowId` and each `steplabels id`). A raw unzip does not contain `.data.xml`.

## New view

- [ ] Added to the app module components. Fastest route:
  ```
  POST /api/data/v9.2/AddAppComponents
  { "AppId": "<appmoduleid>", "Components": [ { "@odata.type": "Microsoft.Dynamics.CRM.savedquery", "savedqueryid": "<viewid>" } ] }
  ```
  then publish the app. Verify with `RetrieveAppComponents(AppModuleId=<id>)` rather than a remembered `appmoduleidunique` (it changes when the app is saved).

## New cloud flow in a solution

- [ ] Uses the solution's existing **connection reference**, not a new one.
- [ ] Do **not** "fix connections" in the designer to turn the flow on if you cannot access the reference's connection: the designer creates a new connection reference, binds the flow to it, and it ships with the solution. Get the connection shared with you, or have its owner turn the flow on.
- [ ] Repointing a connection reference re-saves every flow using it — diff the next export and restore anything that changed unintentionally (e.g. retry policies).

## Plugin steps

- [ ] The step registration lives in the solution (`SdkMessageProcessingSteps/*.xml`). Registration attributes in code are documentation unless your tooling reads them — check what actually deploys.
- [ ] In the Plugin Registration Tool, "Update Assembly" does nothing until you browse to the DLL and click **Load Assembly**; it never creates new steps.

## Before calling it done

Test as a **non-admin** user in an environment deployed from the solutions, not in Dev.
