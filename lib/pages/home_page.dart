import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:archive/archive_io.dart' hide ZipFile;
import 'package:open_file/open_file.dart';
import 'package:raw_file_manager/widgets/expressive_refresh.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/file_search_delegate.dart';
import '../services/deletion_service.dart';
import '../utils/file_utils.dart';
import 'file_editor_page.dart';
import 'preview_page.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'text_preview_page.dart';
import 'secure_file_preview_page.dart';
import 'package:raw_file_manager/widgets/widgets.dart';
import 'package:material_shapes/material_shapes.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

enum SortOption {
  type,
  name,
  date,
  size,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const MethodChannel _channel =
      MethodChannel('com.jara.manager.raw_file_manager/apk_install');

  String currentPath = "/storage/emulated/0";
  List<FileSystemEntity> files = [];
  bool isGridView = false;
  SortOption currentSortOption = SortOption.type;
  String searchQuery = '';

  bool _isMultiSelect = false;
  final Set<FileSystemEntity> _selectedFiles = {};
  final Set<FileSystemEntity> _selectedActionFiles = {};

  DateTime? _lastBackPressed;

  int _listAnimationKey = 0;

  bool _isCopying = false;
  bool _isMoving = false;
  late FileSystemEntity _globalTempEntity;

  // Flutter仅负责调用原生方法，传递APK路径
  Future<void> installApk(String apkPath) async {
    try {
      // 第一步：先接收为dynamic，避免直接强转
      final dynamic resultData = await _channel.invokeMethod(
        'installApk',
        {'apkPath': apkPath},
      );

      // 第二步：安全转换为Map<String, dynamic>
      final Map<String, dynamic> result = Map<String, dynamic>.from(resultData);

      // 仅提示结果（无需处理权限，因为已精简）
      if (mounted) {}
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('调用失败：${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('类型转换错误：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _moveOrCopyItem({required bool isMove, FileSystemEntity? entity}) {
    setState(() {
      _isCopying = true;
      _isMoving = isMove;
      if (entity != null) _selectedActionFiles.add(entity);
    });
  }

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
              content:
                  const Text("This app requires access to your images, videos, "
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

      final manageStatus = await Permission.manageExternalStorage.request();
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
      // 首先区分文件夹和文件，文件夹排在前面
      bool aIsDir = a is Directory;
      bool bIsDir = b is Directory;

      if (aIsDir && !bIsDir) {
        return -1; // a是文件夹，b是文件，a排在前面
      } else if (!aIsDir && bIsDir) {
        return 1; // a是文件，b是文件夹，b排在前面
      } else {
        // 同为文件夹或同为文件时，按名称排序（不区分大小写）
        return path
            .basename(a.path)
            .toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase());
      }
    });
    setState(() {
      files = entities;
      _listAnimationKey++;
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

  void _showFileOperationMenu(
      BuildContext context,
      dynamic entity,
      double buttonX, // 按钮的X坐标
      double buttonY // 按钮的Y坐标
      ) {
    // 构建菜单项（完全不变，极简写法）
    List<PopupMenuEntry<String>> menuItems = [
      const PopupMenuItem<String>(
          value: 'copy',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 12),
              Text('Copy')
            ]),
          )),
      const PopupMenuItem<String>(
          value: 'cut',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.cut, size: 20),
              SizedBox(width: 12),
              Text('Cut')
            ]),
          )),
      const PopupMenuItem<String>(
          value: 'rename',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('Rename')
            ]),
          )),
    ];

    if (entity is File &&
        ['.txt', '.md', '.json', '.xml']
            .contains(path.extension(entity.path).toLowerCase())) {
      menuItems.add(const PopupMenuItem<String>(
          value: 'edit_file',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.edit_note, size: 20),
              SizedBox(width: 12),
              Text('Edit File')
            ]),
          )));
    }

    menuItems.addAll([
      const PopupMenuItem<String>(
          value: 'delete',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.delete, size: 20),
              SizedBox(width: 12),
              Text('Delete')
            ]),
          )),
      const PopupMenuItem<String>(
          value: 'share',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 12),
              Text('Share')
            ]),
          )),
      const PopupMenuItem<String>(
          value: 'zip_unzip',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Row(children: [
              Icon(Icons.archive, size: 20),
              SizedBox(width: 12),
              Text('Zip/Unzip')
            ]),
          )),
    ]);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonX + 40,
        buttonY + 40,
        MediaQuery.of(context).size.width - (buttonX + 40),
        MediaQuery.of(context).size.height - (buttonY + 40),
      ),
      items: menuItems,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 400),
        curve: Curves.decelerate,
        reverseCurve: Curves.decelerate,
      ),
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          _moveOrCopyItem(isMove: false, entity: entity);
          break;
        case 'cut':
          _moveOrCopyItem(isMove: true, entity: entity);
          break;
        case 'rename':
          _renameEntity(entity);
          break;
        case 'edit_file':
          _editFileContent(entity);
          break;
        case 'delete':
          _deleteEntity(entity);
          break;
        case 'share':
          _shareEntity(entity);
          break;
        case 'zip_unzip':
          _zipUnzipEntity(entity);
          break;
      }
    });
  }

  void _navigateTo(FileSystemEntity entity) {
    if (_isMultiSelect) {
      _toggleSelection(entity);
      return;
    }
    if (entity is Directory) {
      currentPath = entity.path;
      _listFiles();
    } else {
      _openFile(entity);
    }
  }

  Future<void> _openFile(FileSystemEntity entity) async {
    if (entity is File) {
      String ext = path.extension(entity.path).toLowerCase();
      if (['.txt', '.md', '.json', '.xml'].contains(ext)) {
        if (currentPath.contains("SecureFolder")) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SecureFilePreviewPage(file: entity)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TextPreviewPage(file: entity)),
          );
        }
      } else if ([".apk"].contains(ext)) {
        installApk(entity.path);
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

  void _onLongPress(FileSystemEntity entity, TapDownDetails details) {
    if (_isMultiSelect) {
      _toggleSelection(entity);
      return;
    }

    _showFileOperationMenu(
        context, entity, details.globalPosition.dx, details.globalPosition.dy);
    /*showModalBottomSheet(
      isScrollControlled: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        List<Widget> options = [
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              //_copyEntity(entity);
              _moveOrCopyItem(isMove: false, entity: entity);
            },
          ),
          const SizedBox(
            height: 2,
          ),
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.cut),
            title: const Text('Cut'),
            onTap: () {
              Navigator.pop(context);
              //_moveEntity(entity);
              _moveOrCopyItem(isMove: true, entity: entity);
            },
          ),
          const SizedBox(
            height: 2,
          ),
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameEntity(entity);
            },
          ),
          const SizedBox(
            height: 2,
          ),
        ];
        if (entity is File &&
            ['.txt', '.md', '.json', '.xml']
                .contains(path.extension(entity.path).toLowerCase())) {
          options.addAll([
            ListTile(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4))),
              tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
              leading: const Icon(Icons.edit_note),
              title: const Text('Edit File'),
              onTap: () {
                Navigator.pop(context);
                _editFileContent(entity);
              },
            ),
            const SizedBox(
              height: 2,
            ),
          ]);
        }
        options.addAll([
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteEntity(entity);
            },
          ),
          const SizedBox(
            height: 2,
          ),
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareEntity(entity);
            },
          ),
          const SizedBox(
            height: 2,
          ),
          ListTile(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24))),
            tileColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            leading: const Icon(Icons.archive),
            title: const Text('Zip/Unzip'),
            onTap: () {
              Navigator.pop(context);
              _zipUnzipEntity(entity);
            },
          ),
        ]);
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options,
          ),
        );
      },
    );*/
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
            title: const Text("Delete file(s)"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4))),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  title: const Text("Move to Recycle Bin"),
                  value: false,
                  groupValue: moveOrPermanent,
                  onChanged: (value) {
                    setState(() => moveOrPermanent = value!);
                  },
                ),
                const SizedBox(
                  height: 2,
                ),
                RadioListTile<bool>(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24))),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
              IntrinsicWidth(
                child: ExpressiveOutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
              ),
              IntrinsicWidth(
                child: ExpressiveFilledButton(
                  onPressed: () => Navigator.pop(context, moveOrPermanent),
                  child: const Text("Confirm"),
                ),
              )
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
        String recycleBinPath =
            path.join("/storage/emulated/0", "RawFileManager", "RecycleBin");
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
    List<String> paths = _selectedFiles.map((entity) => entity.path).toList();
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
    String? newName = await _showInputDialog("Rename", "Enter new name:");
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
            subject: "Sharing File", text: "File shared from Raw File Manager");
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
            decoration: const InputDecoration(hintText: "Zip file name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _zipFileOrFolder(FileSystemEntity entity) async {
    // try {
    //   String defaultName = path.basename(entity.path);
    //   String? enteredName = await _askZipName(defaultName);
    //   if (enteredName == null || enteredName.trim().isEmpty) {
    //     enteredName = defaultName;
    //   }
    //   String zipPath = path.join(path.dirname(entity.path), "$enteredName.zip");
    //   var encoder = ZipFileEncoder();
    //   encoder.create(zipPath);
    //   if (entity is File) {
    //     encoder.addFile(entity);
    //   } else if (entity is Directory) {
    //     encoder.addDirectory(entity);
    //   }
    //   encoder.close();
    //   ScaffoldMessenger.of(context)
    //       .showSnackBar(SnackBar(content: Text("Created zip at $zipPath")));
    //   _listFiles();
    // } catch (e) {
    //   print("Error zipping: $e");
    // }

    String defaultName = path.basename(entity.path);
    String? enteredName = await _askZipName(defaultName);
    if (enteredName == null || enteredName.trim().isEmpty) {
      enteredName = defaultName;
    }

    if (entity is File) {
      final dataDir = Directory(entity.parent.path);
      final zipFile = File(path.join(entity.parent.path, "$enteredName.zip"));
      final files = [File(entity.path)];
      try {
        ZipFile.createFromFiles(
            sourceDir: dataDir, files: files, zipFile: zipFile);
      } catch (e) {
        print(e);
      }
    } else if (entity is Directory) {
      final dataDir = Directory(entity.path);
      try {
        final zipFile = File(path.join(entity.path, "$enteredName.zip"));
        await ZipFile.createFromDirectory(
            sourceDir: dataDir, zipFile: zipFile, recurseSubDirs: true);
        _listFiles();
      } catch (e) {
        print(e);
      }
    }
  }

  Future<void> _unzipFile(FileSystemEntity entity) async {
    // try {
    //   if (entity is File) {
    //     String targetDir = entity.parent.path;
    //     List<int> bytes = await entity.readAsBytes();
    //     Archive archive = ZipDecoder().decodeBytes(bytes);
    //     for (var file in archive) {
    //       String filename = path.join(targetDir, file.name);
    //       if (file.isFile) {
    //         File outFile = File(filename);
    //         await outFile.create(recursive: true);
    //         await outFile.writeAsBytes(file.content as List<int>);
    //       } else {
    //         Directory dir = Directory(filename);
    //         await dir.create(recursive: true);
    //       }
    //     }
    //     ScaffoldMessenger.of(context)
    //         .showSnackBar(SnackBar(content: Text("Unzipped to $targetDir")));
    //     _listFiles();
    //   }
    // } catch (e) {
    //   print("Error unzipping: $e");
    // }

    final zipFile = File(entity.path);
    final destinationDir = Directory(entity.parent.path);
    try {
      await ZipFile.extractToDirectory(
          zipFile: zipFile, destinationDir: destinationDir);
      _listFiles();
    } catch (e) {
      print(e);
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
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: hint,
            ),
            onChanged: (value) {
              userInput = value;
            },
          ),
          actions: [
            IntrinsicWidth(
              child: ExpressiveOutlinedButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            IntrinsicWidth(
              child: ExpressiveFilledButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context, userInput),
              ),
            )
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
    String? fileName =
        await _showInputDialog("New File", "Enter file name (with extension):");
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

  // 解析当前路径为层级列表
  List<String> _getPathSegments() {
    List<String> segments = path.split(currentPath);
    // 过滤空字符串（处理路径开头/结尾的分隔符）
    segments = segments.where((s) => s.isNotEmpty).toList();
    return segments;
  }

