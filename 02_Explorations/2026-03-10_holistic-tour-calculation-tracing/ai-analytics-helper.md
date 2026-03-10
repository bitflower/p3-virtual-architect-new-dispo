# AI/Analytics Helper - Processing Trace Files

**Purpose:** Examples and scripts for feeding trace files into AI agents or analytics pipelines.

## Trace File Format

Each trace file is a JSON document with this structure:

```json
{
  "TraceId": "trace-1710073245-abc123",
  "StartTime": "2026-03-10T14:30:45.123Z",
  "EndTime": "2026-03-10T14:30:51.456Z",
  "DurationMs": 6333,
  "CaptureCount": 11,
  "Components": ["Frontend", "Backend", "TMSBridge"],
  "Captures": [
    {
      "Component": "Backend",
      "CapturePoint": "AfterGetPoolDto",
      "Direction": "Response",
      "Timestamp": "2026-03-10T14:30:46.234Z",
      "TimestampIso": "2026-03-10T14:30:46.2340000Z",
      "Data": {
        "PoolDto": { /* complete PoolDTO structure */ },
        "Summary": { /* metadata */ }
      }
    }
    // ... more captures
  ]
}
```

## Loading Traces for Analysis

### C# - Batch Load for Date

```csharp
// In your analytics service or background job
public class TraceAnalyzer
{
    private readonly ITraceCapture _traceCapture;

    public async Task AnalyzeDailyTracesAsync(DateTime date)
    {
        if (_traceCapture is FileBasedTraceCapture fileCapture)
        {
            // Load all traces for the date
            var traceJsons = await fileCapture.LoadTracesForDateAsync(date);

            foreach (var traceJson in traceJsons)
            {
                // Parse and analyze
                var trace = JsonSerializer.Deserialize<TraceDocument>(traceJson);

                // Extract specific data for analysis
                var poolDtos = ExtractPoolDtos(trace);
                var timezoneIssues = DetectTimezoneIssues(poolDtos);
                var performanceIssues = DetectPerformanceIssues(trace);

                // Send to AI agent or store in analytics DB
                await SendToAIAgent(trace, timezoneIssues, performanceIssues);
            }
        }
    }

    private List<PoolDto> ExtractPoolDtos(TraceDocument trace)
    {
        return trace.Captures
            .Where(c => c.CapturePoint == "AfterGetPoolDto" || c.CapturePoint == "AfterTOPService")
            .Select(c => c.Data.PoolDto ?? c.Data.EnrichedPoolDto)
            .Where(p => p != null)
            .ToList();
    }
}
```

### Python - Load and Analyze Traces

