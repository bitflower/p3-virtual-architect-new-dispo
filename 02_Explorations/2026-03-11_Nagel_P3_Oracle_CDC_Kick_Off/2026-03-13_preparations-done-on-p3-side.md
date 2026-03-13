# 2026-03-13 Status on P3 side

## GCP Preparation

We have defined the PBI that will result in the GCP side configuiration required to be created/provisioned.

PBI:
Technical PBI 123445: [DevOps] Setup GCP infrastructure
https://dev.azure.com/p3ds/Nagel-CAL%20Disposition/_workitems/edit/123445

## Description

[DevOps] Setup GCP infrastructure

Status: Done

Goal: Setup GCP-side infrastructure including:

*   Object Store Buckets - each for Striim & Datastream
    *   Names
        *   oracle-striim-bucket-poc
        *   oracle-datastream-bucket-poc
*   1x Datastream instance
    *   Name: new-dispo-oracle-cdc-datastream-sendung
*   Workload
    *   WL5
*   Environment
    *   TEST

We create these to be separated from any New Dispo deployment.

These instances are used only temporary and will be deleted after the PoC.

## Workshop Meeting Scheduling (Martin)

Scheduled for Montag, 16. März 2026 von 14:30 bis 15:00

"Follow-up | Oracle CDC PoC"