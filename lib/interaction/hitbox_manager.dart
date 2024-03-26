
// ignore_for_file: non_constant_identifier_names, avoid_print, constant_identifier_names

import 'dart:math';

import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';


class HitboxManager {
  
  // Constants to avoid typos in syntax-critical strings
  static const String 
      _PAGE_MARGIN = "page-margin", 
      _CLASS = "class",
      _SYSTEM = "system",
      _MEASURE = "measure",
      _G = "g",
      _SVG = "svg",
      _STAFF = "staff",
      _PATH = "path",
      _D = "d",
      _LAYER = "layer",
      _BEAM = "beam",
      _CHORD = "chord",
      _STEM = "stem",
      _ID = "id",
      _NOTE = "note",
      _REST = "rest",
      _ACCID = "accid",
      _X = "x", _Y = "y",
      _WIDTH = "width",
      _HEIGHT = "height",
      _VIEWBOX = "viewBox",
      _MREST = "mRest";
  
  static const List<String> 
      ElementsToIgnoreDuringUnpacking = [_STEM],
      ElementsToUnpackFurther = [_BEAM, _CHORD],
      ElementsWhoseIDToIgnore = [_BEAM];
  
  static const int LowestStaffHitboxMargin = 40;
    
  // When representing a hitbox, 7 numbers are used.
  //  0  1    2      3       4    5      6
  // [X, Y, Width, Height, Layer, id, groupID]

  List<int> rowMarkers = [];
  //List<List<int>> specialRects = [];
  List<List< int >> columnMarkers = [];
  List<List< String >> elementGroupIDs = [];
  // Inner list is one note group (chord, note, etc)
  // Middle list is a system (line)
  // Outter list is the score.
  // So index with ES[line][columnMarker] and look down that list for element threshold
  List<List< List<List<int>> >> elementHitBoxes = [];
  List<List< List<String> >> elementIDs = [];
  
  int pageHeight = -1;
  int pageWidth = -1;
  
  HitboxManager();
  
