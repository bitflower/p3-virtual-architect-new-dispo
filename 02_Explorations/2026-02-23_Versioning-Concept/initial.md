# Versioning Pattern (Original Concept)

@<Maximilian Kehder> and @<Matthias Max (PARTNER)> thoughts on a versioning pattern to satisfy user experience which is simple while still providing the necessary technical depth to support bug analysis cases when bugs are reported.

## Approach

- Keep the version of the app simple for the user to digest (aka one number)
- Be able to resolve the exact version of each related component of the stack at any time for debugging reasons

These thoughts can be used in the PBI #119887.

Not considered here yet:

- How does the frontend get this data (static vs. dynamic)
- Where could such version info be stored without having to rebuild the frontend all the time

## Example for Version 2.2.0

| Component     | Version                                                                             | Comment                                                       |
| ------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **New Dispo** | 2.2.0                                                                               | End-user friendly version communicated in the UI              |
| Frontend      | 2.2.XXX                                                                             | Technical Version of the component (created by pipeline etc.) |
| Backend       | 2.2.XXX                                                                             |                                                               |
| CloudFn Legs  | 2.2.XXX                                                                             |                                                               |
| TMS Bridge    | 2.2.XXX                                                                             |                                                               |
| TMS Database  | [7.0.0.X](https://github.com/cal-consult/tms-alloydb-schema/releases/tag/v7.0.0.81) | Version used by Project G                                     |

## Example after a UI bugfix

| Component     | Version         | Comment                                                       |
| ------------- | --------------- | ------------------------------------------------------------- |
| **New Dispo** | **_2.2.1_**     | End-user friendly version communicated in the UI              |
| Frontend      | **_2.2.XXX+1_** | Technical Version of the component (created by pipeline etc.) |
| Backend       | 2.2.XXX         |                                                               |
| CloudFn Legs  | 2.2.XXX         |                                                               |
| TMS Bridge    | 2.2.XXX         |                                                               |
| TMS Database  | 7.0.0.X         | Version used by Project G                                     |