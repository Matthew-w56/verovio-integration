
// ignore_for_file: non_constant_identifier_names, avoid_print, constant_identifier_names

/// TODO for next time:
/// Realize that the page offset was 500 in each direction.  This may possibly simplify the
/// hitbox stuff.  Fix the problem by adding in the offsets, and finding how to get
/// bounds from the true box.  Maybe it really is drawing at the top left?  But
/// then why is it flipped?

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';


class HitboxManager {
  
  // Constants to use in syntax-critical strings to avoid run-time
  //  typo problems
  static const String 
      _ACCID = "accid",
      _BEAM = "beam",
      _CHORD = "chord",
      _CLASS = "class",
      _D = "d",
      _DEFS = "defs",
      _G = "g",
      _HEIGHT = "height",
      _ID = "id",
      _LAYER = "layer",
      _MEASURE = "measure",
      _MREST = "mRest",
      _NOTE = "note",
      _PAGE_MARGIN = "page-margin", 
      _PATH = "path",
      _REST = "rest",
      _SPACE = "space",
      _STAFF = "staff",
      _STEM = "stem",
      _SVG = "svg",
      _SYMBOL = "symbol",
      _SYSTEM = "system",
      _TRANSFORM = "transform",
      _VIEWBOX = "viewBox",
      _WIDTH = "width",
      _X = "x", _Y = "y",
      _XLINKHREF = "xlink:href";
  
  static const List<String> 
      ElementsToIgnoreDuringUnpacking = [_STEM, _SPACE],
      ElementsToUnpackFurther = [_BEAM, _CHORD],
      ElementsWhoseIDToIgnore = [_BEAM];
  
  static const int ASSUMED_VIEWPORT_SIZE = 1000;
  
  static const int LowestStaffHitboxMargin = 40;
  
  // When representing a hitbox, 7 numbers are used.
  //  0  1    2      3       4    5      6
  // [X, Y, Width, Height, Layer, id, groupID]
  
  Map<String, List<int>> symbolBounds = {};

  List<int> rowMarkers = [];
  //List<List<int>> specialRects = [];
  List<List< int >> columnMarkers = [];
  List<List< String >> elementGroupIDs = [];
  // Inner list is one note group (chord, note, etc)
  // Middle list is a system (line)
  // Outter list is the score.
  // So index with ES[line][columnMarker] and look down that list for element threshold
  List<List< List<List<int>> >> elementHitboxes = [];
  List<List< List<String> >> elementIDs = [];
  
  int pageHeight = -1;
  int pageWidth = -1;
  int pageOffsetX = 0;
  int pageOffsetY = 0;
  
  HitboxManager();
  
