# Summary

## Integrating the project with DLL

**Pros:**
After exploring the integration of the TOP project into the New Disposition project via DLL files, we reached the following conclusions:
The integration using a DLL file is technically straightforward. Despite the difference in .NET versions between the two projects, there were no build errors, and the application started correctly. The core calculation functionality was also accessible.

**Cons:**
However, there are some important drawbacks to consider. Any change to the TOP project would require manual intervention on our side: pulling the updated repository, building the project, extracting the updated DLLs, and manually copying them into the New Disposition project. This process is time-consuming and would require us to track changes and create dedicated tasks whenever an update is needed.

**Recommended solution**
To address this issue more efficiently, we recommend creating a NuGet package for the TOP library. A dedicated pipeline could handle publishing updated versions automatically. This would allow us to consume the library as a standard dependency, making integration and future maintenance significantly easier, cleaner, and less error-prone.