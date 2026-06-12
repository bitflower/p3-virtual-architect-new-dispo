# Traffic Mode Change Escalation - Changing Traffic Mode Meeting 2026-06-05

**Date:** 2026-06-12
**Status:** Exploration
**Source:** Meeting transcript `00_Meetings/2026-06-05_Changing Traffic mode/`

---

## Meeting Context

- **Meeting:** Changing Traffic Mode (2026-06-05, Friday)
- **Participants:** Beisheim (Maximilian), Maximilian Kehder, Boyan Valchev, Joachim Schreiner, Anna Kaupmann
- **Matthias Max:** On vacation (returned Monday 2026-06-08)

---

## The Core Topic

When a shipment's **traffic mode** changes in classic TMS (e.g. from mode 3 to mode 2 or 4), the system needs to react -- especially when that shipment is already assigned to a transport order with legs (e.g. pickup legs). The old legs may become invalid and need cleanup.

**Central question:** Who should handle the traffic mode change -- classic TMS or New Dispo (via CDC)?

### Joachim's Technical Proposal (~29:36)

Joachim Schreiner proposed a solution: CDC detects the traffic mode change, then before creating new long-haul legs, invoke a TMS function to clean up the previous pickup legs -- the same approach TMS uses internally.

> "CDC detects change of traffic mode. So the current traffic mode was three. [...] before creating the new legs, the long haul legs, you also could invoke TMS function to clean up the previous pickup legs, it's the same I would do in TMS."

### The Conflict: Ownership & Responsibility

**Beisheim's position (Nagel side):** This is the dev team's job. Should have been done long ago.

> "That's what I exactly see as also your job to do. And you should have done it a long time ago." (30:28)

**Kehder's position:** Focus on the timeline (deadline: June 16th). A quick TMS-side restriction of the traffic mode change field would be the minimal effort solution. The restriction needs to happen on TMS side anyway at some point, so it's not double work.

> "My focus is on the timeline. We have agreed that we want to have a timeline for the 16th." (34:14)
> "The question is, how much effort is it to restrict this change now?" (32:02)

---

## The Escalation (32:46 - 34:33)

Beisheim perceived Kehder's proposal as deflecting work onto Nagel's internal people rather than solving it within the dev team's own scope. The exchange escalated:

**Beisheim** (32:46): *"This is amazing how you start your discussions and pushing effort to other people instead of trying to solve it within their own company when it was your project."*

**Beisheim** (33:08): *"I have never, never, ever heard a third party giving jobs to our own people as the way you just did. And it's very, very rude what you just said and how you said it."*

**Beisheim** (33:24): *"And you should watch out who you are working for, Max."*

**Kehder** (33:30) tried to respond: *"Max, I hear you. May I say something or do you want?"*

**Beisheim**: *"No."*

**Beisheim** then demanded an answer by Monday, threatened to escalate to Martin, and cut off the discussion:

> "I would expect you to deliver an answer until Monday. Otherwise, I'll try to call Martin if he then can answer that and he will talk to you and what's your decision on how doing it. Maybe even Matthias can decide if it is possible." (33:45)

> "But I don't quite understand why you're not trying to help us here or try to solve the problem as Joachim suggested." (34:07)

**Beisheim** (34:29): *"Okay, Boyan, Boyan, continue. I don't want to listen to much anymore."*

---

## Boyan's De-escalation (34:33 - 36:28)

Boyan took over and struck a diplomatic tone. Key points:

1. **Dev team is willing:** "From development point of view, we are not reluctant to doing this."
2. **Wants correct approach first:** "It's just like my idea here is like, what is the correct way to do it?"
3. **Proposed next steps:** Wait for Matthias to return Monday, have Joachim + Christian + Matthias make the architectural decision on whether New Dispo should handle this.
4. **Deferred to architecture:** "I don't want to push for anything because I'm not an architect in the end. I mean, we have a dedicated architect, so let's just follow the process, just discuss it."

**Kehder** confirmed: *"He's back on Monday."* (referring to Matthias)

---

## Key Tensions

| Dimension | Beisheim (Nagel) | Kehder (CAL Consult) |
|---|---|---|
| **Priority** | Solve the problem correctly | Meet the June 16th deadline |
| **Ownership** | Dev team should handle it | TMS-side restriction is minimal effort |
| **Perception** | Kehder is pushing work onto Nagel people | Proposing the pragmatic path |
| **Tone** | Escalated, personal | Tried to stay factual |

---

## Open Items

- [ ] Architectural decision needed: Should traffic mode change handling live in New Dispo (CDC-based) or classic TMS (restriction-based)?
- [ ] Joachim's proposal (CDC detect + TMS cleanup function) needs evaluation for feasibility and effort
- [ ] June 16th deadline -- what is the minimal viable approach?
- [ ] Beisheim threatened to escalate to Martin -- did that happen?

---

## Related Files

- `00_Meetings/2026-06-05_Changing Traffic mode/2026-06-05_Changing Traffic mode (0).vtt`
- `00_Meetings/2026-06-05_Changing Traffic mode/2026-06-05_Changing Traffic mode (1).vtt`
- `00_Meetings/2026-06-05_Changing Traffic mode internal with joachim .vtt`
- `00_Meetings/2026-06-05_Changing Traffic mode/2026-06-xx_Max-Kehder-Joachim-Traffic-Mode.md`