  void initHitboxes(String imageSVG) {
    
    // Let the XML library parse the SVG document as an xml doc
    final doc = XmlDocument.parse(imageSVG);
    
    // Parse all the real bounds from each reused symbol
    parseSymbolBounds(doc.getElement(_SVG)!.getElement(_DEFS)!);
    
    // Scrape the page dimensions from the main SVG tag's attributes
    List<String> pageDims = doc.getElement(_SVG)!.getAttribute(_VIEWBOX)!.split(" ");
    pageWidth = int.parse(pageDims[2]);
    pageHeight = int.parse(pageDims[3]);
    
    // Make sure we are grabbing information correctly from the document
    XmlElement? pageMarginWrapper = doc.getElement(_SVG)?.getElement(_G);
    if (pageMarginWrapper == null || pageMarginWrapper.getAttribute(_CLASS) != _PAGE_MARGIN) {
      print("First element grab wasn't page margin!");
      print(pageMarginWrapper);
      return;
    }
    // Collect margin shift applied in the page-margin element
    String page_margins_string = pageMarginWrapper.getAttribute(_TRANSFORM) ?? "translate(0, 0)";
    List<String> transforms = page_margins_string.substring(10, page_margins_string.length-1).split(", ");
    pageOffsetX = int.parse(transforms[0]);
    pageOffsetY = int.parse(transforms[1]);
    
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
      columnMarkers.addAll(List.generate(staffCount, (_) => [marginSeperator]));
      elementGroupIDs.addAll(List.generate(staffCount, (_) => [""]));
      elementHitboxes.addAll(List.generate(staffCount, (_) => []));
      elementIDs.addAll(List.generate(staffCount, (_) => []));
      
      // Handle the measures themselves now
      for (XmlElement measure in system.childElements) {
        if (measure.getAttribute(_CLASS) != _MEASURE) continue;
        //print("----------=[ Starting Measure ]=----------");
        
        int measureEndX = 77;
        List<String>? barLines = measure.firstElementChild?.firstElementChild?.getAttribute(_D)?.split(" ");
        if (barLines == null) {
          print("Measure did not have bar lines!  measure first child: ${measure.firstElementChild}");
        } else {
          measureEndX = int.parse(barLines[2].substring(1)) + pageOffsetX;
        }
       
        
        int measureStaffIndex = systemRowIndex;
        for (XmlElement staff in measure.childElements) {
          if (staff.getAttribute(_CLASS) != _STAFF) continue;

          print("----------=[ Starting Staff $measureStaffIndex ]=----------");
          
          print("Measure end at $measureEndX");
          
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
          int colI = elementHitboxes[measureStaffIndex].length;
          elementHitboxes[measureStaffIndex].add([]);
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
          //      - DO THESE STEPS for every hitbox, regardless of new group or not:
          //      - Add hitbox to elementHitBoxes[msi][colI] (just 0-4)
          //      - Add element ID to elementIDs[msi][colI]
          //      - Add hitbox group ID to group ID string (if not contains)
          //      - Check to see if this element's max X is new group record
          //
          //  When done with all hitboxes:
          //    - Add the right page margin seperator to the columnMarkers[msi]
          //    - Add the right page edge seperator to the columnMarkers[msi]
          //    - Add the groupIDString to elementGroupIDs[msi]
          //    - Add the string "" to elementGroupIDs
          
          // If no elements were found in layer, continue
          if (boundList.isEmpty) {
            print("Nothing in msi $measureStaffIndex somehow..");
            continue;
          }
          
          // Handle the first hitbox
          thisGroupMaxX = boundList[0][0] + boundList[0][2];
          groupIDString = idList[ boundList[0][6] ];
          elementHitboxes[measureStaffIndex][colI].add(boundList[0].sublist(0, 5));
          elementIDs[measureStaffIndex][colI].add(idList[ boundList[0][5] ]);
          checkMaxOrMinY(0, measureStaffIndex);
          
          // Handle all other hitboxes
          for (int i = 1; i < boundList.length; i++) {
            List<int> box = boundList[i];
            checkMaxOrMinY(i, measureStaffIndex);
            if (box[0] >= thisGroupMaxX) {
              // New Group
              int seperatingLine = (box[0] + thisGroupMaxX) ~/ 2;
              columnMarkers[measureStaffIndex].add(seperatingLine);
              elementGroupIDs[measureStaffIndex].add(groupIDString);
              // Resetting Steps
              colI++;
              elementHitboxes[measureStaffIndex].add([]);
              elementIDs[measureStaffIndex].add([]);
              thisGroupMaxX = box[0] + box[2];
              groupIDString = idList[ box[6] ];

            }
            // Do these steps for any hitbox
            elementHitboxes[measureStaffIndex][colI].add(box.sublist(0, 5));
            elementIDs[measureStaffIndex][colI].add(idList[ box[5] ]);
            if (!groupIDString.contains(idList[ box[6] ])) {
              groupIDString += "/${idList[ box[6] ]}";
            }
            thisGroupMaxX = max(thisGroupMaxX, box[0] + box[2]);
            
          } // End for loop
          
          // Close things up
          columnMarkers[measureStaffIndex].add(measureEndX);
          elementGroupIDs[measureStaffIndex].add(groupIDString);
          
          // Increment counter that represents that we are moving
          // down a line - to the next staff in the music downwards
          measureStaffIndex++;
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
  
  void parseSymbolBounds(XmlElement root) {
    
    /// SVG Syntax:
    /// Capital letters use absolute positioning (x, y)
    /// Lower-case letters use relative positioning (dx, dy)
    /// Commands with multiple dx dy, etc are all relative to
    ///    the start position, not the last relative one.
    /// 
    /// M x y   -   -   -   - Move To
    /// L x y   -   -   -   - Line To
    /// H x -   -   -   -   - Horizontal Line
    /// V y -   -   -   -   - Vertical line
    /// C x1 y1 x2 y2 x3 y3 - Cubic curves (end at x3 y3)
    /// Z   -   -   -   -   - Line To Start
    /// S x2 y2 x3 y3   -   - Curve ends at x3 y3
    /// Q x1 y1 x2 y2   -   - Curve with one control point, and ends at x2 y2
    /// 
    
    for (XmlElement symbol in root.childElements) {
      // There shouldn't ever be something here not called <symbol>.  But to be safe, skip them.
      if (symbol.name.toString() != _SYMBOL) continue;
      
      // Get information about the symbol in general
      String symbolID = symbol.getAttribute(_ID)!;
      List<String> viewBox = symbol.getAttribute(_VIEWBOX)!.split(" ");
      int vbWidth = int.parse(viewBox[2]);
      int vbHeight = int.parse(viewBox[3]);
      
      // Select the path and make sure assumptions hold
      XmlElement path = symbol.childElements.first;
      if (path.getAttribute(_TRANSFORM) != "scale(1,-1)") {
        print("[SYMBOL PARSE] Path didn't have scale transform of 1,-1!  Was: [${path.getAttribute(_TRANSFORM)}]!");
      }
      
      String dataString = path.getAttribute(_D)!;
      // Take anything that isn't a (-), a digit, or a space, and pad it with spaces.
      List<String> data = "M ${dataString.substring(1).replaceAllMapped(RegExp(r'[^0-9 \-]'), (match) {
        return " ${match.group(0)} ";
      })}".trimRight().split(" ");
      
      //M 20 -78 c 84 97 114 180 134 329 h 170 c -13 -32 -82 -132 -99 -151 l -84 -97 c -33 -36 -59 -63 -80 -81 h 162 v 102 l 127 123 v -225 h 57 v -39 h -57 v -34 c 0 -43 19 -65 57 -65 v -34 h -244 v 36 c 48 0 60 26 60 70 v 27 h -203 v 39 z
      
      
      // Current position tracking (since most stuff is relative to last position)
      int currX = 0;
      int currY = 0;
      int firstX = int.parse(data[1]);
      int firstY = int.parse(data[2]);
      int minX = vbWidth,
          minY = vbHeight,
          maxX = 0,
          maxY = 0;
      // Purposely no automatic i increment.  Always increments differently based on command
      for (int i = 0; i < data.length; ) {
        switch (data[i]) {
          case "M":
            currX = int.parse(data[i+1]);
            currY = int.parse(data[i+2]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 3;
            break;
          case "m":
            currX += int.parse(data[i+1]);
            currY += int.parse(data[i+2]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 3;
            break;
          case "L":
            currX = int.parse(data[i+1]);
            currY = int.parse(data[i+2]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 3;
            break;
          case "l":
            currX += int.parse(data[i+1]);
            currY += int.parse(data[i+2]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 3;
            break;
          case "H":
            currX = int.parse(data[i+1]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            i += 2;
            break;
          case "h":
            currX += int.parse(data[i+1]);
            if (currX < minX) minX = currX;
            if (currX > maxX) maxX = currX;
            i += 2;
            break;
          case "V":
            currY = int.parse(data[i+1]);
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 2;
            break;
          case "v":
            currY += int.parse(data[i+1]);
            if (currY < minY) minY = currY;
            if (currY > maxY) maxY = currY;
            i += 2;
            break;
          case "C":
            List<int> locals = parseCurveInPath(data, i, currX, currY, true, false);
            if (locals[0] < minX) minX = locals[0];
            if (locals[1] < minY) minY = locals[1];
            if (locals[2] > maxX) maxX = locals[2];
            if (locals[3] > maxY) maxY = locals[3];
            currX = locals[4];
            currY = locals[5];
            i += 7;
            break;
          case "c":
            List<int> locals = parseCurveInPath(data, i, currX, currY, true, true);
            if (locals[0] < minX) minX = locals[0];
            if (locals[1] < minY) minY = locals[1];
            if (locals[2] > maxX) maxX = locals[2];
            if (locals[3] > maxY) maxY = locals[3];
            currX = locals[4];
            currY = locals[5];
            i += 7;
            break;
          case "Z":
          case "z":
            currX = firstX;
            currY = firstY;
            i += 1;
            break;
          case "S":
          case "Q":
            List<int> locals = parseCurveInPath(data, i, currX, currY, false, false);
            if (locals[0] < minX) minX = locals[0];
            if (locals[1] < minY) minY = locals[1];
            if (locals[2] > maxX) maxX = locals[2];
            if (locals[3] > maxY) maxY = locals[3];
            currX = locals[4];
            currY = locals[5];
            i += 5;
            break;
          case "s":
          case "q":
            List<int> locals = parseCurveInPath(data, i, currX, currY, false, true);
            if (locals[0] < minX) minX = locals[0];
            if (locals[1] < minY) minY = locals[1];
            if (locals[2] > maxX) maxX = locals[2];
            if (locals[3] > maxY) maxY = locals[3];
            currX = locals[4];
            currY = locals[5];
            i += 5;
            break;
          case "":
          case " ":
            i++;
            continue;
          // I'm not supporting T and t right now.  I don't think Verovio uses those
          default:
            print("Unexpected svg command: ${data[i]}!");
            i++;
            continue;
        } // end Switch
      } // end For block
      
      List<int> bounds = [minX, minY, (maxX - minX), (maxY - minY), maxX, maxY];
      symbolBounds["#$symbolID"] = bounds;
      
    } // end For Symbol in Defs
    
  }
  
  /// Returns [minX, minY, maxX, maxY, endX, endY] for a curve.
  List<int> parseCurveInPath(List<String> data, int i, int currX, int currY, bool twoControls, bool relative) {
    int minX = currX,
        minY = currY,
        maxX = currX,
        maxY = currY;
    
    int ctrX1, ctrY1, ctrX2 = 0, ctrY2 = 0, endX, endY;
    if (relative) {
      ctrX1 = currX + int.parse(data[i+1]);
      ctrY1 = currY + int.parse(data[i+2]);
      if (twoControls) {
        ctrX2 = currX + int.parse(data[i+3]);
        ctrY2 = currY + int.parse(data[i+4]);
        endX = currX + int.parse(data[i+5]);
        endY = currY + int.parse(data[i+6]);
      } else {
        endX = currX + int.parse(data[i+3]);
        endY = currY + int.parse(data[i+4]);
      }
    } else {
      ctrX1 = int.parse(data[i+1]);
      ctrY1 = int.parse(data[i+2]);
      if (twoControls) {
        ctrX2 = int.parse(data[i+3]);
        ctrY2 = int.parse(data[i+4]);
        endX = int.parse(data[i+5]);
        endY = int.parse(data[i+6]);
      } else {
        endX = int.parse(data[i+3]);
        endY = int.parse(data[i+4]);
      }
      
    }
    
    int diffX = endX - currX;
    int diffXabs = diffX > 0 ? diffX : -diffX;
    int diffY = endY - currY;
    int diffYabs = diffY > 0 ? diffY : -diffY;
    if (diffXabs > diffYabs) {
      // Real curve movement is in Y direction
      int maxCtrY = ctrY1;
      if (twoControls && ctrY2 > ctrY1) maxCtrY = ctrY2;
      int minCtrY = ctrY1;
      if (twoControls && maxCtrY == ctrY1) minCtrY = ctrY2;
      if (maxCtrY > currY) {
        // Curve goes towards +y
        int curveMaxY = (maxCtrY + currY) ~/ 2;
        if (endY < minY) minY = endY;
        if (curveMaxY > maxY) maxY = curveMaxY;
      } else {
        // Curve goes towards -y
        int curveMinY = (minCtrY + currY) ~/ 2;
        if (curveMinY < minY) minY = curveMinY;
        if (endY > maxY) maxY = endY;
      }
      // Check X max/min with new point
      if (endX < minX) minX = endX;
      if (endX > maxX) maxX = endX;
    } else {
      // Real curve movement is in X direction
      int maxCtrX = ctrX1;
      if (twoControls && ctrX2 > ctrX1) maxCtrX = ctrX2;
      int minCtrX = ctrX1;
      if (twoControls && maxCtrX == ctrX1) minCtrX = ctrX2;
      if (maxCtrX > currX) {
        // Curve goes towards +x
        int curveMaxX = (maxCtrX + currX) ~/ 2;
        if (endX < minX) minX = endX;
        if (curveMaxX > maxX) maxX = curveMaxX;
      } else {
        // Curve goes towards -x
        int curveMinX = (minCtrX + currX) ~/ 2;
        if (curveMinX < minX) minX = curveMinX;
        if (endX > maxX) maxX = endX;
      }
      // Check Y max/min with new point
      if (endY < minY) minY = endY;
      if (endY > maxY) maxY = endY;
    }
    
    return [minX, minY, maxX, maxY, endX, endY];
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
        case _MREST:
          extractHitboxOfRest(el, boundsList, idList, groupID, elID, layer);
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
    
    //print("Extracting: ${idList[elementID]} ($elementID) From: $idList");
    
    // Check appropriate group ID
    if (groupID == -1) {
      // If no group holds this, then the group ID = element ID for insertion purposes
      groupID = elementID;
    }
    
    // Get the bounds of the notehead
    List<int> noteUseBounds = parseXYWH(el.firstElementChild!.firstElementChild!);
    
    // Find the tag ID that the <use> tag references (within notehead)
    String? elTagID = el.firstElementChild?.firstElementChild?.getAttribute(_XLINKHREF);
    if (elTagID == null) {
      print("Failed to get tag ID!  elID: $elementID.");
      elTagID = "";
    }
    
    // Call method to adjust the Hitbox to fit actual glyph
    List<int> noteBounds = getBoundsAfterScaling(noteUseBounds, elTagID);
    
    // Add in information about IDs and layer, and add to master list of hitboxes
    noteBounds.addAll([layer, elementID, groupID]);
    boundsList.add(noteBounds);
    
    // Check for accidentals tied to this note
    for (XmlElement child in el.childElements) {
      // Also check to see if it has children.  For some reason, some scores cause a lot
      // of accid tags to be generated, with no effect or children.
      if (child.getAttribute(_CLASS) == _ACCID && child.children.isNotEmpty) {
        // Parse the accidental found
        
        // Get accidental ID and add to the ID list (to allow integer representation)
        int accidId = idList.length;
        idList.add(child.getAttribute(_ID)!);
        
        // Parse accidental bounds (except for width)
        List<int> accidUseBounds = parseXYWH(child.firstElementChild!);
        
        // Find the tag ID that the <use> tag references
        String? accidTagID = child.firstElementChild?.getAttribute(_XLINKHREF);
        if (accidTagID == null) {
          print("Failed to get tag ID for accidental!");
          accidTagID = "";
        }
        
        // Call method to adjust the Hitbox to fit actual glyph
        List<int> accidBounds = getBoundsAfterScaling(accidUseBounds, accidTagID);
        
        // Override the width so that it overlaps with notehead by 1 pixel (to classify as grouped)
        accidBounds[2] = (noteBounds[0] - accidBounds[0]) + 1;
        
        // Add accidental bounds to master bounds list
        // (group ID is same as note, with unique element ID)
        accidBounds.addAll([layer, accidId, groupID]);
        // Add hitbox to end list
        boundsList.add(accidBounds);
      }
    }
    
  }
  
  void extractHitboxOfRest(XmlElement el, List<List<int>> boundsList, List<String> idList, int groupID, int elementID, int layer) {
    // Check appropriate group ID
    if (groupID == -1) {
      // If no group holds this, then the group ID = element ID for insertion purposes
      groupID = elementID;
    }
    
    // Parse the x, y, width, and height mentioned in the <use> tag
    List<int> elUseBounds = parseXYWH(el.firstElementChild!);
    
    // Find the tag ID that the <use> tag references
    String? elTagID = el.firstElementChild?.getAttribute(_XLINKHREF);
    if (elTagID == null) {
      print("Failed to get tag ID!");
      elTagID = "";
    }
    
    // Call method to adjust the Hitbox to fit actual glyph
    List<int> bounds = getBoundsAfterScaling(elUseBounds, elTagID);
    
    // Add in metadata about hitbox
    bounds.addAll([ layer, elementID, groupID ]);
    // Add hitbox to end list
    boundsList.add(bounds);
  }
  
  /// Returns a list containing the adjusted [x, y, width, height]
  List<int> getBoundsAfterScaling(List<int> elUseBounds, String elTagID, ) {
    
    List<int>? elSymbolBounds = symbolBounds[elTagID];
    if (elSymbolBounds == null) {
      print("Could not find bounds for tagID: $elTagID!");
      return [0, 0, 0, 0];
    }
    
    //                   0     1     2      3       4     5
    // symbolBounds is  [minX, minY, width, height, maxX, maxY]
    //                   0  1  2      3
    // elUseBounds is   [x, y, width, height]
    // Steps: 
    // left bound is X + ((vpwidth + minX - symbolWidth) * (width / vpwidth))
    // top  bound is Y + ((vpheight + maxY - symbolHeight) * (height / vpheight))
    // width  is symbolWidth  * (width / vpwidth)
    // height is symbolHeight * (height / vpheight)

    double scalar = elUseBounds[2] / ASSUMED_VIEWPORT_SIZE;
    return [
      elUseBounds[0] + ((ASSUMED_VIEWPORT_SIZE + elSymbolBounds[0] - elSymbolBounds[2]) * scalar).round(),
      // Originally, elSymbolBounds[5] - ...
      elUseBounds[1] + ((ASSUMED_VIEWPORT_SIZE + elSymbolBounds[1] - elSymbolBounds[3]) * scalar).round(),
      (elSymbolBounds[2] * scalar).round(),
      (elSymbolBounds[3] * scalar).round()
    ];
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
  
  
  String drawHitboxes() {
    
    String svg = "<svg viewBox='0 0 $pageWidth $pageHeight' width='2100px' height='2970px'><g>";
    
    
    for (int row in rowMarkers) {
      // Draw the row lines (RED)
      svg += "<path d='M0 $row L$pageWidth $row' stroke='#FF0000' stroke-width='22' />";
    }
    
    for (int r = 0; r < rowMarkers.length-1; r++) {
      print("Column lines: ${columnMarkers[r]}");
      for (int col in columnMarkers[r]) {
        // Draw the column Lines (BLUE)
        svg += "<path d='M$col ${rowMarkers[r]} L$col ${rowMarkers[r+1]}' stroke='#0000FF' stroke-width='17' />";
      }
    }
    
    for (int r = 0; r < elementHitboxes.length; r++) {
      for (int c = 0; c < elementHitboxes[r].length; c++) {
        for (int g = 0; g < elementHitboxes[r][c].length; g++) {
          List<int> box = elementHitboxes[r][c][g];
          int endX = box[0] + box[2];
          int endY = box[1] + box[3];
          // Draw an X per hitbox
          svg += "<path d='M${box[0]} ${box[1]}, $endX $endY' stroke='#0000FF' stroke-width='20' data-id='${elementIDs[r][c][g]}' />";
          svg += "<path d='M$endX ${box[1]}, ${box[0]} $endY' stroke='#0000FF' stroke-width='20' data-id='${elementIDs[r][c][g]}' />";
        }
      }
    }

    svg += "</g></svg>";
    
    return svg;
  }
  
} // end Class

