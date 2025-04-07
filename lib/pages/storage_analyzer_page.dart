import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class StorageAnalyzerPage extends StatefulWidget {
  const StorageAnalyzerPage({super.key});

  @override
  StorageAnalyzerPageState createState() => StorageAnalyzerPageState();
}

class StorageAnalyzerPageState extends State<StorageAnalyzerPage> {
  int totalFiles = 0;
  int totalSize = 0;
  Map<String, int> fileTypeCounts = {};

  @override
  void initState() {
    super.initState();
    _analyzeStorage();
  }

  Future<void> _analyzeStorage() async {
    String rootPath = "/storage/emulated/0";
    Directory rootDir = Directory(rootPath);
    int count = 0;
    int size = 0;
    Map<String, int> types = {};
    try {
      await for (var entity in rootDir.list(recursive: true, followLinks: false)) {
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
    return Scaffold(
      appBar: AppBar(title: const Text("Storage Analyzer")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Files: $totalFiles", style:
              const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Text("Total Size: ${_formatBytes(totalSize, 2)}",
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              const Text("File Type Breakdown:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildChart(),
            ],
          ),
        ),
      ),
    );
  }
}