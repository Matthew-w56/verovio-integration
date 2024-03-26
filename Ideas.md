# Ideas


## Collision Detection With Pre-Computed Rectangles

Here's the idea: Instead of actually creating rectangles to decide what note group the user is hovering over (mainly for note addition preview), you could store the information like this:

One array of integers would store the end of each rectangle, including any margins.  For example, the first number would be the Y-position of the top of the first staff (bottom of page top margin).  The second number would be the upper-most note Y position in the next staff and so forth.  Then, to see what row the click was in, just find the index of the first integer you find whose Y position is larger than the click Y position.

Similar to this, you store a matrix that is NxM integers (N being the number of rows).  In each row, each number is the end of each note group (halfway between notes, end of measure, etc).  You find the index of the first integer that is larger than the click X position.

The indices of these two integers you have found index into an NxM matrix of IDs (or element objects, integer ids, whatever it is you want to select).  You just grab what object you got and boom, you got your element from a click with <50 integer comparisons! That is blazingly fast.

This does make some assumptions:
- All rectangles span the entire height of a row
- All space is within a rectangle
	- This can be dealt with by filling empty spots with (null || 0 || None)
- Only note groupings are wanted to be selected by this method. (or other vertically expanded elements)

One thing that can add support for floating rectangles within this section would be to add in an additional set of floating rectangles for each row.  So they are associated with a row, but not indexed by the integer comparison method described above. This would allow a smaller, floating rectangle that encompasses a fermata, or accidental, or whatever else.  The algorithm would change to:
- Find the row index using the same method
- Check for individual collisions with the special rectangles (if any)
- Continue normally for the note group if no collision found

Only problem would be to calculate all the rectangles, especially things like row boundaries and where the half-way mark between two notes is.  Something to think more about.

Pseudo-code for rectangle creator:
	
	int S = #num of staves in each measure.  Read from first measure.
	
	# Number of staves in system is S
	# Number of rows of music is R
	RowMarkers = []			# Length S*R by end
	ColMarkers = []			# Length is # of items in that row by end
	ElemIDs = []			# Length is S*R by each row's col length
	
	lastMeasureY = -1		# Scalar value
	rowMaxY = [S -1's]		# Length is S
	rowMinY = [S -1's]		# Length is S
	hangingRowMaxY = -1		# Scalar value
	
	# Basically a "for measure in song"
	for child of The_System:
	
		if child doesn't have class = "measure":
			continue;
			
		int measureTopY = first_staff_child.first_child.d.split(" ")[1];
		if measureTopY != lastMeasureY:
			# We are starting a new line now
			
			# First, draw all seperator lines that we have info for
			RowMarkers.append( (rowMinY[0] + hangingRowMaxY) / 2 );
			for (int i = 1; i < S; i++) {
				RowMarkers.append( (rowMinY[i] + rowMaxY[i-1]) / 2 );
			}
			
			# Save the last max value away
			hangingRowMaxY = rowMaxY[rowMaxY.length-1];
			# Set max and min for each staff as it's own staff lines
			for (Staff child in measure) {
				rowMinY[childIndex] = child.first_child.d.split(" ")[1];
				rowMaxY[childIndex] = child.fifth_child.d.split(" ")[1];
			}
		
		
		for staff in (measure)child:
			# staffIndex reflects the index of measure's child
			
			int lastElemMaxX = -1;
			
			# Special case for first element:
			- Add seperator that marks the line such that everything to the
				left is stuff we don't care about (left bound line)
			- Add some value that represents no note to the ElemIDs ("" maybe)
			- Find this element's Max bound only >> lastElemMaxX
			- Add element ID to ElemIDs (top level matrix)
			- Do the maxY and minY checks for this element
			- Skip it now. The next seperator will define it's box
			
			# Go through each direct child of staff
			- Find it's minimum bound
			- Draw a seperator line halfway between minElementX and lastElemMaxX
			- Find it's maximum bound >> lastElemMaxX
			- Add this element ID to ElemIDs (top level matrix)
			- Do the maxY and minY checks for this element
			
			# Once the end of the line is reached
			- Add a seperator line at the end bound of the line
			- Add some value that represents no note to the matrix ("" maybe)
			- Add a seperator line at the very bound of the page (beyond what we
				care about)
			
			
				
	
	