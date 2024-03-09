# Edit Commands in Verovio

This document covers what syntax is expected of an Edit command in Verovio.  Important note to keep in mind though: this may change.  Their edit functionality is currently more of an Alpha-stage concept and less of a built-in feature.  They will be working on it starting early-mid April and it may change drastically by then.  This is just what it is right now, and I'll try to change this as they change their system.

## Basic Syntax

The syntax is Json-encoded and follows this pattern:

	{ 'action': <Name-Of-Action>, 'param': { <Any-Specific-Parameters> } }

Param is usually an object with the parameters needed for that command.  Unless the parameter value is a number, wrap all values in single quotes just like the parameter names (single quotes rather than double so that when we wrap the whole thing in double quotes in our code editor, it doesn't conflict).

## Most Useful Commands

Here's a list of all the most common commands, and their parameters.  Each with example.

	Action: Delete
	Parameter: elementId
	Example:  {'action': 'delete', 'param': { 'elementId': 'd11984b6' } }
	
Below are ones that I haven't gotten into learning yet but I'll update as I do.  Parameters in curly brackets {} are optional.

	Action: Chain
	Parameters: Array of sub-actions.
	Example:  {'action': 'chain', 'param': [
		{action1},
		{action2},
		etc.		
	]}
	The element ID of the previously dealt with element is kept for the next chain.  To refer to it, use the id '[chained-id]'.
	
	Action: Insert
	Parameters: elementType, startid, {endid}
	
	Action: Commit
	Parameters: None
	
	Action: Drag
	Parameters: elementId, x, y
	This method actually calculates the new pitch of a note dragged to those coordinates.
	
	Action: KeyDown
	Parameters: elementId, key, {shiftKey, ctrlKey}
	
	Action: Set
	Parameters: elementId, attribute, value
	
	