# Do We Need Frontend Aggregation?

## The Question

With Cloud Storage archiving individual component versions, do we need Frontend to aggregate them into one JSON file?

## Use Case Analysis

### Use Case 1: User Reports Bug

**With aggregation:**
```
User: "I have a bug. My version shows 2.2.0"
Support: Downloads gs://.../aggregated/...2.2.0.json
Support sees:
  - Frontend: 20260223.5 (commit: abc123)
  - Backend: 20260223.3 (commit: def456)
  - TMS Bridge: 20260223.2 (commit: ghi789)
```

**Without aggregation:**
```
User: "I have a bug. My version shows 20260223.5"
Support: "What time did this happen?"
User: "Around 2pm"
Support: Downloads all components from ~2pm
  - gs://.../frontend/2026-02-23_14-00-00_20260223.5.json
  - gs://.../backend/2026-02-23_10-30-00_20260223.3.json (last deployed at 10:30)
  - gs://.../tms-bridge/2026-02-23_09-15-00_20260223.2.json (last deployed at 9:15)
```

**Key insight:** Without aggregation, you need to manually correlate timestamps to figure out which versions were running together.

### Use Case 2: Support Debugging

**With aggregation:**
- One download, all component versions + commits
- Immediate visibility: "These versions were running together"

**Without aggregation:**
- Download 3 files from different timestamps
- Manually figure out: "At 2pm, which backend was deployed?"

### Use Case 3: Displaying Version to User

**With aggregation:**
```
UI shows: "New Dispo v2.2.0"
Details: Frontend 20260223.5, Backend 20260223.3, etc.
```

**Without aggregation:**
```
UI shows: "Frontend v20260223.5"
User has no idea what backend version they're using
```

## Three Alternatives

### Alternative 1: No Aggregation (Simplest)

**What:**
- Each component serves only its own version.json
- No aggregation, no staleness issue
- For bug reports: manually correlate Cloud Storage archives by timestamp

**Pros:**
- Simplest implementation
- No staleness problem
- Each component completely independent

**Cons:**
- More complex bug report workflow
- Manual timestamp correlation needed
- User can't easily report "system version"

**Bug report workflow:**
```bash
# User: "Bug at 2pm today"
# Support must query all components around that time:

gsutil ls gs://.../frontend/ | grep "2026-02-23_14"
gsutil ls gs://.../backend/ | grep "2026-02-23"  # Find last deploy before 14:00
gsutil ls gs://.../tms-bridge/ | grep "2026-02-23"  # Find last deploy before 14:00

# Download all three, extract commits
```

### Alternative 2: Aggregation Only in UI (Current Proposal)

**What:**
- Frontend aggregates versions during its build
- Serves aggregated version.json
- Subject to staleness (only current when Frontend deploys)

**Pros:**
- Single version number for user to report
- Easy bug report workflow
- One file shows complete system state

**Cons:**
- Staleness: aggregated version lags behind component deployments
- Additional aggregation logic
- Needs handling of unreachable services

**Bug report workflow:**
```bash
# User: "Bug in version 2.2.0"
gsutil ls gs://.../aggregated/ | grep "2.2.0"
gsutil cp gs://.../aggregated/2026-02-23_14-00-00_2.2.0.json ./
# One file, all versions
```

### Alternative 3: Live Aggregation Endpoint (Most Accurate, More Complex)

**What:**
- Backend serves an endpoint that queries all services live
- No static aggregated file
- Always current, no staleness

**Implementation:**
```csharp
// Backend endpoint
[HttpGet("api/system/version")]
public async Task<IActionResult> GetSystemVersion()
{
    var frontendVersion = await httpClient.GetAsync("https://frontend/assets/version.json");
    var backendVersion = GetOwnVersion();
    var tmsBridgeVersion = await httpClient.GetAsync("https://tms-bridge/version.json");

    return Ok(new {
        aggregated = true,
        timestamp = DateTime.UtcNow,
        components = new {
            frontend = frontendVersion,
            backend = backendVersion,
            tmsBridge = tmsBridgeVersion
        }
    });
}
```

