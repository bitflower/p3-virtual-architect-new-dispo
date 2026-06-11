---
name: analyze-bug
description: Analyze a bug ticket end-to-end — fetch from Azure DevOps, resolve environment, query GCP logs across workloads, analyze code, correlate traces, and produce a structured bug analysis report. Use when the user provides a bug ticket URL or ID.
allowed-tools: Bash,Read,Write,Edit,Glob,Grep,Agent,WebFetch,AskUserQuestion
---

# Analyze Bug Skill

End-to-end bug analysis: Azure DevOps ticket → GCP log investigation → code analysis → structured report.

## When to Use

- User provides an Azure DevOps bug ticket URL or ticket ID
- User asks to "analyze bug", "investigate bug", "look into ticket"
- User asks to check logs for a specific ticket

## Input

The user provides one of:
- Azure DevOps URL: `https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/{ID}`
- Ticket ID only: `124918`

If only a URL is given, extract the numeric ID from the path.

## Phase 1: Fetch Ticket Details

Use the Azure CLI to fetch the work item:

```bash
az boards work-item show --id {TICKET_ID} --org https://dev.azure.com/p3ds --output json
```

Extract from `fields`:
- `System.Title` — ticket title
- `System.WorkItemType` — Bug, User Story, etc.
- `System.State` — state
- `System.CreatedDate` — creation timestamp (use as log search anchor)
- `System.ChangedDate` — last update
- `System.CreatedBy.displayName` — reporter
- `System.ChangedBy.displayName` — last updater
- `Microsoft.VSTS.Common.Priority` — priority
- `Microsoft.VSTS.Common.Severity` — severity
- `Microsoft.VSTS.TCM.SystemInfo` — **critical: contains environment + depot**
- `Microsoft.VSTS.TCM.ReproSteps` — repro steps
- `Custom.CurrentBehavior` — current behavior
- `Custom.Expectedbehaviour` — expected behavior
- `System.IterationPath` — sprint
- `System.Tags` — tags
- `System.Parent` — parent work item
- `System.History` — latest comment (may contain developer notes)
- `System.Description` — description (may contain screenshots as HTML img tags)

## Phase 2: Resolve Environment

The `System Info` field (e.g. `ABN1034`) encodes the environment and depot:

### Environment Prefix

| Prefix | Environment | Notes |
|--------|-------------|-------|
| `ABN`  | ABN (test)  | Standard test environment |
| `UAT`  | UAT         | User acceptance testing |
| `DEV`  | Development | Dev environment |
| `PROD` | Production  | Sometimes no prefix at all |
| (none) | Production  | Just a number like `1034` |

### Depot / Database Identifier

The number maps to a database identifier: depot `1034` → `D-10-34`.
Pattern: `D-{first_digits}-{last_two_digits}` where the split depends on the number length.
For 4-digit depots like 1034: `D-10-34`.

### GCP Project Resolution

Resolve the GCP project based on the workload (WL) that owns each component. Use `gcloud projects list` to find the exact project IDs matching the pattern.

**Component → Workload mapping:**

| Component | Workload | GCP Project Pattern (test) |
|-----------|----------|----------------------------|
| New Dispo Backend | WL4 | `prj-cal-w-wl4-t-*` |
| New Dispo Frontend | WL4 | `prj-cal-w-wl4-t-*` |
| TMS Bridge | WL5 | `prj-cal-w-wl5-t-*` |
| TMS Database | WL5 | `prj-cal-w-wl5-t-*` (AlloyDB) |
| Cloud Functions | WL5 | `prj-cal-w-wl5-t-*` |

For UAT/PROD, the project pattern changes (the `-t-` segment changes).

### Cloud Run Service Names

List services with `gcloud run services list --project={PROJECT_ID}` to find the actual service names. Common patterns:
- Backend: `cal-new-disposition-backend-t-t`
- Backend UAT: `cal-new-disposition-backend-t-t-uat`
- TMS Bridge: `cal-new-disposition-tmsbridge-t-t`
- Frontend: `cal-new-disposition-frontend-t-t`

## Phase 3: Identify Components

Use CLAUDE.md to map repository folders to component names. Based on the ticket description, repro steps, and any endpoint mentioned, identify:
1. Which component owns the failing feature
2. Which upstream/downstream components are involved
3. The GCP project and Cloud Run service for each

## Phase 4: Code Analysis

Spawn an `Explore` agent to find the relevant code:
- The endpoint / feature mentioned in the ticket
- The full request flow (controller → handler → service → external calls)
- Error handling and logging patterns
- Configuration (credentials, retry settings, timeouts)
- Any external dependencies (GraphQL calls to TMS Bridge, REST calls, database queries)

Focus on:
- **What can fail** at each step in the flow
- **How errors are handled** (caught, logged, propagated, swallowed)
- **What gets logged** (full exception vs. just message, structured vs. unstructured)
- **What the caller sees** (HTTP status code, error response body)

