import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:verovio_integration/verovio/generated_bindings.dart';


class VerovioMethodStore {
  
  // ------------------------------[ Internal Pointers for Library ]------------------------------
  
  static final _binding = VerovioWrapper(DynamicLibrary.open("C:\\Program Files (x86)\\Verovio\\bin\\verovio.dll"));
  final _toolkitPointer = _binding.vrvToolkit_constructorResourcePath("C:\\Program Files (x86)\\Verovio\\share\\verovio".toNativeUtf8().cast());
  
  // --------------------[ Private helper methods to help with internal tasks ]-------------------- 
  
  Pointer<Char> _stringToCharPointer(String input) {
    return input.toNativeUtf8() as Pointer<Char>;
  }
  
  String _charPointerToString(Pointer<Char> input) {
    return input.cast<Utf8>().toDartString();
  }
  
  // ------------------------------[ Public Methods ]------------------------------
  
  void setSelection(int start, int end) {
    _binding.vrvToolkit_select(_toolkitPointer, _stringToCharPointer('{ "measureRange": "2-3" }'));
  }
  
  void clearSelection() {
    _binding.vrvToolkit_select(_toolkitPointer, _stringToCharPointer(""));
  }
  
  String getOptions() {
    return _charPointerToString(_binding.vrvToolkit_getOptions(_toolkitPointer));
  }
  
  void setOptions(String newOptions) {
    _binding.vrvToolkit_setOptions(_toolkitPointer, _stringToCharPointer(newOptions));
  }
  
  void loadData(String data) {
    _binding.vrvToolkit_loadData(_toolkitPointer, _stringToCharPointer(data));
  }
  
  String getSVGOutput({int page = 1, bool generateXml = false}) {
    return _charPointerToString(_binding.vrvToolkit_renderToSVG(_toolkitPointer, page, generateXml));
  }
  
  String getMEIOutput() {
    return _charPointerToString(_binding.vrvToolkit_getMEI(_toolkitPointer, _stringToCharPointer("{}")));
  }
  
  String getHumdrumOutput() {
    return _charPointerToString(_binding.vrvToolkit_getHumdrum(_toolkitPointer));
  }
  
  void executeEdit(String editToDo) {
    bool success = _binding.vrvToolkit_edit(_toolkitPointer, _stringToCharPointer(editToDo));
    print("\nAttempted edit:\n$editToDo\nWith result:\n$success\n");
  }
  
}