WHO: As a user,
WHAT: I want to edit the contractor field,
WHY: so that the selected or manually entered contractor information is validated and correctly reflected on the transport order level.

Use Case Description
The user can type into the contractor name field to search for an existing contractor.
A fuzzy search provides matching candidates while typing.

Example:
Entered value: “Helmut Log”
Matching candidates:

Helmut Logistic

Airsupply Helmut Logistic

Schelmut Logger GmbH

Each candidate displays the following details to help identify the correct contractor:

Person number

Name1

Country

ZIP code

City

Street


Behaviour if TMS-DB is the data source:

If a candidate is selected, all related fields (address, etc.) are auto-populated with that contractor’s data. 

The autopopulated fields (except for the email and the name) become deactivated, so the user can no longer input information.
If no candidate is selected, the user can manually input individual fields (e.g., address, city, ZIP).


In this case the required fields are:
name (Name)
country (Land)
zip-code (PLZ)
city (Stadt)
street (Straße)
request for adding these data to the Transport order will only be sent when:
All required fields are populated
the combination of country, zip-code and city has been found in the TMS-Database
To ensure the second requirement is met, the UX for adding data to the fields [country (Land), zip-code (PLZ), city (Stadt)] is as follows:
1. Country Selection
AC 1.1 When the user starts typing in the Country field, the system performs a fuzzy search in the TMS database across all available countries.

AC 1.2 Suggestions update dynamically with each keystroke.

AC 1.3 If the user enters “D”, suggestions may include “Germany (DE)”, “Denmark (DK)”, etc.

AC 1.4 If the user enters “DE”, only countries that match “DE” are shown (e.g., Germany).

AC 1.5 The user has to select a candidate. If no candidate is selected the field remains empty.


Showing Abbreviated Country code + full country name

2. Postal Code (ZIP) Selection
AC 2.1 If a Country has been selected, only postal codes belonging to that country are suggested.

AC 2.2 If no country is selected, postal code suggestions include all postal codes from all countries.

AC 2.3 Suggestions use fuzzy search and dynamically update based on user input.

AC 2.4 The user can only select a postal code that exists in TMS.

AC 2.5 The user has to select a candidate. If no candidate is selected the field remains empty.
country, Postal code, City and district will be shown for each zipcode candidate.
On selection of a candidate all available information are populated to fit the candidate.
3. City Selection
AC 3.1 If Country is selected, only cities from that country are suggested.

AC 3.2 If Country and Postal Code are selected, only cities matching both the country and postal code are suggested.

AC 3.3 If only Postal Code is selected, only cities matching that postal code are suggested.

AC 3.4 If neither Country nor Postal Code is selected, all cities in CMD remain valid candidates.

AC 3.5 Suggestions use fuzzy search and dynamically update with each keystroke.

AC 3.6 The user can only select a city that exists in CMD.

AC 2.5 The user has to select a candidate. If no candidate is selected the field remains empty.
country, Postal code, City and district will be shown for each zipcode candidate.
On selection of a candidate all available information are populated to fit the candidate.
4. Street Selection
AC 4.1 Suggestions update dynamically with each keystroke.

AC 4.2 The user can input a street that does not exist in TMS.

optional AC 4.3 When possible a support fuzzy search is aprreactiated.


These manually entered values are only stored on the transport order level and not persisted in the master data tables (pers or person).

The email can always be edited and will only update the transport order.
No validation is performed except for a valid Email format (xxx@yy.zz).
If a new name is entered and a datapoint is selected, the fields will all be updated according to the new datapoints information.
If a new name is entered and no existing datapoint is selected. Resulting in a wipe of the fields from the transport order, making them clear again.

Extra: 
If the carrier data has no input at the time of the population of new contractor data (via autopopulate or manual input). The carrier fields are update to hold the same values as the contractor data. 

When a "non"candidate name is entered and the required additionl fields (zip,city,...) are not populated during the session or before the user leaves the page:
the request to edit the transport order is not sent and therefore will show the old values when refreshing the page.
when trying to leave the page and an open "edit" is present, the user will be notified that his progress on the contractor field will be lost.