## Phase 5: GCP Log Investigation

### Authentication Check

First verify gcloud auth:
```bash
gcloud auth list
```
If tokens are expired, ask the user to run `! gcloud auth login`.

### Log Query Strategy

Use the ticket creation date as the time anchor. Query in this order:

#### Step 1: HTTP Request Logs

Find the specific endpoint calls around the ticket creation time:
```bash
gcloud logging read 'resource.type="cloud_run_revision"
  AND resource.labels.service_name="{SERVICE}"
  AND httpRequest.requestUrl=~"{ENDPOINT_PATTERN}"'
  --project={PROJECT} --format=json --freshness=14d --limit=20
```

Look at:
- HTTP status codes (200 vs 500 — note: 200 doesn't mean success if errors are swallowed)
- Response latencies (fast failures suggest early-stage errors)
- Request patterns (frequency, clustering)

#### Step 2: Application Error Logs

Query structured application logs (Serilog JSON format):
```bash
gcloud logging read 'resource.type="cloud_run_revision"
  AND resource.labels.service_name="{SERVICE}"
  AND jsonPayload."ActionName"=~"{CONTROLLER_ACTION}"
  AND jsonPayload."@l"="Error"'
  --project={PROJECT} --format=json --freshness=14d --limit=20
```

The Serilog JSON payload fields:
- `@m` — log message
- `@l` — log level (Error, Warning, etc.)
- `@x` — exception with stack trace (if the developer logged it properly)
- `@tr` — W3C trace ID
- `@sp` — span ID
- `@t` — timestamp
- `ActionName` — the controller action that produced the log
- `SourceContext` — the logger category (class name)
- `RequestPath` — the HTTP path

#### Step 3: Cross-Component Correlation

If the error involves multiple components (e.g., Backend → TMS Bridge):

1. Extract trace IDs (`@tr`) from the error logs in the primary component
2. Query the downstream component's logs in its GCP project using the same trace IDs:
   ```bash
   gcloud logging read 'resource.type="cloud_run_revision"
     AND resource.labels.service_name="{DOWNSTREAM_SERVICE}"
     AND timestamp >= "{ERROR_TIME_MINUS_5S}"
     AND timestamp <= "{ERROR_TIME_PLUS_5S}"'
     --project={DOWNSTREAM_PROJECT} --format=json --limit=20
   ```
3. Match trace IDs to confirm the error chain
4. Extract the actual root cause from the downstream component's logs (which often has the real exception)

#### Step 4: Timeline Reconstruction

Build a timeline of ALL log entries around the error:
```bash
gcloud logging read 'resource.type="cloud_run_revision"
  AND resource.labels.service_name="{SERVICE}"
  AND timestamp >= "{ERROR_TIME_MINUS_1M}"
  AND timestamp <= "{ERROR_TIME_PLUS_1M}"'
  --project={PROJECT} --format=json --limit=50
```

This reveals:
- What happened immediately before and after the error
- Whether other requests succeeded (isolates the failure)
- Whether the error is specific to certain data/depots

### Interpreting Response Latencies

Response latency is a powerful signal for where in the flow the error occurred:

| Latency Pattern | Likely Failure Point |
|-----------------|---------------------|
| < 50ms | Very early failure (auth, validation, immediate exception) |
| 50–300ms | Single external call failed (one GraphQL/API roundtrip) |
| 300–1000ms | External call succeeded, processing failed |
| > 1000ms | Multiple operations completed before failure |

Compare error latencies against successful request latencies for the same endpoint.

## Phase 6: Write Bug Analysis Report

Create the report at:
```
20_Bug-Analysis/{TICKET_CREATION_DATE}_BUG-{TICKET_ID}_{Title-In-Kebab-Case}.md
```

### Report Template

The report MUST include these sections in order:

```markdown
# BUG-{ID}: {Title}

## Ticket Info
(Table with all ticket metadata — see Phase 1 fields)

## Components Involved
(Table: Component | Repository | Role | GCP Project / Service)

## Architecture of the {Feature} Flow
(Mermaid sequence diagram showing component interactions)
(Error zones in red: rect rgb(255, 220, 220))
(Risk zones in orange: rect rgb(255, 235, 200))

### Error Zone Summary
(Table: Zone | Location | Error | Active Period | Root Cause)

### Key Files
(Bullet list of relevant source files)

## Log Evidence (GCP Cloud Run, {environment})
(Summary statement: failure rate, HTTP status anomalies)

### Phase N: {Error Description} ({date range})
(Table: Timestamp | Latency | Error Message)
(Interpretation paragraph)
(Repeat for each distinct error phase)

## Log Entry Correlation: Confirming Error Attribution
(For each error zone: explain WHY the error is attributed to that component)
(Include trace ID match tables when cross-component correlation was performed)
(Explain exception type provenance — which library produces which message)

## Root Causes
### 1. {Root Cause Title}
(Explanation with file:line references)
(Repeat for each root cause)

## Recommendations
### Immediate
### Short-Term
### Medium-Term

---

<div align="center">
  <sub>Created and maintained by <strong>Virtual Architect</strong></sub>
</div>
```

### Diagram Conventions

- Error zones (confirmed errors): `rect rgb(255, 220, 220)` (red)
- Risk zones (potential/untested paths): `rect rgb(255, 235, 200)` (orange)
- Include the actual error messages in the diagram notes
- Show ALL components that participate in the flow, including databases

## Phase 7: Publish to Wiki (on user request only)

Only publish when the user explicitly asks. Target location:
```
WIKI/Nagel-CAL-Disposition.wiki/Sandbox-(Internal)/Bug-Analysis-(Automated)/
```

Wiki page naming convention (Azure DevOps wiki URL-encoding):
```
{YYYY}%2D{MM}%2D{DD}-{TICKET_ID}-{Title-in-kebab-case}.md
```

Steps:
1. Copy the report to the wiki directory
2. Update `.order` file — add new entry at the top
3. Commit: `bug-analysis: {TICKET_ID}`
4. Push to remote

If the wiki file already exists:
- **Empty**: overwrite with the report
- **Non-empty**: append the report content (the file may contain a previous analysis)

## Phase 8: Comment on Ticket

After publishing to the wiki, add a comment to the Azure DevOps work item linking to the analysis.

### Build the Wiki URL

The wiki page URL requires the numeric page ID:
```
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/{PAGE_ID}/{PAGE_NAME_WITH_DASHES}
```

**Important:** Do NOT use the `?pagePath=` query parameter format — it does not work.

After pushing to the wiki, retrieve the page ID using `az devops wiki page show`:
```bash
az devops wiki page show --wiki "Nagel-CAL-Disposition.wiki" \
  --path "/Sandbox (Internal)/Bug Analysis (Automated)/{WIKI_PAGE_TITLE_WITH_SPACES}" \
  --output json
```

The page ID is in `.page.id` of the JSON response.

**Critical: Wiki path vs. git filename mapping:**
- Git filenames use `%2D` for dashes and `-` between words: `2026%2D06%2D10-124918-Email-can-not-be-sent.md`
- Wiki paths use spaces between words, dashes only in dates: `2026-06-10 124918 Email can not be sent`
- Folder `Bug-Analysis-(Automated)` → wiki path `Bug Analysis (Automated)`
- Folder `Sandbox-(Internal)` → wiki path `Sandbox (Internal)`

Then construct the URL:
```
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_wiki/wikis/Nagel-CAL-Disposition.wiki/{PAGE_ID}/2026-06-10-124918-Email-can-not-be-sent
```

The page name in the URL slug uses dashes (not spaces) — this is the display slug, not the wiki path.

### Post the Comment

Use the Azure CLI:
```bash
az boards work-item update --id {TICKET_ID} --org https://dev.azure.com/p3ds --discussion "Bug analysis completed by Virtual Architect. Report: <a href=\"{WIKI_URL}\">{WIKI_PAGE_NAME}</a>"
```

The `--discussion` flag adds a comment to the work item's discussion thread. Use an HTML anchor tag so the link is clickable in Azure DevOps.

## Error Handling

### GCP Auth Expired
Ask the user: "GCP auth has expired. Please run `! gcloud auth login` to re-authenticate."

### Azure DevOps CLI Not Available
Fall back to `WebFetch` on the ticket URL (will fail on auth redirect — inform user that `az` CLI is needed).

### No Logs Found
- Verify the service name and project are correct
- Try broader time windows (extend freshness)
- Try without severity filters
- Check if the service exists: `gcloud run services list --project={PROJECT}`
- Report what was searched and what was not found — absence of evidence is still evidence

### Insufficient Log Detail
When logs lack stack traces or context (e.g., `_logger.LogError(ex.Message)` pattern), document this as a finding. It's a root cause in itself — the logging is inadequate and should be flagged as a recommendation.

## Tips

- Always query BOTH the HTTP request logs (from Cloud Run) AND the application logs (from Serilog) — they tell different stories
- Response latency from HTTP request logs is often the best clue for localizing the failure point
- When errors say "HTTP request failed with InternalServerError", check WHICH HTTP client library produced the error — different libraries have different exception types and message formats
- The Backend uses `GraphQL.Client.Http.GraphQLHttpClient` for TMS Bridge calls and `Microsoft.Graph.GraphServiceClient` for email — these never share exception types
- Cross-component trace correlation is the gold standard for confirming error attribution — always attempt it when multiple components are involved
