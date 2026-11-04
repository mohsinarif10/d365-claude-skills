# d365-claude-skills

Field-tested [Claude Code](https://claude.com/claude-code) skills for Dynamics 365 / Dataverse / Power Platform developers.

They come from real project work and target the failures that cost the most time: the ones that are **silent** in Dev and only show up in test, for non-admin users, or after a deployment.

## Skills in `dataverse-toolkit`

| Skill | Use it when |
|---|---|
| `dataverse-pre-pr` | Before raising a PR — exports **every** solution so maker-built config isn't left out, packs zips, accounts for every changed file |
| `dataverse-new-component-checklist` | Adding a table, column, BPF, view, flow or plugin step — or one works in Dev but not in test |
| `dataverse-plugin-registration-audit` | A plugin "doesn't fire", or behaves differently between environments |
| `power-automate-solution-flow-standards` | Building or reviewing a solution-aware cloud flow (naming, connection references, try/catch, deployment) |
| `dataverse-log-capacity` | Log/audit storage is full, or an audit deletion is planned — measure, export evidence, prove what was reclaimed |
| `dataverse-integration-reconciliation` | Proving an external system (payment platform, file feed, API) and Dataverse agree — or finding where they don't |
| `dataverse-import-rca` | A data import failed or loaded only partly — find the root cause and write it up |
| `dataverse-env-compare` | Something works in one environment and not another — diff solutions, flows, connection references and config |
| `dataverse-uat-plan` | Turning requirements into a UAT test plan and tracking its status |
| `ado-my-work-status` | Your daily Azure DevOps status — open work items, what's new or changed since yesterday |

All skills **read and recommend**. They do not delete data, change settings, change work items or push code unless you say so.

## Install

### Claude Code (recommended)

In any Claude Code session:

```
/plugin marketplace add mohsinarif10/d365-claude-skills
/plugin install dataverse-toolkit@d365-claude-skills
```

Restart Claude Code (or run `/reload-plugins` if your version has it). Check it worked with `/plugin` → **Installed**.

| To | Run |
|---|---|
| Get new skills and fixes | `/plugin marketplace update d365-claude-skills` |
| Turn it off for a while | `/plugin disable dataverse-toolkit@d365-claude-skills` |
| Remove it | `/plugin uninstall dataverse-toolkit@d365-claude-skills` |

For a whole team, add it to the repo's `.claude/settings.json` so everyone gets it automatically:

```json
{
  "extraKnownMarketplaces": {
    "d365-claude-skills": { "source": { "source": "github", "repo": "mohsinarif10/d365-claude-skills" } }
  },
  "enabledPlugins": { "dataverse-toolkit@d365-claude-skills": true }
}
```

### Claude.ai / Claude Desktop

1. Download this repo (**Code → Download ZIP**) and unzip it.
2. Zip **one** skill folder, e.g. `plugins/dataverse-toolkit/skills/dataverse-pre-pr`.
3. In Claude: **Settings → Capabilities → Skills → Upload skill** and pick that zip.

Skills that run scripts or `pac`/`az` commands need Claude Code, because they work against your local machine and environments.

## Use

You don't have to remember names. Ask in plain words and Claude picks the right skill:

```
> I'm about to raise a PR for the new Contract table, run the pre-PR check
> The approval plugin doesn't fire on update in test but does in dev
> Our Dataverse log capacity is at 140%, what's taking the space?
> Compare the solutions and flows between dev and uat
> What's on my plate in DevOps today?
```

Or call one directly — plugin skills are namespaced by the plugin:

```
/dataverse-toolkit:dataverse-pre-pr
/dataverse-toolkit:dataverse-log-capacity https://contoso.crm.dynamics.com
```

### What you need for each

| Skill | Needs |
|---|---|
| `dataverse-pre-pr`, `dataverse-env-compare` | [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) (`pac`) signed in: `pac auth create --environment <url>` |
| `dataverse-log-capacity`, `dataverse-plugin-registration-audit`, `dataverse-integration-reconciliation`, `dataverse-import-rca` | [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) signed in to the tenant: `az login --tenant <tenant> --allow-no-subscriptions`, and PowerShell |
| `ado-my-work-status` | Azure DevOps MCP server, **or** Azure CLI with `az extension add --name azure-devops` |
| Checklists and standards | Nothing |

### Example: log capacity cleanup

```
> Measure log capacity for https://contoso.crm.dynamics.com
   ... baseline snapshot + top tables by audit size + recommendations
> Export audit for the account and contact tables before 2025-01-01
   ... JSONL files + SHA-256 manifest per table
> (you get sign-off and run the deletion yourself)
> Compare against the baseline
   ... before / after / reclaimed — run again at +24h and +72h, capacity lags
```

## Contributing

Issues and PRs welcome — especially new silent-failure cases for the checklist. Keep examples generic: no customer names, URLs or data.

## License

MIT
