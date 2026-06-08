# Chat to clarify the exact issue

## Matthias

Let's clarify quickly why we want components in WL5 DEV to be Public. Ignoring for a moment that TEST and PROD have them set to Public as well.
 
In case we accept the requirement "Authentication: Require authentication" the effort should'nt be very high to fulfill this? The DEV project could be the "best practise" example.

## Yosif

cannot say for certain what is needed and how much effort to make it work as "Require authentication", Nikolay Hristov and Mihailo Marčetić should give input about this, but my suggestion was to enable them to unblock development and figure out it in parallel otherwise we risk spending effort which we don't know how much exactly it is for certain and if it will work at all and delay the delivery even further

## Matthias

Dev-side seems minimal

## Yosif

we're already sending access tokens when communicating tms bridge from the cloud function for example but I don't think that was the challange we had, Mihailo Marčetić any input here ?

## Matthias

Yosif Mihaylov
we're already sending access tokens when communicating tms bridge from the cloud function for example but I don't think that was the challange we had, Mihailo Marčetić any input here ?
Mihailo Marčetić That's exactly ther gap in my head. From what we just discussed and what Yossif is saying.
 
Central questions: 
 
1) Why is Public needed currently during dev? 
2) Are the cloud functions setup already to work with "Require Authentication"
 
## Mihailo

As I understand Nikolay, he said that TMSBridge is created to work with public access. The main problem is communication between Cloud Functions and TMSBridge, as well as between TMSBridge and Keycloak.
 
So either we can create a similar setup as in the test and production environments and provide public access to TMSBridge and Keycloak so the functions can reach them publicly, or we can try creating a private DNS zone so they can communicate internally.
 
Problem with creating DNS zone is that we don't have permissions to create anything on that project where shared VPC is for Dev environment
 
## Yosif

Matthias Max if understand correctly what Mihailo is saying this is not about authentication and authorization but rather about component visibility and accessibility

## Mihailo

Maybe we can check tomorrow with Nikolay Hristov as well, so then we will be sure about setup that we need for TMSBridge and Keycloak. 

## Matthias

Regarding the private DNS zone: We might not need one at all. GCP has a feature called Direct VPC egress that lets Cloud Functions reach Cloud Run services using the normal *.run.app URL — as long as the function's egress routes through the VPC, Cloud Run recognizes the traffic as "internal."
 
The key difference to the DNS approach: it does not require creating any infrastructure on the shared VPC host project. The only thing the host project admin needs to do is: 
1. Share a subnet with our WL5-dev project
2. Grant compute.networkUser on that subnet to our Cloud Run service agent
 
That "host project admin" would be Ron or Matt 
Mihailo Marčetić Nikolay Hristov ?
 
Is that an option?
 
 
 
Link:
https://docs.cloud.google.com/run/docs/configuring/shared-vpc-direct-vpc

Ah, I think I see your point now. We use KeyCloak auth. Not the GCP native one.

## Mihailo

Yes, we also have this approach already implemented in our services, but the functions cannot have a token in the header because they need to communicate with Keycloak first and then receive a token before sending a request to TMSBridge.
This is the error we are getting now:

![alt text](image.png)