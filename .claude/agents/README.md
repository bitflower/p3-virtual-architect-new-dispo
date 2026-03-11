# New Dispo Coding Expert Agents

Three specialized Claude Code agents for working with the New Dispo codebase.

## Available Agents

### 1. **frontend-expert**
Angular 19 specialist for the Disposition Frontend

**Invoke with:**
```
Can you help with [task] using the frontend-expert agent?
```

**Specializes in:**
- Angular 19 standalone components
- RxJS observables and state management
- Angular Material UI components
- Dynamic forms system
- Nx monorepo structure
- TypeScript strict mode patterns

---

### 2. **backend-expert**
.NET 8 CQRS specialist for the Disposition Backend

**Invoke with:**
```
Can you help with [task] using the backend-expert agent?
```

**Specializes in:**
- CQRS pattern with MediatR
- Entity Framework Core with PostgreSQL
- FluentValidation
- Exception handling strategies
- RESTful API design
- C# 12 primary constructors

---

### 3. **tms-bridge-expert**
.NET 8 GraphQL multi-tenant specialist for the TMS Bridge

**Invoke with:**
```
Can you help with [task] using the tms-bridge-expert agent?
```

**Specializes in:**
- HotChocolate GraphQL server
- Multi-tenant database abstraction
- Oracle and PostgreSQL dual support
- Stored procedure execution
- Transaction management with savepoints
- Vendor-agnostic routine builders

---

## How to Use These Agents

### Option 1: Explicit Invocation
Ask Claude Code to use a specific agent:
```
"Use the frontend-expert agent to create a new Angular component for displaying transport orders"
"Ask the backend-expert to help me implement a new CQRS command"
"Have the tms-bridge-expert add a new GraphQL mutation"
```

### Option 2: Contextual Invocation
Claude Code will automatically select the right agent based on your question context:
```
"How do I add a new form field to the dynamic forms system?"
→ Will likely invoke frontend-expert

"I need to create a new command handler for updating contacts"
→ Will likely invoke backend-expert

"How do I query a different TMS database in GraphQL?"
→ Will likely invoke tms-bridge-expert
```

## What Makes These Agents Special

Each agent has been trained on:
1. **Actual codebase patterns** - Extracted from real code analysis
2. **Specific versions** - Angular 19, .NET 8, etc.
3. **Architecture decisions** - CQRS, multi-tenancy, vendor abstraction
4. **Naming conventions** - File names, class names, variable names
5. **Anti-patterns** - What NOT to do in each codebase
6. **Common tasks** - How to accomplish typical development tasks

## Examples

### Frontend Example
```
Q: "I need to add a new service that calls the backend API"
A: frontend-expert will:
   - Create injectable service with @Injectable({ providedIn: 'root' })
   - Use RequestService (not HttpClient directly)
   - Follow BehaviorSubject pattern for state
   - Include proper error handling with ErrorHandleService
   - Place in nagel-services library
   - Export from index.ts
```

### Backend Example
```
Q: "How do I add a new endpoint to get customer details?"
A: backend-expert will:
   - Create GetCustomerDetailsQuery implementing IQuery<T>
   - Create GetCustomerDetailsQueryHandler implementing IQueryHandler<,>
   - Create validator with FluentValidation
   - Create response DTO
   - Add minimal controller endpoint
   - Follow CQRS pattern (no services/repositories)
```

### TMS Bridge Example
```
Q: "I need to call a stored procedure from the TMS database"
A: tms-bridge-expert will:
   - Create GraphQL mutation with databaseIdentifier parameter
   - Build parameters with RoutineParameterBuilder
   - Execute with IRoutineExecutor
   - Handle both Oracle and PostgreSQL automatically
   - Include transaction support
   - Map DataTable results to response DTO
```

## Agent Architecture

Each agent has:
- **Name**: Unique identifier
- **Description**: What they specialize in
- **Tools**: Read, Write, Edit, Glob, Grep, Bash
- **Model**: Opus (most capable Claude model)
- **Knowledge**: Deep understanding of codebase patterns

## Tips for Best Results

1. **Be specific about the codebase**: Mention "frontend", "backend", or "TMS bridge"
2. **Reference existing patterns**: "Like how we handle pagination in the orders list"
3. **Ask for explanations**: "Explain why we use CQRS instead of services"
4. **Request reviews**: "Review this code against our backend patterns"
5. **Seek guidance**: "What's the right way to add a new entity?"

## Agent Updates

These agents are based on analysis performed on **2026-03-10**.

To refresh agent knowledge when codebases evolve:
1. Re-run the codebase analysis exploration
2. Update the agent markdown files
3. Incorporate new patterns and decisions

## Related Documentation

- **CLAUDE.md**: Project-wide instructions
- **Tech Stack**: See CLAUDE.md for component mapping
- **Codebase Locations**:
  - Frontend: `Code/Disposition-Frontend/`
  - Backend: `Code/Disposition-Backend/`
  - TMS Bridge: `Code/Disposition-Abstraction-Layer/`

---

**Questions?** Just ask Claude Code: "How do I use the coding expert agents?"