  void initHitboxes(String imageSVG) {
    
    // Let the XML library parse the SVG document as an xml doc
    final doc = XmlDocument.parse(imageSVG);
    
    // Scrape the page dimensions from the main SVG tag's attributes
    List<String> pageDims = doc.getElement(_SVG)!.getAttribute(_VIEWBOX)!.split(" ");
    pageWidth = int.parse(pageDims[2]);
    pageHeight = int.parse(pageDims[3]);
    
    // Make sure we are grabbing information correctly from the document
    XmlElement? pageMarginWrapper = doc.getElement(_SVG)?.getElement(_G);
    if (pageMarginWrapper == null || pageMarginWrapper.getAttribute(_CLASS) != _PAGE_MARGIN) {
      print("First element grab wasn't page margin!");
      print(pageMarginWrapper);
    }
    
    // Read how many staves each line will have
    int staffCount = doc
      .xpath("/svg/g[@class='page-margin']/g[@class='system']/g[@class='measure']").first
      .xpath("./g[@class='staff']").length;
    
    // Create variable spaces for storing bounds between rows
    List<int> rowMaxY = List.filled(staffCount, -1, growable: false);
    List<int> rowMinY = List.filled(staffCount, -1, growable: false);
    int hangingRowMaxY = -1;
    
    // A system is a horizontal line of music comprised of measures
    for (XmlElement system in pageMarginWrapper!.findElements(_G)) {
      if (system.getAttribute(_CLASS) != _SYSTEM) continue;
      //print("----------=[ Starting System ]=----------");
      
      bool isFirstSystem = hangingRowMaxY == -1;
      
      // Fill in existing value for all min, max, and hanging
      hangingRowMaxY = isFirstSystem ? 0 : rowMaxY[rowMaxY.length-1];
      Iterable<XmlNode> staves = system
          .xpath("./g[@class='$_MEASURE']").first
          .xpath("./g[@class='$_STAFF']");
      int i = 0;
      for (XmlNode staff in staves) {
        Iterable<XmlElement> staffLines = staff.findElements(_PATH);
        rowMinY[i] = int.parse(staffLines.first.getAttribute(_D)!.split(" ")[1]);
        rowMaxY[i] = int.parse(staffLines.last.getAttribute(_D)!.split(" ")[1]);
        i++;
      }
      
      // Set up columnMarkers and elementIDs to accept more values (add new rows)
      // Get the index of rows that we will start with in this system
      int systemRowIndex = columnMarkers.length;
      // This is the start of the system (line).  Acts to define page margin in hitboxes
      int marginSeperator = int.parse(system.firstElementChild!.getAttribute(_D)!.split(" ")[0].substring(1));
      // Add a new row for each staff.  Column marker gets margin seperator, and element ID for margin is ""
      print("Choosing margin seperator as $marginSeperator");
      columnMarkers.addAll(List.filled(staffCount, [marginSeperator]));
      elementGroupIDs.addAll(List.filled(staffCount, [""]));
      elementHitBoxes.addAll(List.filled(staffCount, []));
      elementIDs.addAll(List.filled(staffCount, []));
      
      // Handle the measures themselves now
      for (XmlElement measure in system.childElements) {
        if (measure.getAttribute(_CLASS) != _MEASURE) continue;
        //print("----------=[ Starting Measure ]=----------");
        
        int measureStaffIndex = systemRowIndex;
        for (XmlElement staff in measure.childElements) {
          if (staff.getAttribute(_CLASS) != _STAFF) continue;
          //print("----------=[ Starting Staff $measureStaffIndex ]=----------");
          
          // Get the left and right edges of measure
          // staff first child is horizontal barline.
          // attribute D has it's path (x1, y1, x2, y2)
          List<String> staffBarlineCoords = staff.firstElementChild!.getAttribute(_D)!.split(" ");
          // Substring(1) so that it takes off SVG path argument (M, L, etc)
          int staffEndX = int.parse(staffBarlineCoords[2].substring(1));
          
          List< List<int> > boundList = [];
          List<String> idList = [];
          int layerIndex = 0;
          for (XmlElement staffChild in staff.findElements(_G)) {
            // Only take layers, and then unpack all their children
            if (staffChild.getAttribute(_CLASS) == _LAYER) {
              for (XmlElement layerChild in staffChild.childElements) {
                unpackElementBounds(layerChild, boundList, idList, -1, layerIndex);
              }
              layerIndex++;
            }
          }
          
          // Sort the hitboxes by their X position
          boundList.sort((a, b) => a[0].compareTo(b[0]));
          
          // For each group found, add:
          //  - columnMarker value in columnMarkers[measureStaffIndex]
          //  - elementGroupIDs value in elementGroupIDs[measureStaffIndex]
          //  - List of hitboxes in elementHitboxes[measureStaffIndex] (for group)
          //  - List of element IDs (string) in elementIDs[measureStaffIndex] (for group)
          //
          // For each group found, create:
          //  - int: Bound coordinate that marks left bound
          //  - String: Group id of groups (with slashes if multiple layers)
          //  - List<List<int>>: sorted bound boxes (for this group only)
          //  - List<String>: sorted string IDs (from int and id list)
          
          /// Local function that checks to see if the given hitbox makes
          /// any records for being the lowest or highest element in its
          /// row.  If so, the corresponding variable is updated.
          void checkMaxOrMinY(int hitboxIndex, int msi) {
            int tempI = msi % staffCount;
            if (boundList[hitboxIndex][1] < rowMinY[tempI]) {
              rowMinY[tempI] = boundList[hitboxIndex][1];
            }
            if (boundList[hitboxIndex][1] + boundList[hitboxIndex][3] > rowMaxY[tempI]) {
              rowMaxY[tempI] = boundList[hitboxIndex][1] + boundList[hitboxIndex][3];
            }
          }
          
          String groupIDString;
          int colI = elementHitBoxes[measureStaffIndex].length;
          elementHitBoxes[measureStaffIndex].add([]);
          elementIDs[measureStaffIndex].add([]);
          
          int thisGroupMaxX;
          
          // When representing a hitbox, 7 numbers are used.
          //  0  1    2      3       4    5      6
          // [X, Y, Width, Height, Layer, id, groupID]
          
          //  First Hitbox Steps:
          //    - Set thisGroupMaxX to this element X + Width
          //    - Set groupIDString to this groupID
          //    - Add hitbox to elementHitBoxes[msi][colI] (just indices 0-4) (don't add id ints)
          //    - Add element ID to elementIDs[msi][colI]
          //    - Check to see if it sets a maxY or minY
          //
          //  Per Hitbox Steps:
          //    - Check to see if it sets a maxY or minY
          //    - Check to see if it overlaps with previous group
          //      - If YES:
          //        - Add hitbox to elementHitBoxes[msi][colI] (just 0-4)
          //        - Add element ID to elementIDs[msi][colI]
          //        - Add hitbox group ID to group ID string (if not contains)
          //        - Check to see if this element's max X is new group record
          //      - If NO:
          //        - New group is found.
          //        - Calculate the 1/2-point between hitbox[i].x, and thisGroupMaxX
          //        - Add this value to columnMarkers[msi]
          //        - Add the group ID string to elementGroupIDs[msi]
          //        - Do resetting steps:
          //          - colI++
          //          - Add an empty list to elementHitBoxes[msi], and elementIDs[msi]
          //          - Set thisGroupMaxX to this element X + Width
          //          - Set groupIDString to this element's group ID
          //
          //  When done with all hitboxes:
          //    - Add the right page margin seperator to the columnMarkers[msi]
          //    - Add the right page edge seperator to the columnMarkers[msi]
          //    - Add the groupIDString to elementGroupIDs[msi]
          //    - Add the string "" to elementGroupIDs
          
          // Handle the first hitbox
          print("Hitbox: ${boundList[0]}");
          thisGroupMaxX = boundList[0][0] + boundList[0][2];
          groupIDString = idList[ boundList[0][6] ];
          elementHitBoxes[measureStaffIndex][colI].add(boundList[0].sublist(0, 5));
          elementIDs[measureStaffIndex][colI].add(idList[ boundList[0][5] ]);
          checkMaxOrMinY(0, measureStaffIndex);
          
          // Handle all other hitboxes
          for (int i = 1; i < boundList.length; i++) {
            List<int> box = boundList[i];
            print("Hitbox: $box");
            print("overlap: ${box[0] < thisGroupMaxX}");
            checkMaxOrMinY(i, measureStaffIndex);
            if (box[0] < thisGroupMaxX) {
              print("OVERLAP between $box and $thisGroupMaxX");
              // Same as existing group
              elementHitBoxes[measureStaffIndex][colI].add(box.sublist(0, 5));
              elementIDs[measureStaffIndex][colI].add(idList[ box[5] ]);
              if (!groupIDString.contains(idList[ box[6] ])) {
                groupIDString += "/${idList[ box[6] ]}";
              }
              thisGroupMaxX = max(thisGroupMaxX, box[0] + box[2]);
            } else {
              // New Group
              print("NO overlap.  Line is: ${(box[0] + thisGroupMaxX) ~/ 2}.");
              print("Adding val to $measureStaffIndex ${columnMarkers[measureStaffIndex]}");
              int seperatingLine = (box[0] + thisGroupMaxX) ~/ 2;
              columnMarkers[measureStaffIndex].add(seperatingLine);
              elementGroupIDs[measureStaffIndex].add(groupIDString);
              // Resetting Steps
              colI++;
              elementHitBoxes[measureStaffIndex].add([]);
              elementIDs[measureStaffIndex].add([]);
              thisGroupMaxX = box[0] + box[2];
              groupIDString = idList[ box[6] ];

            }
          } // End for loop
          
          // Close things up
          columnMarkers[measureStaffIndex].add(staffEndX);
          elementGroupIDs[measureStaffIndex].add(groupIDString);
          
          // Increment counter that represents that we are moving
          // down a line - to the next staff in the music downwards
          measureStaffIndex++;
          print("Incrementing msi to $measureStaffIndex");
          if (measureStaffIndex > 4) return;
        } // End Staff
        
      } // End measure
      
      // At end of each system (line of measures), add the right page margin to our hitbox system
      for (int j = systemRowIndex; j < systemRowIndex + staffCount; j++) {
        columnMarkers[j].add(pageWidth);
        elementGroupIDs[j].add("");
      }
      
      // Also add row markers to list
      rowMarkers.add( (rowMinY[0] + hangingRowMaxY) ~/ 2 );
      for (int i = 1; i < staffCount; i++) {
        rowMarkers.add( (rowMinY[i] + rowMaxY[i-1]) ~/ 2 );
      }
      
    } // End systems
    
    // Add a final row marker for the last layer
    rowMarkers.add( rowMaxY[rowMaxY.length-1] + LowestStaffHitboxMargin );
    
  } // End initHitboxes
  
