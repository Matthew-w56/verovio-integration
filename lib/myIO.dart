
import 'package:path/path.dart' as p;
import 'dart:io';

class IOWorker {
  
  static String _getPathString(String relativePath) {
    return p.join(Directory.current.path, 'assets', relativePath);
  }
  
  ///Returns the text content of the given file.  The path is relative to
  ///the directory /assets/
  static String getFileText(String relativePath) {
    File file = File(_getPathString(relativePath));
    return file.readAsStringSync();
  }
  
  
  
}