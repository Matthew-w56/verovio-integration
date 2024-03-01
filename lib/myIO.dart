
import 'package:path/path.dart' as p;
import 'dart:io';

class IOWorker {
  
  static String getFileText(String relativePath) {
    File file = File(p.join(Directory.current.path, 'assets', relativePath));
    return file.readAsStringSync();
  }
  
}