// 跳转到指定层级的路径
  void _navigateToPathSegment(int index) {
    List<String> segments = _getPathSegments();
    if (index < 0 || index >= segments.length) return;

    // 拼接选中层级的完整路径
    String targetPath = "/" + segments.sublist(0, index + 1).join("/");
    // 特殊处理Android根目录格式
    if (targetPath == "/storage/emulated/0") {
      targetPath = "/storage/emulated/0";
    }

    setState(() {
      currentPath = targetPath;
    });
    _listFiles();
  }

  List<Widget> _buildPathIndicator() {
    List<String> segments = _getPathSegments();
    List<Widget> widgets = [];

    // 处理根目录（第一个层级）
    for (int i = 0; i < segments.length; i++) {
      String segment = segments[i];
      // 特殊显示根目录名称
      String displayName = segment;
      if (i == 0 && segment == "storage") {
        displayName = "Storage";
      } else if (i == 2 && segment == "0") {
        displayName = "Internal Storage";
      }

      // 添加层级文本按钮
      widgets.add(
        InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(128)),
            onTap: () => _navigateToPathSegment(i),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                displayName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
      );

      // 添加分隔符（最后一个层级不显示）
      if (i != segments.length - 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  bool _canSystemPop = false;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      // 判断是否为横屏
      bool isLandscape = orientation == Orientation.landscape;

      return PopScope(
        // 核心：通过 canPop 控制是否允许系统执行默认返回
        // 非根目录时：设为 false，阻止系统返回，优先执行业务逻辑
        // 根目录时：设为 true，允许系统返回（但双击才真退出）
        canPop: _canSystemPop,
        onPopInvoked: (didPop) async {
          if (didPop) return; // 系统已处理，直接返回

          // 1. 非根目录：优先返回上一级目录，阻止系统退回桌面
          if (currentPath != "/storage/emulated/0") {
            setState(() {
              currentPath = Directory(currentPath).parent.path;
            });
            await _listFiles();
            return;
          }

          // 2. 根目录：处理双击退出逻辑
          DateTime now = DateTime.now();
          if (_lastBackPressed == null ||
              now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Press back again to exit the app"),
                duration: Duration(seconds: 2),
              ),
            );
            // 第一次点击：仍阻止系统返回
            setState(() => _canSystemPop = false);
            return;
          }

          // 3. 双击确认退出：允许系统返回
          setState(() => _canSystemPop = true);
          // 主动触发系统返回（退出App）
          Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: isLandscape ? null : const SizedBox(),
            surfaceTintColor: Theme.of(context).colorScheme.surface,
            bottomOpacity: 1,
            bottom: PreferredSize(
              preferredSize: const Size(double.infinity, 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: _buildPathIndicator(),
                  ),
                ),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: !_isMultiSelect
                ? const Text('Files')
                : Text('${_selectedFiles.length} Selected'),
            actions: [
              /*if (!_isMultiSelect)
              IconButton.filledTonal(
                icon: const Icon(Icons.add_box),
                onPressed: _showAddOptions,
              ),*/
              if (!_isMultiSelect)
                IntrinsicHeight(
                  child: ExpressiveFilledButton(
                    child: const Icon(Icons.search),
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: FileSearchDelegate(
                            onSearch: _onSearch, initialFiles: files),
                      );
                    },
                  ),
                ),
              /*if (!_isMultiSelect)
              PopupMenuButton<SortOption>(
                onSelected: _changeSortOption,
                icon: const Icon(Icons.sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: SortOption.name, child: Text("Sort by Name")),
                  const PopupMenuItem(
                      value: SortOption.date, child: Text("Sort by Date")),
                  const PopupMenuItem(
                      value: SortOption.size, child: Text("Sort by Size")),
                  const PopupMenuItem(
                      value: SortOption.type, child: Text("Sort by Type")),
                ],
              ),*/
              if (_isMultiSelect && !_isCopying && !_isMoving) ...[
                const SizedBox(
                  width: 4,
                ),
                IntrinsicHeight(
                  child: ExpressiveFilledButton(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.copy),
                    onPressed: () {
                      setState(() {
                        _isCopying = true;
                        _isMoving = false;
                        _selectedActionFiles.addAll(_selectedFiles);
                        _isMultiSelect = false;
                        _selectedFiles.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                IntrinsicHeight(
                  child: ExpressiveFilledButton(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.cut),
                    onPressed: () {
                      setState(() {
                        _isCopying = true;
                        _isMoving = true;
                        _selectedActionFiles.addAll(_selectedFiles);
                        _isMultiSelect = false;
                        _selectedFiles.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                IntrinsicHeight(
                  child: ExpressiveFilledButton(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.delete),
                    onPressed: () {
                      _deleteSelectedEntities();
                    },
                  ),
                ),
              ],
              const SizedBox(
                width: 4,
              ),
              IntrinsicHeight(
                child: ExpressiveFilledButton(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  onPressed: () {
                    if (_isMultiSelect) {
                      _toggleMultiSelect();
                    } else {
                      setState(() {
                        _isMultiSelect = true;
                      });
                    }
                  },
                  child: Icon(
                    _isMultiSelect ? Icons.clear : Icons.select_all,
                  ),
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              IntrinsicHeight(
                child: ExpressiveFilledButton(
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onTertiaryContainer,
                  child: Icon(isGridView ? Icons.list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      isGridView = !isGridView;
                    });
                  },
                ),
              ),
              const SizedBox(
                width: 16,
              )
            ],
          ),
          body: ExpressiveRefreshIndicator.contained(
            onRefresh: _listFiles,
            child: files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MaterialShapes.fourLeafClover(
                            color: Theme.of(context).colorScheme.primary,
                            size: 96),
                        const SizedBox(
                          height: 4,
                        ),
                        MaterialShapes.circle(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            size: 24),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          "It's empty.",
                          style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(context).colorScheme.inverseSurface),
                        )
                      ],
                    ),
                  )
                : isGridView
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
                            child: Card(
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_getIcon(entity), size: 40),
                                      const SizedBox(height: 8),
                                      Text(
                                        path.basename(entity.path),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
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
                    : AnimationLimiter(
                        key: ValueKey(_listAnimationKey),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 84),
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            FileSystemEntity entity = files[index];
                            bool isSelected = _selectedFiles.contains(entity);

                            // 定义圆角值常量，方便维护
                            const double largeRadius = 24.0;
                            const double smallRadius = 4.0;

                            // 根据索引动态计算圆角
                            BorderRadius borderRadius;
                            if (files.length == 1) {
                              borderRadius = const BorderRadius.all(
                                  Radius.circular(largeRadius));
                            } else {
                              if (index == 0) {
                                borderRadius = const BorderRadius.only(
                                  topLeft: Radius.circular(largeRadius),
                                  topRight: Radius.circular(largeRadius),
                                  bottomLeft: Radius.circular(smallRadius),
                                  bottomRight: Radius.circular(smallRadius),
                                );
                              } else if (index == files.length - 1) {
                                borderRadius = const BorderRadius.only(
                                  topLeft: Radius.circular(smallRadius),
                                  topRight: Radius.circular(smallRadius),
                                  bottomLeft: Radius.circular(largeRadius),
                                  bottomRight: Radius.circular(largeRadius),
                                );
                              } else {
                                borderRadius = const BorderRadius.all(
                                    Radius.circular(smallRadius));
                              }
                            }
                            return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                delay: const Duration(milliseconds: 20),
                                child: SlideAnimation(
                                    verticalOffset: 3.0,
                                    curve: Curves.fastOutSlowIn,
                                    child: FadeInAnimation(
                                        curve: Curves.fastOutSlowIn,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 1,
                                              bottom: 1,
                                              right: 16,
                                              left: 16),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 24.0),
                                            tileColor: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .secondaryContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerLowest,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: isSelected
                                                    ? const BorderRadius.all(
                                                        Radius.circular(128))
                                                    : borderRadius),
                                            leading: _isMultiSelect
                                                ? isSelected
                                                    ? Icon(
                                                        Icons.check_circle,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      )
                                                    : Icon(_getIcon(entity))
                                                : Icon(_getIcon(entity)),
                                            title: Text(
                                                path.basename(entity.path)),
                                            subtitle: Text(entity is File
                                                ? "${(entity.statSync().size / 1024).toStringAsFixed(2)} KB"
                                                : "Folder"),
                                            trailing: _isMultiSelect
                                                ? null
                                                : GestureDetector(
                                                    // 用onTapDown获取点击位置
                                                    onTapDown: (TapDownDetails
                                                        details) {
                                                      // 传点击位置的X/Y给菜单方法
                                                      _showFileOperationMenu(
                                                          context,
                                                          entity,
                                                          details.globalPosition
                                                              .dx, // 点击位置X
                                                          details.globalPosition
                                                              .dy // 点击位置Y
                                                          );
                                                    },
                                                    // 保留原onTap（防止误触）
                                                    onTap: () {},
                                                    child: const Icon(Icons
                                                        .more_vert), // 你的原按钮组件
                                                  ),
                                            onTap: () {
                                              _navigateTo(entity);
                                            },
                                            onLongPress: () {
                                              setState(() {
                                                _isMultiSelect = true;
                                                _toggleSelection(entity);
                                              });
                                            },
                                          ),
                                        ))));
                          },
                        ),
                      ),
          ),
          floatingActionButton: ExpressiveFloatingActionButton(
            defaultIcon: Icons.add,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            actionItems: [
              ActionItem(
                icon: Icons.file_open,
                label: 'File',
                onTap: () {
                  _createNewFile();
                },
              ),
              ActionItem(
                icon: Icons.folder,
                label: 'Folder',
                onTap: () {
                  _createNewFolder();
                },
              ),
            ],
          ),
          persistentFooterButtons: _isCopying
              ? [
                  AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: AnimationController(
                            vsync: this,
                            duration: const Duration(milliseconds: 300),
                          )..forward(),
                          curve: Curves.easeInOut,
                        )),
                        child: Container(
                          height: 72,
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 0),
                            child: Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width - 48 <=
                                        480
                                    ? MediaQuery.of(context).size.width - 48
                                    : 480,
                                height: 72,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10.0,
                                      spreadRadius: 0.0,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 16.0,
                                      spreadRadius: -1.0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(128)),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 54,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(48),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLowest,
                                          ),
                                          child: Center(
                                            child: Text(
                                              "${_selectedActionFiles.length}",
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 1,
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(48),
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(48),
                                            onTap: () {
                                              setState(() {
                                                _isCopying = false;
                                                _isMoving = false;
                                                _selectedActionFiles.clear();
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(48),
                                              ),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(48),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLowest,
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    "Cancel",
                                                    style:
                                                        TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 1,
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(48),
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(48),
                                            onTap: () async {
                                              try {
                                                List<String> selectedPaths =
                                                    _selectedActionFiles
                                                        .map((entity) =>
                                                            entity.path)
                                                        .toList();

                                                await bulkActionFiles(
                                                  selectedPaths,
                                                  _isMoving,
                                                  currentPath,
                                                  onCompleted: (bool isSuccess,
                                                      int fileCount) {
                                                    if (mounted) {
                                                      _listFiles();
                                                    }
                                                  },
                                                );
                                              } catch (e) {
                                                print(e);
                                              }
                                              setState(() {
                                                _isCopying = false;
                                                _isMoving = false;
                                                _selectedActionFiles.clear();
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(48),
                                              ),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(48),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerLowest,
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    "Paste",
                                                    style:
                                                        TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )),
                ]
              : null,
        ),
      );
    });
  }
}
