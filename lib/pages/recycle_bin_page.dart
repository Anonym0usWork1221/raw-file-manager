import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/deletion_service.dart';
import '../widgets/widgets.dart';
import '../widgets/expressive_refresh.dart';

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
    String binPath =
        path.join("/storage/emulated/0", "RawFileManager", "RecycleBin");
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
    return OrientationBuilder(builder: (context, orientation) {
      // 判断是否为横屏
      bool isLandscape = orientation == Orientation.landscape;

      return Scaffold(
        appBar: AppBar(
          leading: isLandscape ? null : const SizedBox(),
          title: !_isMultiSelect
              ? const Text("Recycle Bin")
              : Text("${_selectedBinFiles.length} Selected"),
          actions: [
            if (!_isMultiSelect)
              IntrinsicHeight(
                child: ExpressiveFilledButton(
                  child: const Icon(Icons.delete_forever),
                  onPressed: () => _deleteAllEntities(),
                ),
              ),
            const SizedBox(
              width: 4,
            ),
            IntrinsicHeight(
              child: ExpressiveFilledButton(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: Icon(_isMultiSelect ? Icons.clear : Icons.select_all),
                onPressed: () {
                  setState(() {
                    _isMultiSelect = !_isMultiSelect;
                    _selectedBinFiles.clear();
                  });
                },
              ),
            ),
            const SizedBox(
              width: 16,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ExpressiveRefreshIndicator(
            onRefresh: _loadRecycleBin,
            child: ListView.builder(
                itemCount: binFiles.length,
                itemBuilder: (context, index) {
                  FileSystemEntity entity = binFiles[index];
                  bool isSelected = _selectedBinFiles.contains(entity);
                  // 定义圆角值常量，方便维护
                  const double largeRadius = 24.0;
                  const double smallRadius = 4.0;

                  // 根据索引动态计算圆角
                  BorderRadius borderRadius;
                  if (binFiles.length == 1) {
                    borderRadius =
                        const BorderRadius.all(Radius.circular(largeRadius));
                  } else {
                    if (index == 0) {
                      borderRadius = const BorderRadius.only(
                        topLeft: Radius.circular(largeRadius),
                        topRight: Radius.circular(largeRadius),
                        bottomLeft: Radius.circular(smallRadius),
                        bottomRight: Radius.circular(smallRadius),
                      );
                    } else if (index == binFiles.length - 1) {
                      borderRadius = const BorderRadius.only(
                        topLeft: Radius.circular(smallRadius),
                        topRight: Radius.circular(smallRadius),
                        bottomLeft: Radius.circular(largeRadius),
                        bottomRight: Radius.circular(largeRadius),
                      );
                    } else {
                      borderRadius =
                          const BorderRadius.all(Radius.circular(smallRadius));
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.all(1),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: borderRadius),
                      tileColor:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
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
                          : IconButton.filledTonal(
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
                    ),
                  );
                }),
          ),
        ),
        floatingActionButton: _isMultiSelect
            ? FloatingActionButton(
                onPressed: _deleteSelectedEntities,
                child: const Icon(Icons.delete),
              )
            : null,
      );
    });
  }
}