**Pros:**
- Always current, no staleness
- Single endpoint for system version
- Can be called from Frontend or by support

**Cons:**
- Adds runtime dependency (Backend calls other services)
- Slower (network calls)
- Fails if any service is down
- More complex implementation

## Recommendation

### For Validation Phase: **Alternative 1 (No Aggregation)**

**Why:**
1. **Simplest to implement and validate** the versioning concept
2. **No staleness issues** to worry about
3. **Proves the value** of versioning for bug reports
4. Can add aggregation later if needed

**User sees in UI:**
```
Frontend version: 20260223.5
Build: 2026-02-23 14:00:00
```

**Bug report workflow:**
```bash
# User: "Bug at 2pm today"
# Support queries Cloud Storage:

# Get frontend version at 2pm
gsutil ls gs://.../frontend/ | grep "2026-02-23_14"
# Download: 2026-02-23_14-00-00_20260223.5.json → commit abc123

# Get backend deployed before 2pm (last one)
gsutil ls gs://.../backend/ | grep "2026-02-23"
# Find: 2026-02-23_10-30-00_20260223.3.json → commit def456

# Get TMS bridge deployed before 2pm (last one)
gsutil ls gs://.../tms-bridge/ | grep "2026-02-23"
# Find: 2026-02-23_09-15-00_20260223.2.json → commit ghi789

# Now checkout all three commits and reproduce
```

**Script to help support (optional):**
```bash
#!/bin/bash
# get-versions-at-time.sh

TIMESTAMP=$1  # e.g., "2026-02-23_14-00-00"
ENV=${2:-t-t}

echo "Finding versions deployed at $TIMESTAMP..."

for component in frontend backend tms-bridge; do
  # Find latest version before timestamp
  VERSION=$(gsutil ls gs://newdispo-version-history/$ENV/$component/ | \
    grep -E "^.*202[0-9]-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}" | \
    awk -v ts="$TIMESTAMP" '$0 <= ts' | \
    tail -1)

  echo "$component: $VERSION"
  gsutil cp "$VERSION" ./${component}-version.json
done

echo "Downloaded all versions. Extracting commits:"
jq -r '.commit' frontend-version.json
jq -r '.commit' backend-version.json
jq -r '.commit' tms-bridge-version.json
```

### If No Aggregation Proves Insufficient: Add Alternative 2 or 3

After validation, if the team finds:
- Manual timestamp correlation too cumbersome
- Need for "single version number" from users

Then implement:
- **Alternative 2** if Frontend deployments are frequent enough
- **Alternative 3** if need always-current system version

## Decision Framework

| Scenario | Recommendation |
|----------|----------------|
| Frontend deploys 10+ times/day | Alternative 1 (no aggregation) |
| Frontend deploys 1-2 times/day, Backend 10+ times/day | Alternative 1 or 3 |
| Need "single version number" for communication | Alternative 2 or 3 |
| Validation phase | **Alternative 1** (simplest) |

## Simplified Implementation

**Skip aggregation entirely:**

1. **Frontend** - serves only its own version:
   - `GET /assets/version.json` → Frontend version only

2. **Backend** - serves only its own version:
   - `GET /version.json` → Backend version only

3. **TMS Bridge** - serves only its own version:
   - `GET /version.json` → TMS Bridge version only

4. **Frontend UI** - shows only Frontend version:
   ```typescript
   // Simple component
   <div>Version: {{ version.version }}</div>
   ```

5. **Bug reports** - support uses Cloud Storage + script:
   ```bash
   ./get-versions-at-time.sh 2026-02-23_14-00-00
   ```

## Conclusion

**Start without aggregation.** It's simpler, has no staleness issues, and validates the core concept. Add aggregation only if the manual correlation proves too cumbersome.

The value of versioning is in the individual component versions + Cloud Storage history, not necessarily in the aggregation.
