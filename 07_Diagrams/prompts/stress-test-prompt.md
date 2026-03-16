I have a PlantUML architecture diagram describing a system. I need to modify it to include stress test scenario annotations while preserving key visual elements and considering business and nonfunctional requirements.

Please transform the given PlantUML diagram while ensuring the following constraints:

1️⃣ Preserve the original system architecture

- Keep all system boundaries, components, and relationships unchanged.
- Do not rename or modify existing components.
- Ensure that all relationships between components remain as originally defined.

2️⃣ Maintain all sprite definitions

- If sprites are present (e.g., $sprite="dotnet", $sprite="postgresql"), keep them exactly as they are.
- If new components are added, use appropriate sprites to maintain visual consistency.

3️⃣ Integrate stress test scenario annotations

- Annotate each component with the relevant stress test case number (e.g., 2.1, 2.2, etc.).
- Ensure each annotation describes the test’s goal, focus, and expected impact.
- Position the annotations directly next to their corresponding component.

4️⃣ Optimize visual placement for readability

- Keep the notes close to their definition in the plantuml code so that system boundaries are considered
- If multiple notes reference the same component, alternate between left and right placement.
- Avoid clustering too many notes on one side to maintain clarity.

5️⃣ Update the caption to highlight the stress testing focus

- Modify the caption to state that the diagram now includes stress test annotations.
- Clearly indicate that each component is linked to specific test cases.

6️⃣ Incorporate business and nonfunctional requirements

Given Business & Nonfunctional Requirements:

- The system must handle ~100,000 changes on transport orders stored in the SEN_TS table daily.
  - The 100k changes are during one day in random intensitiy but with a peak around noon (11-14 o'clock)
- The TMS branch database has a known bottleneck: reads are slow (>1 second).
- The performance of Azure Service Bus under high load is unknown.

Expected Adjustments:

- Stress test scenarios should consider these constraints and analyze potential performance issues.
- Include tests for handling slow database reads, queue delays, and burst event processing.

Given the following PlantUML architecture diagram, apply all the modifications based on these constraints:	The final output must be a clear and professional PlantUML diagram that effectively communicates both the architecture and associated stress test scenarios.

The diagram:

