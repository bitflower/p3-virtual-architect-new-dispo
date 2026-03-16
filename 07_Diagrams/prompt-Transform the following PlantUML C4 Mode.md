Transform the following PlantUML C4 Model into a PlantUML Sequence Diagram that represents the interactions between the components, containers, and systems. Ensure the sequence diagram accurately reflects the relationships and message flow in the original C4 diagram.

1. Identify Participants

- Each Component, Container, and System in the C4 diagram should be represented as a participant, actor, or database in the sequence diagram.
- Use meaningful labels based on the names of the components.

2. Define Message Flow

- Convert Rel, Rel_U, Rel_D, and Rel_R relationships into sequence messages.
- Use appropriate sequence diagram notation:
- -> (synchronous request)
- --> (asynchronous message/event)
- <- or <-- (response where necessary)

3. Choose a Representation for HTTP & Database Calls (Optional)

- Option A (Single Arrow - Implicit Response): Show only the request, assuming the response is implied.
- Option B (Two Arrows - Explicit Response with Activation/Deactivation): Show both the request and the returned data explicitly, using activate and deactivate to indicate processing duration.

4. Add Triggers and Events

- Capture how data moves between components (e.g., event triggers, API calls, database reads/writes).
- If a component listens for changes, represent it as an event or a conditional activation.

5. Include Activation/Deactivation for Requests (If Using Option B)

- Use activate to show when a request starts processing.
- Use deactivate to indicate when processing ends.

6. Include Details

- Mention protocols (e.g., HTTPS, Azure Service Bus, TCP/IP) in the message descriptions.
- Use comments (note left, note right) where necessary to provide additional context.

The diagram:

<diagram-code>
{diagramCode}
</diamgram-code>