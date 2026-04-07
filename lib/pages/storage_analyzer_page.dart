import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart'; // 新增：用于获取存储信息

class StorageAnalyzerPage extends StatefulWidget {
  const StorageAnalyzerPage({super.key});

  @override
  StorageAnalyzerPageState createState() => StorageAnalyzerPageState();
}

class StorageAnalyzerPageState extends State<StorageAnalyzerPage> {
  int totalFiles = 0;
  int totalSize = 0;
  Map<String, int> fileTypeCounts = {};
  // 新增：存储相关变量
  int? totalStorageSize; // 总存储容量（字节）
  int? usedStorageSize; // 已使用存储容量（字节）
  double storageUsagePercentage = 0.0; // 存储占用百分比

  @override
  void initState() {
    super.initState();
    // 先获取存储信息，再分析文件
    _getStorageInfo();
    _analyzeStorage();
  }

  // 新增：获取设备存储总容量和已用容量
  Future<void> _getStorageInfo() async {
    try {
      // 获取外部存储目录（Android）
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // 执行系统命令获取存储信息（Android专属）
        ProcessResult result = await Process.run(
          'df',
          [externalDir.path], // 指定要查询的目录路径
        );

        if (result.exitCode == 0) {
          String output = result.stdout.toString();
          // 解析df命令输出，提取总容量和已用容量
          List<String> lines = output.split('\n');
          if (lines.length > 1) {
            List<String> parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length >= 5) {
              // df命令返回的单位是块，需要转换为字节（通常1块=1024字节）
              int blockSize = 1024;
              // 已用块数 * 块大小 = 已用字节
              usedStorageSize = int.parse(parts[2]) * blockSize;
              // 总块数 * 块大小 = 总字节
              totalStorageSize = int.parse(parts[1]) * blockSize;

              // 计算占用百分比（0-1之间）
              if (totalStorageSize! > 0) {
                storageUsagePercentage = usedStorageSize! / totalStorageSize!;
              }
            }
          }
        }
      }
    } catch (e) {
      print("获取存储信息失败: $e");
      storageUsagePercentage = 0.0; // 异常时设为0
    }

    // 更新UI
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _analyzeStorage() async {
    String rootPath = "/storage/emulated/0";
    Directory rootDir = Directory(rootPath);
    int count = 0;
    int size = 0;
    Map<String, int> types = {};
    try {
      await for (var entity
          in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          count++;
          int fileSize = await entity.length();
          size += fileSize;
          String ext = path.extension(entity.path).toLowerCase();
          types[ext] = (types[ext] ?? 0) + 1;
        }
      }
    } catch (e) {
      print("Error during storage scan: $e");
    }
    setState(() {
      totalFiles = count;
      totalSize = size;
      fileTypeCounts = types;
    });
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (math.log(bytes) / math.log(1024)).floor();
    // 防止索引越界
    i = math.min(i, suffixes.length - 1);
    String value = (bytes / math.pow(1024, i)).toStringAsFixed(decimals);
    return "$value ${suffixes[i]}";
  }

  Widget _buildChart() {
    int maxCount = fileTypeCounts.values.isNotEmpty
        ? fileTypeCounts.values.reduce(math.max)
        : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fileTypeCounts.entries.map((entry) {
        double percentage = entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  entry.key.isEmpty ? "None" : entry.key,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey,
                  color: Colors.teal,
                  minHeight: 10,
                ),
              ),
              const SizedBox(width: 8),
              Text("${entry.value}"),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      bool isLandscape = orientation == Orientation.landscape;

      return Scaffold(
        appBar: AppBar(
          title: const Text("Storage Analyzer"),
          leading: isLandscape ? null : const SizedBox(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 修改：使用计算出的存储占用百分比作为进度值
                SizedBox(
                  width: 128,
                  height: 128,
                  child: CircularProgressIndicator(
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    value: storageUsagePercentage,
                    strokeWidth: 12,
                    //year2023: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Storage Usage: ${(storageUsagePercentage * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  "Used: ${_formatBytes(usedStorageSize ?? 0, 2)} / Total: ${_formatBytes(totalStorageSize ?? 0, 2)}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),

                /*const SizedBox(height: 16),
                Text("Total Files: $totalFiles",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                Text("Scanned Files Size: ${_formatBytes(totalSize, 2)}",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                const Text("File Type Breakdown:",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),*/
                //_buildChart(),
              ],
            ),
          ),
        ),
      );
    });
  }
}
