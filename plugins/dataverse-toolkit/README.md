# dataverse-toolkit

Ten Claude Code skills for Dynamics 365, Dataverse and Power Automate developers. They target the failures that stay silent in Dev and only appear in test, for non-admin users, or after a deployment.

| Skill | Use it when |
|---|---|
| `dataverse-pre-pr` | Before a PR: export every solution so maker-built configuration reaches source control |
| `dataverse-new-component-checklist` | Adding a table, column, BPF, view, flow or plugin step |
| `dataverse-plugin-registration-audit` | A plugin doesn't fire, or behaves differently between environments |
| `power-automate-solution-flow-standards` | Building or reviewing a solution-aware cloud flow |
| `dataverse-log-capacity` | Log/audit storage is full or an audit deletion is planned |
| `dataverse-integration-reconciliation` | Proving an external system and Dataverse agree |
| `dataverse-import-rca` | A data import failed or loaded only partly |
| `dataverse-env-compare` | Something works in one environment and not another |
| `dataverse-uat-plan` | Writing a UAT plan and tracking its status |
| `ado-my-work-status` | Daily Azure DevOps status of your work items |

All skills read and recommend. They never delete data, change settings, update work items or push code without the user asking.

Requirements: Power Platform CLI (`pac`) and/or Azure CLI (`az`) and PowerShell for the skills that query environments. The checklists need nothing.

Full install and usage guide: https://github.com/mohsinarif10/d365-claude-skills

License: MIT
