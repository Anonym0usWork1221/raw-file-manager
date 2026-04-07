import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'dart:io';
import 'package:path/path.dart' as path;

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

// 定义回调函数类型：返回操作是否成功、处理的文件数量
typedef FileActionCallback = void Function(bool isSuccess, int fileCount);

// isMoving: true 表示剪切(移动)，false 表示复制
// 添加可选的回调参数，操作完成后触发
Future<void> bulkActionFiles(
  List<String> paths,
  bool isMoving,
  String destination, {
  FileActionCallback? onCompleted, // 可选的完成回调
}) async {
  bool isSuccess = true;
  int processedCount = 0;

  try {
    // 将回调需要的参数也传递给isolate，用于统计结果
    await compute(actionFilesIsolate, {
      'paths': paths,
      'isMoving': isMoving,
      'destination': destination,
    });

    // 统计成功处理的文件数（排除不存在的文件）
    processedCount = paths.where((path) {
      return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    }).length;
  } catch (e) {
    isSuccess = false;
    print('批量文件操作异常：$e');
  } finally {
    // 无论成功失败，都触发回调（如果传入了回调）
    onCompleted?.call(isSuccess, processedCount);
  }
}

/// Isolate中执行的文件操作核心逻辑
void actionFilesIsolate(Map<String, dynamic> params) {
  // 安全地解析参数
  List<String> paths = List<String>.from(params['paths'] as List? ?? []);
  bool isMoving = params['isMoving'] as bool? ?? false;
  String destination = params['destination'] as String? ?? '';

  // 验证目标路径是否有效
  if (destination.isEmpty) {
    print('Error: 目标路径不能为空');
    return;
  }

  Directory destDir = Directory(destination);
  if (!destDir.existsSync()) { // 通过Directory实例调用existsSync
    try {
      destDir.createSync(recursive: true);
    } catch (e) {
      print('Error: 创建目标目录失败 $e');
      return;
    }
  }

  // 遍历处理每个文件/文件夹
  for (String sourcePath in paths) {
    try {
      // 用typeSync静态方法判断路径是否存在
      FileSystemEntityType entityType = FileSystemEntity.typeSync(sourcePath);
      if (entityType == FileSystemEntityType.notFound) {
        print('Warning: 文件/文件夹不存在 $sourcePath');
        continue;
      }

      // 构建目标文件路径（保留原文件名）
      String fileName = path.basename(sourcePath);
      String targetPath = path.join(destination, fileName);

      // 处理文件已存在的情况（添加序号避免覆盖）
      int counter = 1;
      // 检查目标路径是否存在
      while (FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound) {
        String extension = path.extension(sourcePath);
        String nameWithoutExt = path.basenameWithoutExtension(sourcePath);
        targetPath = path.join(destination, '$nameWithoutExt($counter)$extension');
        counter++;
      }

      // 执行复制/剪切操作
      if (entityType == FileSystemEntityType.directory) {
        // 处理文件夹
        if (isMoving) {
          // 剪切：重命名（移动）文件夹
          Directory(sourcePath).renameSync(targetPath);
        } else {
          // 复制：递归复制整个文件夹
          _copyDirectory(Directory(sourcePath), Directory(targetPath));
        }
      } else if (entityType == FileSystemEntityType.file) {
        // 处理文件
        if (isMoving) {
          // 剪切：重命名（移动）文件
          File(sourcePath).renameSync(targetPath);
        } else {
          // 复制：复制文件
          File(sourcePath).copySync(targetPath);
        }
      }

      print('Success: ${isMoving ? '剪切' : '复制'} $sourcePath 到 $targetPath');
    } catch (e) {
      print('Error: 处理文件 $sourcePath 失败 - $e');
    }
  }
}

/// 递归复制文件夹及其所有内容
void _copyDirectory(Directory source, Directory target) {
  // 检查目标目录是否存在
  if (!target.existsSync()) { // Directory实例调用existsSync
    target.createSync(recursive: true);
  }

  // 遍历源文件夹中的所有实体
  for (var entity in source.listSync()) {
    String targetPath = path.join(target.path, path.basename(entity.path));

    if (entity is Directory) {
      // 递归复制子文件夹
      _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      // 复制文件
      entity.copySync(targetPath);
    }
  }
}