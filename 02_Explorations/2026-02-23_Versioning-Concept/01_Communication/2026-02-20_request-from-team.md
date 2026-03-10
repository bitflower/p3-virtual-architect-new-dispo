 
please describe the idea that you have for the versioning, so we can get better idea. My personal grey areas are the following:
 - how is the proposed versioning maintained
 - for which environment we should have it
 - when it is maintained (for example if we want this on TEST env and we have approximately 10 deployments per day of different services what will the process be)
 - who is maintaining/updating it
-where would this versioning be stored
- how we will be able to resolve particular version in the PAST to its underlying services versions
- how this approach keeps the different pipelines decoupled - how for example will the FE understand that the BE has been deployed without redeploying (if we do not resolve the versioning run time)
 
For future reference let's put all of the requirements/restrictions in the POC, so we can avoid capacity being lost. I personally understood that the result of this particular POC is what Yosif presented. Obviously there are some stuff which are not mentioned in the POC