---
name: ado-my-work-status
description: Read-only daily status of your Azure DevOps work items - re-queries every open non-Task item assigned to you, flags what is new or changed since the last run, and shows one compact table. Use when the user asks for their morning status, "my PBIs", "my work items", "what's on my plate", or a sprint status.
---

# My Azure DevOps work status (read-only)

**Never write to Azure DevOps here** — no state, field, comment or link change, even if something looks wrong. Report it in chat; the user decides.

## Setup (once)

Ask the user for their organisation URL (`https://dev.azure.com/<org>`) and default project if not known, and remember them for next time. Auth: Azure DevOps MCP server if connected; otherwise Azure CLI with the devops extension (`az extension add --name azure-devops`) and either `az login` or a PAT in `AZURE_DEVOPS_EXT_PAT`.

## 1. Query fresh — never reuse an earlier list

```
az boards query --org <org> -o json --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.AssignedTo] = @Me AND [System.WorkItemType] <> 'Task' AND [System.State] NOT IN ('Done','Removed','Closed') ORDER BY [System.ChangedDate] DESC"
```

- Use `WorkItemType <> 'Task'`, not `= 'Product Backlog Item'` — the positive form drops Bugs, User Stories and Issues.
- State names differ per process template (Agile: `Closed`/`Resolved`; Scrum: `Done`; CMMI: `Closed`). Check one item's states and adjust the exclusion list.
- If the result count looks capped, page it. **Never conclude an item is absent from a truncated list.**

Then fetch each id for the fields you show — take type and state from the item, not the query:

```
az boards work-item show --org <org> --id <id> --fields System.WorkItemType,System.State,System.Title,System.IterationPath,System.Parent,System.ChangedDate
```

If the user names a sprint, area or project, filter to it.

Optionally read the latest comment on each item (`az devops invoke --area wit --resource comments ...` or the MCP) — decisions and blockers usually live in comments, not fields.

## 2. Diff against the last run

Keep a snapshot at `~/.claude/ado-status-last.json` (id → state). Mark items not in it 🆕 and items whose state changed with `old → new`. Overwrite the snapshot afterwards.

## 3. Output — one table

| # | ID | Type | Title (short) | State | Marker | Next step / blocked on |
|---|---|---|---|---|---|---|

✅ done/ready · ⚠️ needs attention · ❌ blocked · ⏳ waiting on someone · 🆕 new since last run

Under the table, at most three lines: what is new, and what needs the user's decision today. No per-item prose.