  String drawHitboxes() {
    
    print("Drawing the hitboxes!");
    print("rowMarkers length: ${rowMarkers.length}");
    
    String svg = "<svg viewBox='0 0 $pageWidth $pageHeight' width='2100px' height='2970px'><g>";
    
    for (int row in rowMarkers) {
      svg += "<path d='M0 $row L$pageWidth $row' stroke='#FF0000' stroke-width='22' />";
    }
    
    for (int r = 0; r < rowMarkers.length-1; r++) {
      print("Column lines: ${columnMarkers[r]}");
      for (int col in columnMarkers[r]) {
        svg += "<path d='M$col ${rowMarkers[r]} L$col ${rowMarkers[r+1]}' stroke='#0000FF' stroke-width='17' />";
      }
    }
    
    svg += "</g></svg>";
    return svg;
  }
  
  /// Recursive method to pull all individual elements from a measure line
  /// for further processing afterwards.
  void unpackElementBounds(XmlElement el, List< List<int> > boundsList, List<String> idList, int groupID, int layer) {
    if (el.name.toString() != _G) return;
    
    String elClass = el.getAttribute(_CLASS) ?? "";
    
    int elID = -1;
    if (!ElementsWhoseIDToIgnore.contains(elClass)) {
      String? elIDString = el.getAttribute(_ID);
      if (elIDString == null) {
        print("[Unpacker] Found element without ID! (${el.name})");
        return;
      }
      elID = idList.length;
      idList.add(elIDString);
    }
    
    // Check to see if this element should be ignored
    if (ElementsToIgnoreDuringUnpacking.contains(elClass)) { return; }
    
    // Check to see if this element should be split up before unpacking
    else if (ElementsToUnpackFurther.contains(elClass)) {
      for (XmlElement childEl in el.childElements) {
        unpackElementBounds(childEl, boundsList, idList, elID, layer);
      }
    
    // Otherwise, unpack this element (scrape it's bounds from the svg)
    } else {
      
      switch (elClass) {
        case _NOTE:
          extractHitboxOfNote(el, boundsList, idList, groupID, elID, layer);
          break;
        case _REST:
          extractHitboxOfRest(el, boundsList, idList, groupID, elID, layer);
          break;
        case _MREST:
          extractHitboxOfMeasureRest(el, boundsList, idList, groupID, elID, layer);
          break;
        default:
          print("[Unpacker] Element class not expected!  Class: $elClass");
          break;
      }
    } // end Else clause
    
  } // end unpackElementBounds
  
