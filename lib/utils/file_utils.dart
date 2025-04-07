import 'dart:io';
import 'package:path/path.dart' as path;

Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!(await destination.exists())) {
    await destination.create(recursive: true);
  }
  await for (var entity in source.list(recursive: false)) {
    if (entity is Directory) {
      String newDirPath = path.join(destination.path, path.basename(entity.path));
      await copyDirectory(entity, Directory(newDirPath));
    } else if (entity is File) {
      String newPath = path.join(destination.path, path.basename(entity.path));
      await entity.copy(newPath);
    }
  }
}