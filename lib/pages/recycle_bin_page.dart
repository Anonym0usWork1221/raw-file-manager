import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/deletion_service.dart';

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  RecycleBinPageState createState() => RecycleBinPageState();
}

class RecycleBinPageState extends State<RecycleBinPage> {
  List<FileSystemEntity> binFiles = [];
  bool _isMultiSelect = false;
  final Set<FileSystemEntity> _selectedBinFiles = {};

  @override
  void initState() {
    super.initState();
    _loadRecycleBin();
  }

  Future<void> _loadRecycleBin() async {
    String binPath = path.join("/storage/emulated/0",
        "RawFileManager", "RecycleBin");
    Directory binDir = Directory(binPath);
    if (await binDir.exists()) {
      List<FileSystemEntity> files = await binDir.list().toList();
      setState(() {
        binFiles = files;
      });
    }
  }

  void _toggleBinSelection(FileSystemEntity entity) {
    setState(() {
      if (_selectedBinFiles.contains(entity)) {
        _selectedBinFiles.remove(entity);
      } else {
        _selectedBinFiles.add(entity);
      }
    });
  }

  Future<void> _restoreEntity(FileSystemEntity entity) async {
    String destination = "/storage/emulated/0";
    String newPath = path.join(destination, path.basename(entity.path));
    await entity.rename(newPath);
    _loadRecycleBin();
  }

  Future<void> _deleteSelectedEntities() async {
    if (_selectedBinFiles.isEmpty) return;
    List<String> paths =
    _selectedBinFiles.map((entity) => entity.path).toList();
    await bulkDeleteFiles(paths, true);
    setState(() {
      _selectedBinFiles.clear();
    });
    _loadRecycleBin();
  }

  Future<void> _deleteAllEntities() async {
    List<String> paths = binFiles.map((entity) => entity.path).toList();
    await bulkDeleteFiles(paths, true);
    _loadRecycleBin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isMultiSelect
            ? const Text("Recycle Bin")
            : Text("${_selectedBinFiles.length} Selected"),
        actions: [
          if (!_isMultiSelect)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () => _deleteAllEntities(),
            ),
          IconButton(
            icon: Icon(_isMultiSelect ? Icons.clear : Icons.select_all),
            onPressed: () {
              setState(() {
                _isMultiSelect = !_isMultiSelect;
                _selectedBinFiles.clear();
              });
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecycleBin,
        child: ListView.builder(
            itemCount: binFiles.length,
            itemBuilder: (context, index) {
              FileSystemEntity entity = binFiles[index];
              bool isSelected = _selectedBinFiles.contains(entity);
              return ListTile(
                leading: _isMultiSelect
                    ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleBinSelection(entity),
                )
                    : Icon(entity is Directory
                    ? Icons.folder
                    : Icons.insert_drive_file),
                title: Text(path.basename(entity.path)),
                trailing: _isMultiSelect
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () async {
                    await _restoreEntity(entity);
                  },
                ),
                onTap: () {
                  if (_isMultiSelect) {
                    _toggleBinSelection(entity);
                  }
                },
                onLongPress: () {
                  if (!_isMultiSelect) {
                    _toggleBinSelection(entity);
                    setState(() {
                      _isMultiSelect = true;
                    });
                  }
                },
              );
            }),
      ),
      floatingActionButton: _isMultiSelect
          ? FloatingActionButton(
        onPressed: _deleteSelectedEntities,
        child: const Icon(Icons.delete),
      )
          : null,
    );
  }
}