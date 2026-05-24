# Communication Root Cause

Christian, the confusion arose because:

1. Cem's escalation mail mixed infrastructure concerns (DevOps, access) with the actual data problem, making it impossible to understand the real issue
2. The term "redesign" was used loosely, causing you to question whether the approved architecture had changed — it has not
3. Matt Wilkinson introduced infrastructure security topics (TMS Bridge public IP, prod secrets) into the same communication thread, further diluting focus
4. The chat format made it impossible to track what is a blocker vs. what is a side topic

I want to be clear on my position: I fully support using real-world data for development and testing, not mock data. New Dispo is the best proof that this approach works — we only achieved the required quality once we had access to real data. The same applies to Cloud4Log and Markant DVA.

**Going forward:** Blockers should be communicated as a numbered list with owner, status, and resolution path — not in open-ended chat threads or multi-topic mails.
