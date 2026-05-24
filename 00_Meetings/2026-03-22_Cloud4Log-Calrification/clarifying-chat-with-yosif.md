# Chat with Yosif and Cem to calrify internally

## Matthias

Hi guys, Christian contacted me asking for clarification about why we need right access to digilis TMS etc. 
 
We need to clarify this quickly.
 
My understanding is reading through the chat that the root cause is missing reliable bundle data. Correct
Yosif Mihaylov ? This is something Nagel should provide, we should not create this ourselves.

## Yosif

correct the shipments that are in the databases they provided are not in the correct states

we simply cannot make any use of the data inside for the cloud 4 log project.

What makes relevant data in C4L for upload:
 
In Oracle TMS:
- Have shipments, which:
- have 'verkehrsstrom' = '30'
- have non nullable druckdatumE value
- have related bordero OR rollkart record
   - if the related record is rollkart the shipment should have tranArt value of 3 or 6
- have related person record (realtion is established by EmpfN and EmpfI columns) with specifically iln values of 4099200045498 or 4099200045504
- Have related pstHsts record
   - pstHsts record should have status '660'
   - pstHsts record should have mp '4' if border is related of '7' if rollkart is related
   - pstHsts record should have meaningful metadata value
   - have related data in senLsPsts
      - senLsPsts record should have same lsN as related dl_no from digilis DL_SHIP_ORD_POS
 
- Have data in sen_ls_ref, which:
  - has 'typ' value "BES"
  - has lsN the same as related dl_no from digilis DL_SHIP_ORD_POS
  - has sen_tix as related shipment
 
- Have relation in sen_ls_ref, which:
- has relation with senLs
   - senLs has same sen_tix as relevant shipment
- has 'typ' value "BES"
 
In Digilis Oracale:
- delivery note with same SEN_TIX as the relavant shipment in tms 
- delivery note shipment orders (DL_SHIP_ORD) related with delivery note shipment order positions (DL_SHIP_ORD_POS)
- delivery note shipment order positions (DL_SHIP_ORD_POS) related with delivery note connections (DL_DEL_NOTE_CONN)
 
In Digilis file share
- Have file at the path present in Digilis DL_DEL_NOTE_CONN.Path



it is very important

Matthias Max please let them know that they should provide the databases with the data inside, I don't think at this point we should let them go with "just providing WRITE access" let them do what they're supposed to
 
so next time they appreciate our best intentions to "do their job ourselves"

## Cem

Hi 
Yosif Mihaylov, hi Matthias Max,
I need your quick support on the following topic:
Currently, we are talking about SQL data not the initially mentioned DevOps aspects, accesses, etc. This is causing some confusion on Christians side. 
 
What he don’t fully understand: We are now discussing a redesign of the implementation due to C4L/Markant. However, these data points should have already been available during the initial testing in the first iteration of the project.
 
Therefore, his questions are:
On what data basis was the initial testing performed?
Were the relevant SQL data already available at that stage, or was testing done with mock/test data?
What exactly has changed that now requires a re-design?
Christian is waiting for a response, so a quick clarification would be highly appreciated. 


## Yosif

Cem Karaman
 
Answering the first two bullet points:
 
The initial testing was performed against the production databases.
 
We wanted to use the production databases on our dev environment as well (because we only ever do READING and never WRITING) so the data inside cannot be corrupted also this could be guaranteed even more if the user we use for the prod databases has only READ rights (this is mostly likely the case anyway). That was our intention in first place as we are going to benefit from greatly.
 
We would be able to simulate our real environment (multiple depots constantly fed with data leading to concurrent and parallel execution which is the core of this project and it is essential to test)
Will reduce a lot of operation effort by avoiding to set up our dev environment with multiple depots (multiple development resources for each depot) and avoiding to feed data inside them.
 
Answering the last bullet point:
"We are now discussing a redesign of the implementation due to C4L/Markant"
 
What redesign? What we are doing is improving the resiliency around both platforms by changing the architecture (queues, cloud tasks etc, as per the new arcthitecture proposal) and the other thing is the Markant integration. I'm not sure about what redesign you two are talking.

## Matthias

> Matthias 22.05.26 15:16: Matthias Max please let them know that they should provide the databases with the data inside, I don't think at this point we should let them go with "just providing WRITE access" let them do what th…

Absolutely not ! Christian doesn't want us to write anyway.

I will clarify this with Christian, as he has personally reached out to me yesterday, and explain the need for test data.
 
I will keep you in the loop.
 
Reg. "redesign" - for me the new design approved months ago is still the target state. Including the small changes introduced by you
Yosif Mihaylov to have a cloud run service instead of the two sep. components. Just to be clear.

## Cem

We are all on the same page and share the same target.
I will inform Christian that Matthias Max will reach out to him directly.
Yosif Mihaylov whether we refer to it as “re-design” or “refactoring”, the key point is that we move forward. I need your support Matthias Max. 

## Yosif

Cem Karaman I thought that this refactoring (the new architecture) is already something that Christian is aware of given that he personally signed it as far as I am aware of, I'm not sure why we keep repeating the same stuff.

## Cem

Of course he is aware of the new architecture, we got his approval before we started. 
 
I am also not sure why this is happing, Matthias Max did you had the chance to speak to Christian.
 