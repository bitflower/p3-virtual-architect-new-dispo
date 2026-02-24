Transport Mode Topic:

Joachim would be able to provide a column on sendung defining „created by New Dispo“.
 
Please think about any other implications of this desture request.
 
If this the way forward I‘ll put this in the concept and get it verified.
 
well for one thing I am not sure if "created by new dispo" should be the correct name of the column
 
We probably would set it in our wrapper or even core function.
 
the Use Cases state
 


It needs to be ensured that the ALL the following scenarios are covered:
All Transport orders with transport mode 60 are plannable and visible on the planning page 
All Transport orders which have been created from the New Dispo App remain plannable and visible on the planning page
All Transport orders which have been created via the "Vorbelegung" (Automatic creation of transport orders) with transport mode 60 remain plannable and visible on the planning page
This would result in the following behaviour:
A transport order has been created from outside the New Dispo app and its transport mode is changed to 60 (here it would be visible in the New Dispo app), then its mode is changed to a different mode. Then it would disappear from the APP.
 
 
The name was just to explain our current state of knowledge. Could be anything. Just technically he confirmed its possible.
 
Matthias Max
The name was just to explain our current state of knowledge. Could be anything. Just technically he confirmed its possible.
ah ok
 
But generally I think the column approach should  do the job
 
If Joachim is fine with it
 
then we should be good
 
Yes. It wasn‘t so clear because they are hesitant to add new columns due to downstream  risk introduced in processes.

They give an existing column that is unused.
 