```python
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

class TraceAnalyzer:
    def __init__(self, traces_base_path="traces"):
        self.traces_base_path = Path(traces_base_path)

    def load_traces_for_date(self, date: datetime) -> list:
        """Load all traces for a specific date."""
        date_str = date.strftime("%Y-%m-%d")
        date_path = self.traces_base_path / date_str

        if not date_path.exists():
            return []

        traces = []
        for trace_file in date_path.glob("*.json"):
            with open(trace_file, 'r') as f:
                traces.append(json.load(f))

        return traces

    def load_recent_traces(self, days=7) -> list:
        """Load traces from the last N days."""
        all_traces = []
        for i in range(days):
            date = datetime.now() - timedelta(days=i)
            traces = self.load_traces_for_date(date)
            all_traces.extend(traces)

        return all_traces

    def extract_pool_dtos(self, trace: dict) -> list:
        """Extract all PoolDTO objects from a trace."""
        pool_dtos = []

        for capture in trace.get("Captures", []):
            if capture.get("CapturePoint") == "AfterGetPoolDto":
                if "PoolDto" in capture.get("Data", {}):
                    pool_dtos.append({
                        "stage": "from_database",
                        "timestamp": capture.get("Timestamp"),
                        "data": capture["Data"]["PoolDto"]
                    })

            elif capture.get("CapturePoint") == "AfterTOPService":
                if "EnrichedPoolDto" in capture.get("Data", {}):
                    pool_dtos.append({
                        "stage": "after_top",
                        "timestamp": capture.get("Timestamp"),
                        "data": capture["Data"]["EnrichedPoolDto"]
                    })

        return pool_dtos

    def analyze_timezone_issues(self, traces: list) -> list:
        """Analyze traces for timezone inconsistencies."""
        issues = []

        for trace in traces:
            pool_dtos = self.extract_pool_dtos(trace)

            for pool_dto_capture in pool_dtos:
                pool_dto = pool_dto_capture["data"]

                # Check PlanningInterval for missing timezone
                interval = pool_dto.get("PlanningInterval", {})
                start = interval.get("Start", "")
                end = interval.get("End", "")

                if start and not ("+" in start or "Z" in start):
                    issues.append({
                        "trace_id": trace["TraceId"],
                        "issue": "missing_timezone",
                        "field": "PlanningInterval.Start",
                        "value": start,
                        "stage": pool_dto_capture["stage"]
                    })

                if end and not ("+" in end or "Z" in end):
                    issues.append({
                        "trace_id": trace["TraceId"],
                        "issue": "missing_timezone",
                        "field": "PlanningInterval.End",
                        "value": end,
                        "stage": pool_dto_capture["stage"]
                    })

        return issues

    def generate_summary_report(self, traces: list) -> dict:
        """Generate a summary report for AI analysis."""
        return {
            "total_traces": len(traces),
            "date_range": {
                "start": min(t["StartTime"] for t in traces),
                "end": max(t["EndTime"] for t in traces)
            },
            "avg_duration_ms": sum(t["DurationMs"] for t in traces) / len(traces) if traces else 0,
            "timezone_issues": self.analyze_timezone_issues(traces),
            "performance_issues": self.analyze_performance(traces)
        }

    def analyze_performance(self, traces: list) -> list:
        """Identify slow traces."""
        issues = []
        avg_duration = sum(t["DurationMs"] for t in traces) / len(traces) if traces else 0

        for trace in traces:
            if trace["DurationMs"] > avg_duration * 2:  # More than 2x average
                issues.append({
                    "trace_id": trace["TraceId"],
                    "duration_ms": trace["DurationMs"],
                    "avg_duration_ms": avg_duration,
                    "slowdown_factor": trace["DurationMs"] / avg_duration
                })

        return issues

# Usage example
analyzer = TraceAnalyzer()

# Load recent traces
traces = analyzer.load_recent_traces(days=7)

# Generate summary for AI
summary = analyzer.generate_summary_report(traces)

# Save summary for AI agent
with open("traces_summary.json", "w") as f:
    json.dump(summary, f, indent=2)
```

### Node.js/TypeScript - Feed to AI Agent

