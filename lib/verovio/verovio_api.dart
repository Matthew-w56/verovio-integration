/// Author: Matthew Williams
/// Date: March 2024
/// 
/// This file serves as an easier API to interact with the Verovio library.
/// Note: This is not a comprehensive list of methods we COULD use, just the
///       ones I thought we WOULD use.  For a complete list of methods we can
///       add in nice and easy, see the c_wrapper.h file.  For a complete list
///       of methods we could add with a small amount of work, see this page:
///       https://book.verovio.org/toolkit-reference/toolkit-methods.html

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:verovio_integration/verovio/generated_bindings.dart';

import 'svg_adjustor.dart';


class VerovioAPI {
  
  // ------------------------------[ Internal Pointers for Library ]------------------------------
  /// This variable holds the generated API that we use to interact with the dll mentioned in the path
  static final _binding = VerovioWrapper(DynamicLibrary.open("C:\\Program Files (x86)\\Verovio\\bin\\verovio.dll"));
  /// This pointer is our object, which has to be interacted with through a functional programming style throughout this file
  final _toolkitPointer = _binding.vrvToolkit_constructorResourcePath("C:\\Program Files (x86)\\Verovio\\share\\verovio".toNativeUtf8().cast());
  
  // --------------------[ Private helper methods to help with internal tasks ]-------------------- 
  
  /// Translate a nice String into a C-style char pointer
  Pointer<Char> _stringToCharPointer(String input) {
    return input.toNativeUtf8() as Pointer<Char>;
  }
  
  /// Translates a nice String into a C-style unsigned char pointer
  /// (This method is really only used in loadCompressedMusicXMLData)
  Pointer<UnsignedChar> _stringToUnsignedCharPointer(String input) {
    return input.toNativeUtf8() as Pointer<UnsignedChar>;
  }
  
  /// Translate a C-style char pointer into a nice String
  String _charPointerToString(Pointer<Char> input) {
    return input.cast<Utf8>().toDartString();
  }
  
  // ------------------------------[ Public Methods ]------------------------------
  
  /// Takes in a String representation of a score (file contents from MEI, MusicXML, etc), and
  /// goes through all the work to build the internal representation from it.
  /// 
  /// Note: While this varies by machine and by day, this method has historically taken about
  /// 1 second per page in the score.  It's not too quick.
  void loadData(String data) {
    _binding.vrvToolkit_loadData(_toolkitPointer, _stringToCharPointer(data));
  }
  
  /// Returns a String containing the SVG representation of the score (or selection, if one is
  /// set currently).  Use the page parameter to decide which page to render (1 by default), and
  /// use the generateXml parameter if you want the general XML header at the beginning of it
  /// (false by default)
  String getSVGOutput({int page = 1, bool generateXml = false}) {
    String svgRaw = _charPointerToString(_binding.vrvToolkit_renderToSVG(_toolkitPointer, page, generateXml));
    return SVGAdjustor.adjustSVG(svgRaw);
  }
  
    /// Returns a String containing the SVG representation of the score (or selection, if one is
  /// set currently).  Use the page parameter to decide which page to render (1 by default), and
  /// use the generateXml parameter if you want the general XML header at the beginning of it
  /// (false by default)
  @Deprecated("This Method is only for testing purposes and will cause rendering to break.  Use getSVGOutput.")
  String getSVGOutputNoAdjust({int page = 1, bool generateXml = false}) {
    return _charPointerToString(_binding.vrvToolkit_renderToSVG(_toolkitPointer, page, generateXml));
  }
  
  /// Takes in a Json-structured edit command and executes it.  Returns a boolean representing if the
  /// command was able to be successfully completed.  If false, get more information on why from the
  /// getEditInfo method.
  /// 
  /// Note: For more information about what kind of format they expect from an Edit command, see the
  /// EditCommands.md file in this directory
  bool executeEdit(String editToDo) {
    return _binding.vrvToolkit_edit(_toolkitPointer, _stringToCharPointer(editToDo));
  }
  
  /// Tells the library which measures to focus on whenever we ask to render anything again.
  /// To set bounds at the beginning or end of the score, set that parameter to -1.  (-1 start
  /// means the start of the score, -1 end means the end of the score).
  /// 
  /// Note: The library doesn't like having a selection set when loading data, so don't use this
  /// until we're ready to render.  Also, the resulting render will act like this is the only part
  /// of the score exists.  So if you select 5 measures from page 8, it still returns them as a
  /// 1-page score of 5 measures (So if you ask to render page 8, it will not work).
  void setSelection(int start, int end) {
    String startParsed = start as String;
    if (startParsed == "-1") startParsed = "start";
    String endParsed = end as String;
    if (endParsed == "-1") endParsed = "end";
    _binding.vrvToolkit_select(_toolkitPointer, _stringToCharPointer('{ "measureRange": "$startParsed-$endParsed" }'));
  }
  
  /// Removes any selection set by the setSelection method.  Full score will be rendered for
  /// any future renders.
  void clearSelection() {
    _binding.vrvToolkit_select(_toolkitPointer, _stringToCharPointer(""));
  }
  
  /// Render the score playback MIDI, and return as 64-bit encoding String.
  String renderToMIDI({String options=""}) {
    return _charPointerToString(_binding.vrvToolkit_renderToMIDI(_toolkitPointer, _stringToCharPointer(options)));
  }
  
  /// Render the score to a format called Plaine and Easie.
  String renderToPAE() {
    return _charPointerToString(_binding.vrvToolkit_renderToPAE(_toolkitPointer));
  }
  
  /// Returns a large Json-style dictionary of every single available option for the Verovio
  /// library, and their current values.  Most of these are defaults that we don't mess with.
  String getOptions() {
    return _charPointerToString(_binding.vrvToolkit_getOptions(_toolkitPointer));
  }
  
  /// Given a Json-style dictionary with options and their desired new values, this updates
  /// the master options list with any values you specified.  See getOptions for the full list
  /// of options we can change with this.
  void setOptions(String newOptions) {
    _binding.vrvToolkit_setOptions(_toolkitPointer, _stringToCharPointer(newOptions));
  }
  
  /// Returns a String containing an MEI representation of the score (which is the form that it is
  /// internally structured in, so this method is super fast and simple).
  String getMEIOutput() {
    return _charPointerToString(_binding.vrvToolkit_getMEI(_toolkitPointer, _stringToCharPointer("{}")));
  }
  
  /// Returns information about what happened during the last edit command that was run.  This will
  /// be an empty Json object if there have been no edit commands yet, or if the last one was
  /// successful.
  String getEditInfo() {
    return _charPointerToString(_binding.vrvToolkit_editInfo(_toolkitPointer));
  }
  
  /// Returns the number of pages in the current score (or current selection if there is one).
  int getPageCount() {
    return _binding.vrvToolkit_getPageCount(_toolkitPointer);
  }
  
  /// Returns the page that contains the given element
  int getPageWithElement(String elementId) {
    return _binding.vrvToolkit_getPageWithElement(_toolkitPointer, _stringToCharPointer(elementId));
  }
  
  /// Returns all attributes (in Json format) of the element with the given Id.
  String getElementAttributes(String elementId) {
    return _charPointerToString(_binding.vrvToolkit_getElementAttr(_toolkitPointer, _stringToCharPointer(elementId)));
  }
  
  /// Returns a Json object containing information about what page and notes are being played at
  /// the given time during playback (measured in milliseconds since the start of the score).
  String getElementsAtTime(int millisec) {
    return _charPointerToString(_binding.vrvToolkit_getElementsAtTime(_toolkitPointer, millisec));
  }
  
  /// Returns the time (in milliseconds) that the given element will be played during MIDI playback.
  /// 
  /// Note: The method renderToMIDI MUST be called before this, otherwise it breaks
  int getTimeForElement(String elementId) {
    return _binding.vrvToolkit_getTimeForElement(_toolkitPointer, _stringToCharPointer(elementId)) as int;
  }
  
  /// Unsure about this one, but the idea is that if you read the text directly of a compressed
  /// MusicXMl file, this can load that the same as a normal loadData call.
  bool loadCompressedMusicXMLData(String data) {
    return _binding.vrvToolkit_loadZipDataBuffer(_toolkitPointer, _stringToUnsignedCharPointer(data), data.length);
  }
  
  /// Takes in new options to decide how to render score (zoom, page size, etc), and redoes all the
  /// rendering and layout work.  To only re-do the vertical positions of notes, use redoPitchPosLayout.
  void redoLayout(String newOptions) {
    _binding.vrvToolkit_redoLayout(_toolkitPointer, _stringToCharPointer(newOptions));
  }
  
  /// Re-calculates all the vertical positions of notes.  This is a subset of the redoLayout method, which
  /// redoes everything.
  void redoPitchPosLayout() {
    _binding.vrvToolkit_redoPagePitchPosLayout(_toolkitPointer);
  }
  
}