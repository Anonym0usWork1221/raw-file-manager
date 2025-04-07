import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/file_search_delegate.dart';
import '../services/deletion_service.dart';
import '../utils/file_utils.dart';
import 'file_editor_page.dart';
import 'preview_page.dart';
import 'text_preview_page.dart';
import 'secure_file_preview_page.dart';

enum SortOption { name, date, size, type }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String currentPath = "/storage/emulated/0";
  List<FileSystemEntity> files = [];
  bool isGridView = false;
  SortOption currentSortOption = SortOption.name;
  String searchQuery = '';

  bool _isMultiSelect = false;
  final Set<FileSystemEntity> _selectedFiles = {};

  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listFiles();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final plugin = DeviceInfoPlugin();
      final androidInfo = await plugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // For Android 13 and above, request media permissions separately.
        final imageStatus = await Permission.photos.request();
        final videoStatus = await Permission.videos.request();
        final audioStatus = await Permission.audio.request();

        if (imageStatus.isDenied ||
            videoStatus.isDenied ||
            audioStatus.isDenied) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Media Permissions Required"),
              content: const Text(
                  "This app requires access to your images, videos, "
                      "and audio files. Please grant these permissions."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _requestPermissions(); // Re-request permissions.
                  },
                  child: const Text("Retry"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          );
          return;
        }
      } else {
        // For Android below 33, request storage permission.
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isDenied) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Storage Permission Required"),
              content: const Text("Storage permission is needed to access "
                  "files. Please grant the permission."),
              actions: [
                TextButton(
                  child: const Text("Retry"),
                  onPressed: () {
                    Navigator.pop(context);
                    _requestPermissions();
                  },
                ),
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
          return;
        }
      }

      final manageStatus =
      await Permission.manageExternalStorage.request();
      if (manageStatus.isDenied) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Manage Storage Permission Required"),
            content: const Text("This app requires permission to manage all"
                " files. Please grant this permission."),
            actions: [
              TextButton(
                child: const Text("Retry"),
                onPressed: () {
                  Navigator.pop(context);
                  _requestPermissions();
                },
              ),
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return;
      }
      if (manageStatus.isPermanentlyDenied) {
        openAppSettings();
        return;
      }
    }
  }

  Future<void> _listFiles() async {
    List<FileSystemEntity> entities = [];
    try {
      Directory dir = Directory(currentPath);
      entities = await dir.list().toList();
    } catch (e) {
      print("Error listing files: $e");
      // If in a restricted top-level folder, prompt for subfolder selection.
      if (currentPath.endsWith("/Android/data") ||
          currentPath.endsWith("/Android/obb")) {
        await _promptForSubFolderSelection();
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cannot access $currentPath. Check permissions."),
          ),
        );
      }
      return;
    }
    if (searchQuery.isNotEmpty) {
      entities = entities
          .where((entity) => path
          .basename(entity.path)
          .toLowerCase()
          .contains(searchQuery.toLowerCase()))
          .toList();
    }
    entities.sort((a, b) {
      switch (currentSortOption) {
        case SortOption.name:
          return path.basename(a.path).toLowerCase().compareTo(
              path.basename(b.path).toLowerCase());
        case SortOption.date:
          return a.statSync().modified.compareTo(b.statSync().modified);
        case SortOption.size:
          int aSize = a is File ? a.statSync().size : 0;
          int bSize = b is File ? b.statSync().size : 0;
          return aSize.compareTo(bSize);
        case SortOption.type:
          return path.extension(a.path).compareTo(path.extension(b.path));
        default:
          return 0;
      }
    });
    setState(() {
      files = entities;
    });
  }

  Future<void> _promptForSubFolderSelection() async {
    bool proceed = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Restricted Folder"),
          content: const Text(
              "Direct access to the Android/data (or obb) folder is restricted"
                  " by the system. Please select the specific subfolder for "
                  "the app you want to access (e.g., com.tencent.ig)."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Select Folder"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
    if (proceed) {
      await _pickFolder();
    }
  }

  Future<void> _pickFolder() async {
    // Used when navigating to a restricted folder.
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select a folder",
    );
    if (selectedDirectory != null) {
      setState(() {
        currentPath = selectedDirectory;
      });
      _listFiles();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Folder selection cancelled")),
      );
    }
  }

  Future<String?> _selectDestinationFolder(String action) async {
    // Opens the file-picker UI for the user to select a destination folder.
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select destination folder for $action",
    );
  }

  void _navigateTo(FileSystemEntity entity) {
    if (_isMultiSelect) {
      _toggleSelection(entity);
      return;
    }
    if (entity is Directory) {
      setState(() {
        currentPath = entity.path;
      });
      _listFiles();
    } else {
      _openFile(entity);
    }
  }

  Future<void> _openFile(FileSystemEntity entity) async {
    if (entity is File) {
      String ext = path.extension(entity.path).toLowerCase();
      if (['.jpg', '.png', '.jpeg', '.gif', '.bmp'].contains(ext)) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PreviewPage(file: entity)),
        );
      } else if (['.txt', '.md', '.json', '.xml'].contains(ext)) {
        if (currentPath.contains("SecureFolder")) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SecureFilePreviewPage(file: entity)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TextPreviewPage(file: entity)),
          );
        }
      } else {
        OpenFile.open(entity.path);
      }
    }
  }

  IconData _getIcon(FileSystemEntity entity) {
    if (entity is Directory) return Icons.folder;
    String ext = path.extension(entity.path).toLowerCase();
    if (['.jpg', '.png', '.jpeg', '.gif', '.bmp'].contains(ext)) {
      return Icons.image;
    }
    if (['.mp4', '.avi', '.mov'].contains(ext)) {
      return Icons.movie;
    }
    if (['.mp3', '.wav'].contains(ext)) {
      return Icons.audiotrack;
    }
    if (ext == '.pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  void _onLongPress(FileSystemEntity entity) {
    if (_isMultiSelect) {
      _toggleSelection(entity);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        List<Widget> options = [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              _copyEntity(entity);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: const Text('Move'),
            onTap: () {
              Navigator.pop(context);
              _moveEntity(entity);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameEntity(entity);
            },
          ),
        ];
        if (entity is File &&
            ['.txt', '.md', '.json', '.xml']
                .contains(path.extension(entity.path).toLowerCase())) {
          options.add(
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit File'),
              onTap: () {
                Navigator.pop(context);
                _editFileContent(entity);
              },
            ),
          );
        }
        options.addAll([
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteEntity(entity);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareEntity(entity);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Zip/Unzip'),
            onTap: () {
              Navigator.pop(context);
              _zipUnzipEntity(entity);
            },
          ),
        ]);
        return Wrap(children: options);
      },
    );
  }

  void _toggleSelection(FileSystemEntity entity) {
    setState(() {
      if (_selectedFiles.contains(entity)) {
        _selectedFiles.remove(entity);
      } else {
        _selectedFiles.add(entity);
      }
    });
  }

  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelect = !_isMultiSelect;
      _selectedFiles.clear();
    });
  }

  Future<bool?> _showDeletionConfirmation() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool moveOrPermanent = false; // false: move to bin, true: permanent
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Confirm Deletion"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Delete file(s)"),
                RadioListTile<bool>(
                  title: const Text("Move to Recycle Bin"),
                  value: false,
                  groupValue: moveOrPermanent,
                  onChanged: (value) {
                    setState(() => moveOrPermanent = value!);
                  },
                ),
                RadioListTile<bool>(
                  title: const Text("Delete Permanently"),
                  value: true,
                  groupValue: moveOrPermanent,
                  onChanged: (value) {
                    setState(() => moveOrPermanent = value!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, moveOrPermanent),
                child: const Text("Yes"),
              ),
            ],
          );
        });
      },
    );
    return confirmed;
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    bool? permanent = await _showDeletionConfirmation();
    if (permanent == null) return;
    try {
      if (permanent) {
        if (FileSystemEntity.typeSync(entity.path) ==
            FileSystemEntityType.directory) {
          await Directory(entity.path).delete(recursive: true);
        } else {
          await File(entity.path).delete();
        }
      } else {
        String recycleBinPath = path.join(
            "/storage/emulated/0", "RawFileManager", "RecycleBin");
        Directory recycleDir = Directory(recycleBinPath);
        if (!(await recycleDir.exists())) {
          await recycleDir.create(recursive: true);
        }
        String newPath = path.join(recycleBinPath, path.basename(entity.path));
        await entity.rename(newPath);
      }
      _listFiles();
    } catch (e) {
      print("Error deleting: $e");
    }
  }

  Future<void> _deleteSelectedEntities() async {
    if (_selectedFiles.isEmpty) return;
    bool? permanent = await _showDeletionConfirmation();
    if (permanent == null) return;
    List<String> paths =
    _selectedFiles.map((entity) => entity.path).toList();
    await bulkDeleteFiles(paths, permanent);
    _toggleMultiSelect();
    _listFiles();
  }

  Future<void> _copyEntity(FileSystemEntity entity) async {
    String? destination = await _selectDestinationFolder("copy");
    if (destination != null && destination.isNotEmpty) {
      try {
        if (entity is File) {
          String newPath = path.join(destination, path.basename(entity.path));
          await entity.copy(newPath);
        } else if (entity is Directory) {
          copyDirectory(entity, Directory(destination));
        }
        _listFiles();
      } catch (e) {
        print("Error copying: $e");
      }
    }
  }

  Future<void> _moveEntity(FileSystemEntity entity) async {
    String? destination = await _selectDestinationFolder("move");
    if (destination != null && destination.isNotEmpty) {
      try {
        String newPath = path.join(destination, path.basename(entity.path));
        await entity.rename(newPath);
        _listFiles();
      } catch (e) {
        print("Error moving: $e");
      }
    }
  }

  Future<void> _renameEntity(FileSystemEntity entity) async {
    String? newName =
    await _showInputDialog("Rename", "Enter new name:");
    if (newName != null && newName.isNotEmpty) {
      try {
        String newPath = path.join(path.dirname(entity.path), newName);
        await entity.rename(newPath);
        _listFiles();
      } catch (e) {
        print("Error renaming: $e");
      }
    }
  }

  Future<void> _shareEntity(FileSystemEntity entity) async {
    try {
      if (entity is File) {
        XFile xfile = XFile(entity.path);
        await Share.shareXFiles([xfile],
            subject: "Sharing File",
            text: "File shared from Raw File Manager");
      }
    } catch (e) {
      print("Error sharing file: $e");
    }
  }

  Future<void> _zipUnzipEntity(FileSystemEntity entity) async {
    String ext = path.extension(entity.path).toLowerCase();
    if (ext == '.zip') {
      _unzipFile(entity);
    } else {
      _zipFileOrFolder(entity);
    }
  }

  Future<String?> _askZipName(String defaultName) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller =
        TextEditingController(text: defaultName);
        return AlertDialog(
          title: const Text("Enter zip file name"),
          content: TextField(
            controller: controller,
            decoration:
            const InputDecoration(hintText: "Zip file name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _zipFileOrFolder(FileSystemEntity entity) async {
    try {
      String defaultName = path.basename(entity.path);
      String? enteredName = await _askZipName(defaultName);
      if (enteredName == null || enteredName.trim().isEmpty) {
        enteredName = defaultName;
      }
      String zipPath =
      path.join(path.dirname(entity.path), "$enteredName.zip");
      var encoder = ZipFileEncoder();
      encoder.create(zipPath);
      if (entity is File) {
        encoder.addFile(entity);
      } else if (entity is Directory) {
        encoder.addDirectory(entity);
      }
      encoder.close();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Created zip at $zipPath")));
      _listFiles();
    } catch (e) {
      print("Error zipping: $e");
    }
  }

  Future<void> _unzipFile(FileSystemEntity entity) async {
    try {
      if (entity is File) {
        String targetDir = entity.parent.path;
        List<int> bytes = await entity.readAsBytes();
        Archive archive = ZipDecoder().decodeBytes(bytes);
        for (var file in archive) {
          String filename = path.join(targetDir, file.name);
          if (file.isFile) {
            File outFile = File(filename);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            Directory dir = Directory(filename);
            await dir.create(recursive: true);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Unzipped to $targetDir")));
        _listFiles();
      }
    } catch (e) {
      print("Error unzipping: $e");
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    String userInput = "";
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            decoration: InputDecoration(hintText: hint),
            onChanged: (value) {
              userInput = value;
            },
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context, userInput),
            ),
          ],
        );
      },
    );
  }

  void _onSearch(String query) {
    setState(() {
      searchQuery = query;
    });
    _listFiles();
  }

  void _changeSortOption(SortOption? option) {
    if (option != null) {
      setState(() {
        currentSortOption = option;
      });
      _listFiles();
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text("New File"),
              onTap: () {
                Navigator.pop(context);
                _createNewFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text("New Folder"),
              onTap: () {
                Navigator.pop(context);
                _createNewFolder();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewFile() async {
    String? fileName = await _showInputDialog(
        "New File", "Enter file name (with extension):");
    if (fileName != null && fileName.isNotEmpty) {
      try {
        String newPath = path.join(currentPath, fileName);
        File newFile = File(newPath);
        await newFile.create();
        await newFile.writeAsString("");
        _listFiles();
      } catch (e) {
        print("Error creating file: $e");
      }
    }
  }

  Future<void> _createNewFolder() async {
    String? folderName =
    await _showInputDialog("New Folder", "Enter folder name:");
    if (folderName != null && folderName.isNotEmpty) {
      try {
        String newPath = path.join(currentPath, folderName);
        Directory newFolder = Directory(newPath);
        if (!(await newFolder.exists())) {
          await newFolder.create();
        }
        _listFiles();
      } catch (e) {
        print("Error creating folder: $e");
      }
    }
  }

  void _editFileContent(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FileEditorPage(file: file)),
    ).then((_) {
      _listFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If not at the starting path, navigate to the parent directory.
        if (currentPath != "/storage/emulated/0") {
          setState(() {
            currentPath = Directory(currentPath).parent.path;
          });
          _listFiles();
          return false;
        }
        // If at the starting path, require a double-tap back to exit.
        DateTime now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Press back again to exit the app")),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: !_isMultiSelect
              ? const Text('Raw File Manager')
              : Text('${_selectedFiles.length} Selected'),
          actions: [
            if (!_isMultiSelect)
              IconButton(
                icon: const Icon(Icons.add_box),
                onPressed: _showAddOptions,
              ),
            if (!_isMultiSelect)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: FileSearchDelegate(
                        onSearch: _onSearch, initialFiles: files),
                  );
                },
              ),
            if (!_isMultiSelect)
              PopupMenuButton<SortOption>(
                onSelected: _changeSortOption,
                icon: const Icon(Icons.sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: SortOption.name,
                      child: Text("Sort by Name")),
                  const PopupMenuItem(
                      value: SortOption.date,
                      child: Text("Sort by Date")),
                  const PopupMenuItem(
                      value: SortOption.size,
                      child: Text("Sort by Size")),
                  const PopupMenuItem(
                      value: SortOption.type,
                      child: Text("Sort by Type")),
                ],
              ),
            IconButton(
              icon: Icon(_isMultiSelect ? Icons.clear : Icons.select_all),
              onPressed: () {
                if (_isMultiSelect) {
                  _toggleMultiSelect();
                } else {
                  setState(() {
                    _isMultiSelect = true;
                  });
                }
              },
            ),
            IconButton(
              icon: Icon(isGridView ? Icons.list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  isGridView = !isGridView;
                });
              },
            )
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Center(
                  child: Text("Raw File Manager",
                      style: TextStyle(fontSize: 24)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text("Home"),
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Recycle Bin"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/recycle_bin');
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text("Secure Folder"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/secure_folder');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pie_chart),
                title: const Text("Storage Analyzer"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/storage_analyzer');
                },
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _listFiles,
          child: isGridView
              ? GridView.builder(
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3),
            itemCount: files.length,
            itemBuilder: (context, index) {
              FileSystemEntity entity = files[index];
              bool isSelected = _selectedFiles.contains(entity);
              return GestureDetector(
                onTap: () => _navigateTo(entity),
                onLongPress: () => _onLongPress(entity),
                child: Card(
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(_getIcon(entity), size: 40),
                          const SizedBox(height: 8),
                          Text(
                            path.basename(entity.path),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style:
                            const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      if (_isMultiSelect)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: Colors.teal,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          )
              : ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              FileSystemEntity entity = files[index];
              bool isSelected = _selectedFiles.contains(entity);
              return ListTile(
                leading: _isMultiSelect
                    ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(entity),
                )
                    : Icon(_getIcon(entity)),
                title: Text(path.basename(entity.path)),
                subtitle: Text(entity is File
                    ? "${(entity.statSync().size / 1024).toStringAsFixed(2)} KB"
                    : "Folder"),
                trailing: entity is File
                    ? Text("${entity.statSync().modified}")
                    : null,
                onTap: () => _navigateTo(entity),
                onLongPress: () => _onLongPress(entity),
              );
            },
          ),
        ),
        floatingActionButton: _isMultiSelect
            ? FloatingActionButton(
          onPressed: _deleteSelectedEntities,
          child: const Icon(Icons.delete),
        )
            : currentPath != "/storage/emulated/0"
            ? FloatingActionButton(
          child: const Icon(Icons.arrow_upward),
          onPressed: () {
            setState(() {
              currentPath =
                  Directory(currentPath).parent.path;
            });
            _listFiles();
          },
        )
            : null,
      ),
    );
  }
}