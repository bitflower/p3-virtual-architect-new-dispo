Subject: Request for Approval: Additional GCP Environment for Dispo UAT Testing

Hi Christian, hi Pascal,

I am writing to request your approval for setting up an additional GCP environment required for the Dispo acceptance process.

## Current Situation

Following a discussion with Dominik Landau on February 11, 2026, we identified that Workload 4 (WL4) currently lacks a complete environment setup. As per GCP standard practice, each workload typically includes four environments out of the box (Shared, Dev, Test, Prod). However, WL4 is missing the Dev environment, as clearly visible in the attached GCP landscape overview provided by Dominik.

## Proposed Solution

We propose to set up the missing Dev environment for WL4, which will be repurposed as our UAT/ACC environment. According to Dominik's assessment, this setup can be completed with approximately one hour of effort on his side.

## Intended Use

The new environment will be dedicated to User Acceptance Testing (UAT) and will connect to the following databases:
- UAT2820
- UAT1034 (noting that this database may be behind schema-wise)

This setup will replicate the production environment structure and enable us to properly test the target acceptance process before go-live.

## Naming Convention

We acknowledge that the environment will technically be named "DEV" within the GCP infrastructure. We plan to harmonize the usage and naming conventions in the future to better reflect its UAT purpose. However, this standardization will not occur immediately, as I need to lead internal discussions to determine the optimal approach.

## Next Steps

Beyond this immediate requirement, our priority remains the upleveling of the overall GCP workload landscape, as discussed in our ongoing infrastructure optimization efforts.

## Request

I would appreciate your approval to proceed with this environment setup. Please let me know if you require any additional information or if you have concerns regarding this approach.

Thank you for your consideration.

Best regards,
Matthias
