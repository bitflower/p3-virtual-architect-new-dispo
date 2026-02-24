# Edit Flow – 14.1 Edit Tour Point Data I Changing Tourpoint data of an existing Tourpoint (TMS as source)

Open Questions:
- How to identify a Tourpoint? whats the source for tourpoints?
- Question:
  - Do we have a tourpoint specific filtering for the suggestions? ergo by a type column e.g. type = tourpoint in the person table or where ever the master data comes from
- what is the source?
- correct behaviour?
  - If a new name is entered and a datapoint is selected, the fields will all be updated according to the new datapoints information.
  - If a new name is entered and no existing datapoint is selected. Resulting in a wipe of the fields from the transport order, making them clear again.

WHO: As a user, 
WHAT: I want to edit the data of an existing tour point (with the exception of Loading and Unloading tourpoints)
WHY: so that the selected or manually entered tourpoint information is correctly reflected on the transport order level.

Use Case Description
The user can type into the name 1 field to search for an existing tourpoint.
A fuzzy search provides matching candidates while typing.

Example:
Entered value: “Helmut Log”
Matching candidates:

Helmut Logistic

Airsupply Helmut Logistic

Schelmut Logger GmbH

Each candidate displays the following details to help identify the correct tourpoint:

Name1

Name2

Country

ZIP code

City

Street

Behaviour if TMS-DB is the data source:

If a candidate is selected, all related fields (address, etc.) are auto-populated with that tourpoint's data. 

The autopopulated fields (except for the reference, name and tournumber) become deactivated, so the user can no longer input information.
If no candidate is selected, the user can manually input individual fields (e.g., address, city, ZIP).


In this case the required fields are:
name (Name)
country (Land)
zip-code (PLZ)
city (Stadt)
street (Straße)
request for adding these data to the Transport order will only be sent when:
All required fields are populated
the combination of country, zip-code, city and street has been found in the TMS-Database
To ensure the second requirement is met, the UX for adding data to the fields [country (Land), zip-code (PLZ), city (Stadt), street (Straße)] is as follows:
1. Country Selection
AC 1.1 When the user starts typing in the Country field, the system performs a fuzzy search in the TMS database across all available countries.

AC 1.2 Suggestions update dynamically with each keystroke.

AC 1.3 If the user enters “D”, suggestions may include “Germany (DE)”, “Denmark (DK)”, etc.

AC 1.4 If the user enters “DE”, only countries that match “DE” are shown (e.g., Germany).

AC 1.5 Either the user selects a candidate or it matches 1:1 with one entry in the DB. If the user leaves this field without a match from the DB this field will receive a red border and be treated (for the following validations) as empty.


2. Postal Code (ZIP) Selection
AC 2.1 If a Country has been selected, only postal codes belonging to that country are suggested.

AC 2.2 If no country is selected, postal code suggestions include all postal codes from all countries.

AC 2.3 Suggestions use fuzzy search and dynamically update based on user input.

AC 2.4 The user can only select a postal code that exists in TMS.

AC 2.5 Either the user selects a candidate or it matches 1:1 with one entry in the DB. If the user leaves this field without a match from the DB this field will receive a red border and be treated (for the following validations) as empty.
3. City Selection
AC 3.1 If Country is selected, only cities from that country are suggested.

AC 3.2 If Country and Postal Code are selected, only cities matching both the country and postal code are suggested.

AC 3.3 If only Postal Code is selected, only cities matching that postal code are suggested.

AC 3.4 If neither Country nor Postal Code is selected, all cities in TMS remain valid candidates.

AC 3.5 Suggestions use fuzzy search and dynamically update with each keystroke.

AC 3.6 The user can only select a city that exists in TMS.

AC 3.7 Either the user selects a candidate or it matches 1:1 with one entry in the DB. If the user leaves this field without a match from the DB this field will receive a red border and be treated (for the following validations) as empty.
4. Street Selection
AC 4.1 Suggestions update dynamically with each keystroke.

AC 4.2 The system shows all streets from TMS as possible suggestions.

AC 4.3 Fuzzy search must be applied to all street suggestions.

AC 4.4 The user can input a street that does not exist in TMS.



These manually entered values are only stored on the transport order level and not persisted in the master data tables (pers or person).

If a new name is entered and a datapoint is selected, the fields will all be updated according to the new datapoints information.
If a new name is entered and no existing datapoint is selected. Resulting in a wipe of the fields from the transport order, making them clear again.

## Acceptance Criteria

The tourpoint can be searched via a fuzzy search in the "Name 1" field.
The system displays a list of matching tourpoints, showing:

Name1

Name2

Country

ZIP code

City

Street

Selecting a candidate automatically fills all related tourpoint fields with the candidate’s data.

After selecting a candidate, the tourpoint information is saved to the transport order.

If no candidate is selected, each tourpoint's field (name, address, etc.) can be edited individually as described above.

When leaving a manually edited field (onBlur event):

The input is validated by checking against the TMS DB.

If validation passes, only that field is updated and saved to the transport order,

If validation fails, the user is informed via a visual indicator (e.g., red border, tooltip, or message).

Manually entered data (when no candidate is chosen) are stored only on the transport order and not in master data tables.

Changes are only saved if the field content actually changes.

If a save request fails, an error message is displayed and the field value reverts to the last successfully saved value.


