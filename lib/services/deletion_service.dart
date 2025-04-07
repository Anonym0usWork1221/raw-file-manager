import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

Future<void> bulkDeleteFiles(List<String> paths, bool permanent) async {
  await compute(deleteFilesIsolate, {'paths': paths, 'permanent': permanent});
}

void deleteFilesIsolate(Map<String, dynamic> params) {
  List<String> paths = List<String>.from(params['paths'] as List);
  bool permanent = params['permanent'] as bool;

  for (String p in paths) {
    try {
      if (permanent) {
        if (FileSystemEntity.typeSync(p) == FileSystemEntityType.directory) {
          Directory(p).deleteSync(recursive: true);
        } else {
          File(p).deleteSync();
        }
      } else {
        String recycleBinPath =
        path.join("/storage/emulated/0", "RawFileManager", "RecycleBin");
        Directory binDir = Directory(recycleBinPath);
        if (!binDir.existsSync()) {
          binDir.createSync(recursive: true);
        }
        String newPath = path.join(recycleBinPath, path.basename(p));
        if (FileSystemEntity.typeSync(p) == FileSystemEntityType.directory) {
          Directory(p).renameSync(newPath);
        } else {
          File(p).renameSync(newPath);
        }
      }
    } catch (e) {
      print("Error deleting $p: $e");
    }
  }
}