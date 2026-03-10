
Besprechungsnotizen:
Versioning and Tagging Best Practices: 
Marko explained to Matthias the importance of semantic versioning (major, minor, patch) for applications, detailing how to use version tags for artifact storage, rollbacks, and modular deployments, and emphasized the need for a uniform versioning strategy across all microservices and system versions.
	Semantic Versioning Structure: Marko described the use of semantic versioning, where the first number indicates a major version (breaking changes), the second a minor version (new functionality, backward compatible), and the third a patch version (bug fixes or quick updates).
	Artifact Storage and Rollbacks: Marko recommended creating artifacts for each version and storing them in artifact storage solutions (such as GCP buckets or artifact managers), enabling easy rollbacks to previous versions if issues are found during testing or production.
	System and Service Versioning: Marko suggested maintaining separate artifact storages for backend, frontend, and TMS bridge, and grouping specific versions of these services into a system version, which simplifies customer deployments and rollbacks.
	Uniform Tagging Strategy: Marko emphasized the importance of agreeing on and consistently applying a tagging convention across all microservices and the system version, warning that inconsistent tagging (e.g., using 'latest') can break the deployment system.
Pipeline Design and Automation: 
Marko and Matthias discussed how to structure CI/CD pipelines to automate building, testing, tagging, and deploying artifacts, clarifying that pipeline logic should handle versioning and deployment rather than embedding this logic in always-running microservices.
	Pipeline Responsibilities: Marko explained that pipelines should handle building, testing, and deploying artifacts, with separate pipelines for integration/unit tests and for building and pushing artifacts to storage, depending on the language and technology stack.
	Branching and Trigger Strategies: Marko described using branching strategies and pipeline triggers (e.g., on pull requests or merges) to automate artifact creation and deployment, ensuring that only merged features are tagged and deployed.
	Avoiding Unnecessary Microservices: Marko advised against creating a dedicated microservice to manage versioning logic, stating that existing tools like Git and Azure DevOps are designed for this purpose and can handle versioning and deployment efficiently.
	Pipeline Complexity Concerns: Matthias raised concerns about pipeline complexity, to which Marko responded that with proper branching and trigger configuration, the pipelines remain manageable and do not require excessive manual intervention.
Displaying Version Information in the Frontend: 
Matthias asked Marko how to dynamically display system and service versions in the frontend, and Marko suggested storing deployed version information in a database or using deployment hooks, rather than hardcoding or coupling it to the frontend.
	Dynamic Version Retrieval: Marko recommended storing the deployed version information in a database table or similar persistent storage during deployment, allowing the frontend to query and display the current system and service versions.
	Alternative Approaches: Marko also mentioned the possibility of using deployment hooks to fetch version information from the artifact registry, but preferred a local variable or database approach for simplicity and reliability.
Branching Strategy and Developer Workflow: 
Marko outlined to Matthias how branching strategies should be defined and documented, with clear rules for tagging and artifact creation, and stressed the importance of team-wide adherence to the agreed strategy to avoid inconsistencies.
	Branching and Tagging Rules: Marko explained that minor and patch versions should be managed according to the branching strategy, with tags created only after pull requests are merged into main or release branches, ensuring only stable features are deployed.
	Documentation and Team Alignment: Marko advised creating a document outlining the branching, tagging, and pipeline strategies, and ensuring all developers follow the agreed workflow to maintain consistency and avoid deployment issues.
	Role of DevOps Engineer: Marko suggested involving a dedicated DevOps engineer (such as Gojko) to help define and enforce the workflow, and to act as a point of contact for developers to clarify requirements and maintain the process.
Next Steps and Delegation: 
Due to time constraints, Marko recommended that Matthias coordinate with Gojko, the project's DevOps engineer, to further discuss and implement the proposed best practices and workflows with the development team.
	Delegation to DevOps Engineer: Marko explained that he is unavailable for further meetings and advised Matthias to reach out to Gojko to arrange discussions with the development and DevOps teams regarding the implementation of best practices.
	Importance of Dedicated Ownership: Marko emphasized the need for a dedicated person to oversee the integration of the agreed strategies into the team's workflow, ensuring everyone is aligned and the process is properly documented and maintained.
Folgeaufgaben:
DevOps Best Practices Alignment: 
Align with Gojko to arrange for a dedicated DevOps engineer to review best practices and workflows with the developers and help define a unified branching and tagging strategy. (Matthias)
Documentation of Versioning and Branching Strategy: 
Create a document outlining the agreed branching strategy, tagging strategy, and pipeline processes for the team to follow. (the team)