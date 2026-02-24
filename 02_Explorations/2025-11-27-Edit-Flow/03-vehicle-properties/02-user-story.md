What is the function?

What is the field which needs to be mapped?


WHO: As a user,

WHAT: I want to check and uncheck vehicle body types and properties,
WHY: so that I can correctly reflect the vehicle’s technical setup and equipment in the transport order.

Description / Use Case
There are two distinct editable areas within the transport order:

Area 1 – Body Type
The user can check or uncheck the following body type attributes to define the type of vehicle body used for the transport:

ATP-Kühlung FRC – 20 °C (defaultly selected, can be unselected)

ATP-Kühlung FRB – 10 °C

ATP-Koffer

Wechselbrücke

Plane

Tank / Silo

Multiple selections are possible.
Checked items are visually highlighted (e.g., with a blue background or a checkmark).
Unchecking removes the body type from the transport order.

Area 2 – Vehicle Properties
The user can also define additional vehicle-specific properties by checking or unchecking them.
These could include (examples):

Temperaturschreiber erforderlich

Vorkühlung (can not be unchecked)

Trennwand

Doppelstock

As with body types, selections can be toggled on or off.
All changes are stored to the transport order once the user confirms or leaves the section.

## Acceptance Criteria

General
Both areas (“Body Type” and “Vehicle Properties”) are displayed in clearly separated sections.

Each selectable attribute is represented by a checkbox (or toggle).

Multiple selections are possible.

Checked elements are persisted in the transport order.

Unchecked elements are removed from the saved properties.

Changes are saved automatically upon user confirmation (e.g., onBlur, or via explicit “Save” action).

The current state (checked / unchecked) is correctly displayed when reopening the transport order.

If saving fails, an error notification appears and the previous state is restored.

Body Type (Area 1)
The listed body type options are available as defined above.

Only predefined body types can be selected – no free-text entry.

At least one option can remain unchecked (no “mandatory” requirement).

Properties (Area 2)
The predefined list of vehicle properties can be checked or unchecked.

Each property directly maps to a Boolean value in TMS.

No validation or interdependency logic is applied

