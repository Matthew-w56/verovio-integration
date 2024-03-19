
class SVGAdjustor {
  
  /// Adjusts an svg string so that it can be drawn by the jovial_svg library.
  /// 
  /// Specifically, Jovial doesn't like the nested svg tag.  So we take that out,
  /// and put all attributes from both into the outter tag.
  static String adjustSVG(String input) {
    
    /// Previous to this method running, the file looks like:
    /// 
    /// <svg {attributes and such}>
    ///   ... stuff ...
    ///   <svg {more attributes that we need}>
    ///     ... The actual song (all notes and such) ...
    ///     ... Usually this is very long ...
    ///   </svg>
    /// </svg>
    /// 
    /// And we want it to look like:
    /// 
    /// <svg {all attributes from both tags}>
    ///   ... stuff ...
    ///   ... The actual song (all notes and such) ...
    /// </svg>
    
    // Steps:
    //  - Find the position of the first svg tag
    //  - Add 4 to that to get the index of the first space after "<svg" (POS1) [firstSpace]
    //  - Find the position of the next svg tag (POS2) [second]
    //  - Find the position of the following newline [newLineAfterSecond]
    //  - Substring out the first part until the newline
    //  - Substring out the last part, do the last min(100, len-firstpart) characters
    //  - Substring out the tags of the second svg (C)
    //  - Substring out the first part until the first svg's space (A)
    //  - Substring out the first part after the first svg's space uhtil POS2 (B)
    //  - In the last part, replace the first instance of "</svg>" with "" (D)
    //  - Concatenate: A, C, B, MIDDLE, D
    //  - Done!
    
    // Start by finding all indices that we'll need (not any faster to wait until first substring)
    int first = input.indexOf("<svg");
    int firstSpace = first + 4;
    int second = input.indexOf("<svg ", firstSpace);
    int newLineAfterSecond = input.indexOf("\n", second);
    int lastSvgClosingTag = input.lastIndexOf("</svg>");
    
    // By setting the end to the last svg tag, that one is removed, leaving only one left (what we want)
    String bulkOfFile = input.substring(newLineAfterSecond, lastSvgClosingTag);
    String firstChunk = input.substring(0, newLineAfterSecond);
    String untilFirstSvgTags = firstChunk.substring(0, firstSpace);
    String afterFirstSvgTags = firstChunk.substring(firstSpace, second);
    String secondLineAttrs = firstChunk.substring(second + 4, newLineAfterSecond-1);
    
    // Return the newly constructed string!
    return "$untilFirstSvgTags$secondLineAttrs$afterFirstSvgTags$bulkOfFile";
  }
  
}