  void extractHitboxOfNote(XmlElement el, List<List<int>> boundsList, List<String> idList, int groupID, int elementID, int layer) {
    // This method gets the bounds of a note, but also
    //  gets the bounds of any connecting accidentals.
    //  The hitboxes are then designed to overlap by 1 pixel,
    //  so that they are put into a group together but still
    //  have seperate hitboxes
    
    // Get the bounds of the notehead
    List<int> noteBounds = parseXYWH(el.firstElementChild!.firstElementChild!);
    
    // Check appropriate group ID
    if (groupID == -1) {
      // If no group holds this, then the group ID = element ID for insertion purposes
      groupID = elementID;
    }
    
    // Add in information about IDs and layer, and add to master list of hitboxes
    noteBounds.addAll([layer, elementID, groupID]);
    boundsList.add(noteBounds);
    
    // Check to see if the note has an accidental attached
    bool foundAccid = false;
    XmlElement? accid;
    // hasAccid only gets tripped if the foundAccid gets tripped twice.
    // SVG structure is weird and this is what signifies a true accidental.
    for (XmlElement child in el.childElements) {
      if (child.getAttribute(_CLASS) == _ACCID) {
        foundAccid = !foundAccid;
        if (!foundAccid) {
          accid = child;
        }
      }
    }
    
    // Parse the accidental (if one was found)
    if (accid != null) {
      // Get accidental ID and add to the ID list (to allow integer representation)
      int accidId = idList.length;
      idList.add(accid.getAttribute(_ID)!);
      
      // Parse accidental bounds (except for width)
      int accidX = int.parse(accid.firstElementChild!.getAttribute(_X)!);
      int accidY = int.parse(accid.firstElementChild!.getAttribute(_Y)!);
      String accidHString = accid.firstElementChild!.getAttribute(_HEIGHT)!;
      int accidH = int.parse(accidHString.substring(0, accidHString.length-2));
      
      // Define width so that it overlaps with notehead by 1 pixel
      int accidW = (noteBounds[0] - accidX) + 1;
      
      // Add accidental bounds to master bounds list
      // (group ID is same as note, with unique element ID)
      boundsList.add([
        accidX, accidY, accidW, accidH,
        layer, accidId, groupID
      ]);
      
    }
    
  }
  