```typescript
import * as fs from 'fs/promises';
import * as path from 'path';

interface TraceDocument {
  TraceId: string;
  StartTime: string;
  EndTime: string;
  DurationMs: number;
  CaptureCount: number;
  Components: string[];
  Captures: CapturePoint[];
}

interface CapturePoint {
  Component: string;
  CapturePoint: string;
  Direction: string;
  Timestamp: string;
  Data: any;
}

class TraceProcessor {
  constructor(private tracesBasePath: string = 'traces') {}

  async loadTracesForDate(date: Date): Promise<TraceDocument[]> {
    const dateStr = date.toISOString().split('T')[0];
    const datePath = path.join(this.tracesBasePath, dateStr);

    try {
      const files = await fs.readdir(datePath);
      const traces: TraceDocument[] = [];

      for (const file of files) {
        if (file.endsWith('.json')) {
          const content = await fs.readFile(path.join(datePath, file), 'utf-8');
          traces.push(JSON.parse(content));
        }
      }

      return traces;
    } catch (error) {
      return [];
    }
  }

  async sendToAIAgent(traces: TraceDocument[]): Promise<void> {
    // Prepare data for AI agent
    const payload = {
      task: "analyze_tour_calculation_traces",
      traces: traces.map(t => ({
        traceId: t.TraceId,
        duration: t.DurationMs,
        captures: t.Captures.map(c => ({
          component: c.Component,
          point: c.CapturePoint,
          data: c.Data
        }))
      })),
      questions: [
        "Are there any timezone inconsistencies?",
        "Are there any data transformation issues?",
        "What is causing performance bottlenecks?"
      ]
    };

    // Example: Send to Claude API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4096,
        messages: [{
          role: 'user',
          content: `Analyze these tour calculation traces and identify issues:\n\n${JSON.stringify(payload, null, 2)}`
        }]
      })
    });

    const analysis = await response.json();
    console.log('AI Analysis:', analysis);

    // Save analysis
    await fs.writeFile(
      `analysis-${Date.now()}.json`,
      JSON.stringify(analysis, null, 2)
    );
  }

  extractPoolDtoComparison(trace: TraceDocument): any {
    const beforeTOP = trace.Captures.find(c => c.CapturePoint === 'AfterGetPoolDto');
    const afterTOP = trace.Captures.find(c => c.CapturePoint === 'AfterTOPService');

    return {
      traceId: trace.TraceId,
      before: beforeTOP?.Data.PoolDto,
      after: afterTOP?.Data.EnrichedPoolDto,
      changes: this.detectChanges(
        beforeTOP?.Data.PoolDto,
        afterTOP?.Data.EnrichedPoolDto
      )
    };
  }

  private detectChanges(before: any, after: any): string[] {
    const changes: string[] = [];

    // Compare location count
    const beforeLocations = before?.Locations?.length || 0;
    const afterLocations = after?.Locations?.length || 0;
    if (beforeLocations !== afterLocations) {
      changes.push(`Location count changed: ${beforeLocations} → ${afterLocations}`);
    }

    // Check if Plans were added (by TOP)
    if (!before?.Plans && after?.Plans) {
      changes.push(`Plans added by TOP: ${after.Plans.length} plan(s)`);
    }

    return changes;
  }
}

// Usage
const processor = new TraceProcessor();

// Load today's traces
const today = new Date();
const traces = await processor.loadTracesForDate(today);

// Send to AI for analysis
await processor.sendToAIAgent(traces);
```

## Prompts for AI Analysis

### Example 1: Timezone Issue Detection

```
Analyze these tour calculation traces and identify timezone-related issues.

For each trace, examine:
1. PlanningDate and PlanningInterval fields
2. Location OpeningIntervals
3. TourElement StartTime/EndTime values

Identify:
- Missing timezone indicators (+HH:MM or Z)
- Inconsistent timezone formats
- Timezone conversion issues

Provide specific field paths and values for each issue found.
```

### Example 2: Data Transformation Analysis

```
Compare the PoolDTO before and after TOP Service processing.

Before TOP (AfterGetPoolDto capture):
{before_pool_dto}

After TOP (AfterTOPService capture):
{after_pool_dto}

Identify:
1. What fields were added by TOP?
2. What fields were modified?
3. Are the transformations correct?
4. Are there any unexpected changes?
```

### Example 3: Performance Analysis

```
Analyze performance bottlenecks in these traces.

For each trace:
- Total duration: {DurationMs}ms
- Time in TMS Bridge calls
- Time in TOP Service
- Time in Backend processing

Identify:
1. Which component is the bottleneck?
2. Are there any unusually slow operations?
3. What is the baseline vs. outlier performance?
```

## Batch Processing Script

Create a file `analyze-traces.sh`:

```bash
#!/bin/bash

# Analyze traces from yesterday
DATE=$(date -d "yesterday" +%Y-%m-%d)
TRACES_DIR="traces/$DATE"

echo "Analyzing traces for $DATE..."

# Count traces
TRACE_COUNT=$(ls -1 $TRACES_DIR/*.json 2>/dev/null | wc -l)
echo "Found $TRACE_COUNT traces"

# Extract all PoolDTOs
jq '.Captures[] | select(.CapturePoint == "AfterGetPoolDto") | .Data.PoolDto' \
  $TRACES_DIR/*.json > pool_dtos_$DATE.json

# Detect timezone issues
jq '.Captures[] | select(.CapturePoint == "AfterGetPoolDto") |
  .Data.PoolDto.PlanningInterval |
  select(.Start | test("\\+|Z") | not)' \
  $TRACES_DIR/*.json > timezone_issues_$DATE.json

echo "Analysis complete. Files created:"
echo "  - pool_dtos_$DATE.json"
echo "  - timezone_issues_$DATE.json"

# Feed to AI agent (example using Claude CLI)
cat pool_dtos_$DATE.json | claude "Analyze these PoolDTOs for common issues"
```

Make executable:
```bash
chmod +x analyze-traces.sh
```

## Integration with Analytics Dashboard

### Example: Load into Elasticsearch

```python
from elasticsearch import Elasticsearch
import json
from pathlib import Path

es = Elasticsearch(['http://localhost:9200'])

def index_traces(date):
    """Index traces into Elasticsearch for querying."""
    traces_path = Path(f"traces/{date.strftime('%Y-%m-%d')}")

    for trace_file in traces_path.glob("*.json"):
        with open(trace_file, 'r') as f:
            trace = json.load(f)

            # Index trace document
            es.index(
                index='tour-calculation-traces',
                id=trace['TraceId'],
                document=trace
            )

            # Index each capture point separately for fine-grained queries
            for i, capture in enumerate(trace['Captures']):
                es.index(
                    index='tour-calculation-captures',
                    document={
                        'trace_id': trace['TraceId'],
                        'capture_index': i,
                        'component': capture['Component'],
                        'capture_point': capture['CapturePoint'],
                        'timestamp': capture['Timestamp'],
                        'data': capture['Data']
                    }
                )

# Usage
from datetime import datetime
index_traces(datetime.now())
```

### Example Queries

```json
// Find all traces with timezone issues
GET tour-calculation-captures/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "capture_point": "AfterGetPoolDto" } },
        { "script": {
          "script": "doc['data.PoolDto.PlanningInterval.Start'].value.indexOf('+') == -1"
        }}
      ]
    }
  }
}

// Find slow traces (> 10 seconds)
GET tour-calculation-traces/_search
{
  "query": {
    "range": {
      "DurationMs": { "gte": 10000 }
    }
  }
}
```

## Tips for AI Analysis

1. **Provide Context**: Include domain knowledge in your prompts
   ```
   "In tour calculation, PlanningInterval should have timezone information.
   Times without timezone are ambiguous and cause calculation errors."
   ```

2. **Be Specific**: Ask for actionable insights
   ```
   "For each issue found, provide:
   - Trace ID
   - Exact field path (e.g., PoolDto.PlanningInterval.Start)
   - Current value
   - Expected value
   - Root cause analysis"
   ```

3. **Batch Similar Traces**: Group traces by pattern for efficiency
   ```python
   # Group traces by similar issues
   timezone_issues = [t for t in traces if has_timezone_issue(t)]
   performance_issues = [t for t in traces if t['DurationMs'] > 10000]
   ```

4. **Save AI Insights**: Store analysis results alongside traces
   ```
   traces/2026-03-10/
   ├── trace-xxx.json
   ├── trace-yyy.json
   └── ai-analysis-2026-03-10.json  # AI's findings
   ```

## Next Steps

1. Implement FileBasedTraceCapture in your backend
2. Run a few tour calculations to generate traces
3. Use the Python script to load and analyze
4. Feed into your preferred AI agent (Claude, GPT-4, etc.)
5. Iterate on prompts based on insights gained
