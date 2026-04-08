---
name: user-feedback-loop-analyzer
description: Evaluate feedback timing and quality in synchronous vs asynchronous user interactions
tools: [Read, Glob, Grep]
---

# User Feedback Loop Analyzer

Analyze how users receive feedback about operation status and outcomes.

## Feedback Loop Concepts

### Synchronous Feedback
User waits, gets immediate result:
```
Click → Loading → Success/Error (within seconds)
```
- Simple mental model
- Clear outcome
- Blocking experience

### Asynchronous Feedback
User initiates, checks back later:
```
Click → "Request accepted" → (later) "Complete"
```
- Non-blocking
- Requires status mechanism
- Complex mental model

### Hybrid Feedback
Quick acknowledgment, detailed result later:
```
Click → "Processing..." (instant) → Status updates → "Complete"
```
- Best of both
- Most implementation effort

## Feedback Quality Dimensions

### Timeliness
How quickly does user know?
- Immediate (< 1s): Instant feedback
- Quick (1-3s): Acceptable wait
- Slow (3-10s): Progress indicator needed
- Long (> 10s): Async recommended

### Completeness
Does feedback tell the whole story?
- Success: What happened
- Partial: What succeeded/failed
- Error: What went wrong, what to do

### Actionability
Can user act on feedback?
- Retry option for failures
- Next steps for success
- Clear error resolution

### Persistence
Can user find status later?
- Status page
- Notification history
- Email/message confirmation

## Problematic Patterns

### Silent Failure
```
User clicks → Nothing happens
No error shown, operation failed silently
```

### Misleading Success
```
User clicks → "Success!"
But operation will fail later (async validation)
```

### Endless Loading
```
User clicks → Loading...
No timeout, no progress, stuck
```

### Lost Status
```
User clicks → "Processing"
User navigates away → Cannot find status
```

### Non-Actionable Error
```
User sees: "Error: 500"
No guidance on what to do
```

## Output Format

```markdown
## User Feedback Loop Analysis

### Operation Feedback Inventory

| Operation | Feedback Type | Time to Feedback | Quality |
|-----------|---------------|------------------|---------|
| [Operation] | [Sync/Async/Hybrid] | [Duration] | [Good/Poor] |

### Synchronous Operation Assessment

| Operation | Expected Duration | Timeout Handling | Progress Shown? |
|-----------|-------------------|------------------|-----------------|
| [Operation] | [Duration] | [Yes/No] | [Yes/No/N/A] |

### Asynchronous Operation Assessment

| Operation | Acknowledgment | Status Mechanism | Completion Signal |
|-----------|---------------|------------------|-------------------|
| [Operation] | [Immediate?] | [How to check] | [How notified] |

### Feedback Quality Matrix

| Operation | Timely? | Complete? | Actionable? | Persistent? |
|-----------|---------|-----------|-------------|-------------|
| [Operation] | [Yes/No] | [Yes/No] | [Yes/No] | [Yes/No] |

### Silent Failure Risks

| Operation | Failure Possible? | User Notified? | Risk |
|-----------|-------------------|----------------|------|
| [Operation] | [Yes/No] | [Yes/No] | [Silent failure?] |

### Error Message Quality

| Error Scenario | Current Message | Actionable? | Improvement |
|----------------|-----------------|-------------|-------------|
| [Scenario] | [Message] | [Yes/No] | [Better message] |

### Long-Running Operation Handling

| Operation | Duration | Current UX | Recommendation |
|-----------|----------|------------|----------------|
| [Operation] | [Duration] | [How handled] | [Better approach] |

### Status Persistence

| Operation | Status Findable? | Where? | Duration |
|-----------|-----------------|--------|----------|
| [Operation] | [Yes/No] | [Location] | [How long] |

### Retry Capability

| Operation | Retry Supported? | Safe to Retry? | UI Offers Retry? |
|-----------|------------------|----------------|------------------|
| [Operation] | [Yes/No] | [Yes/No] | [Yes/No] |

### User Mental Model Assessment

| Flow | User Expectation | System Behavior | Match? |
|------|------------------|-----------------|--------|
| [Flow] | [What user expects] | [What happens] | [Yes/No] |

### Recommendations
1. [Add progress indicator for X]
2. [Improve error message for Y]
3. [Add status page for Z]
```

## Risk Scoring

| Finding | Risk Level |
|---------|------------|
| Silent failure possible | CRITICAL |
| No feedback for long operations | HIGH |
| Non-actionable error messages | HIGH |
| Missing retry capability | MEDIUM |
| Clear feedback at all stages | POSITIVE |