  void extractHitboxOfRest(XmlElement el, List<List<int>> boundsList, List<String> idList, int groupID, int elementID, int layer) {
    // Check appropriate group ID
    if (groupID == -1) {
      // If no group holds this, then the group ID = element ID for insertion purposes
      groupID = elementID;
    }
    
    // Simply parse bounds from the <use> tag that is the first and only child of the rest group
    List<int> bounds = parseXYWH(el.firstElementChild!);
    bounds.addAll([ layer, elementID, groupID ]);
    boundsList.add(bounds);
  }
  
  void extractHitboxOfMeasureRest(XmlElement el, List<List<int>> boundsList, List<String> idList, int groupID, int elementID, int layer) {
    // Check appropriate group ID
    if (groupID == -1) {
      // If no group holds this, then the group ID = element ID for insertion purposes
      groupID = elementID;
    }
    
    // Simply parse bounds from the <use> tag that is the first and only child of the rest group
    List<int> bounds = parseXYWH(el.firstElementChild!);
    bounds.addAll([ layer, elementID, groupID ]);
    boundsList.add(bounds);
  }
  
  /// Parses attributes called "x", "y", "width", and "height" as integers
  /// from the passed element, and removes the last 2 characters from the
  /// last two with the assumption that they end with "px".
  List<int> parseXYWH(XmlElement el) {
    
    String? width = el.getAttribute(_WIDTH);
	if (width == null) {
		print("\nProblem!  Element does not have $_WIDTH! El: ${el.name} (${el.attributes})");
		return [0, 0, 1, 1];
	}
    String? height = el.getAttribute(_HEIGHT);
	if (height == null) {
		print("\nProblem!  Element does not have $_HEIGHT! El: ${el.name} (${el.getAttribute("id")})");
		return [0, 0, 1, 1];
	}
	String? elX = el.getAttribute(_X);
	if (elX == null) {
		print("\nProblem!  Element does not have $_X! El: ${el.name} (${el.getAttribute("id")})");
		return [0, 0, 1, 1];
	}
	String? elY = el.getAttribute(_Y);
	if (elY == null) {
		print("\nProblem!  Element does not have $_Y! El: ${el.name} (${el.getAttribute("id")})");
		return [0, 0, 1, 1];
	}
    
    return [
      int.parse(elX),
      int.parse(elY),
      int.parse(width.substring(0, width.length-2)), // Remove last 2 chars because length and width end in "px"
      int.parse(height.substring(0, height.length-2))
    ];
    
    
  }
  
} // end Class

