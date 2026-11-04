# d365-claude-skills

Field-tested [Claude Code](https://claude.com/claude-code) skills for Dynamics 365 / Dataverse / Power Platform developers.

They come from real project work and target the failures that cost the most time: the ones that are **silent** in Dev and only show up in test, for non-admin users, or after a deployment.

## Install

```
/plugin marketplace add mohsinarif10/d365-claude-skills
/plugin install dataverse-toolkit@d365-claude-skills
```

Using Claude.ai or Claude Desktop instead? Download any folder under `plugins/dataverse-toolkit/skills/` and upload it as a skill.

## Skills in `dataverse-toolkit`

| Skill | What it does |
|---|---|
| `dataverse-log-capacity` | Measures audit / plugin trace / async operation storage, exports audit history with a SHA-256 manifest before deletion, and proves reclaimed capacity with before/after snapshots. Read-only scripts. |
| `dataverse-pre-pr` | Before a PR: exports and unpacks **every** solution so maker-built configuration is not left out, packs zips, accounts for every changed file, checks conventions. |
| `dataverse-new-component-checklist` | Checklist and symptom → cause table for new tables, columns, BPFs, views, solution flows and plugin steps. |

## Requirements

- [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) (`pac`) for `dataverse-pre-pr`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`) and PowerShell for `dataverse-log-capacity`

## Safety

The skills read and recommend; they do not delete data, change audit settings or push code without you saying so.

## Contributing

Issues and PRs welcome — especially new silent-failure cases for the checklist.

## License

MIT
