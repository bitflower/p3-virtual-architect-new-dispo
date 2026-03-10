Everyone we have an issue with the uat2820 database, I need someone to support me on this
CDC datastream is 1 week behind, there is 422gb data_lag on that database
datastream currently works but is filling the bucket with data from 23 jan 2026
 
 
 ![alt text](<image (7).png>)

there are some queries that are in 'hanged' state:
 
  ![alt text](<image (8).png>)
 
datastream log:
 
  ![alt text](<image (9).png>)

## Teams Chat#

it is working and it is green, I think there is something wrong on  the database side
 
datastream captures whatever is sent to 'sendung_slot_2820'

  ![alt text](<image (10).png>)
 
How many records do we have in table "sendung"? How many new daily?
 
I'll check the above (my last message)
 
probably that is the issue, the data goes very slow to that slot but I am not postgres expert
 
Still 422GB is a lot. This is not from 7 day gap
 
btw it is now 426gb
 
Can you share the SQL for the creation of the slot?
 