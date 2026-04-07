import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:raw_file_manager/widgets/widgets.dart';
import 'secure_file_preview_page.dart';
import '../widgets/expressive_refresh.dart';

class SecureFolderPage extends StatefulWidget {
  const SecureFolderPage({super.key});
  @override
  SecureFolderPageState createState() => SecureFolderPageState();
}

class SecureFolderPageState extends State<SecureFolderPage> {
  bool authenticated = false;
  List<FileSystemEntity> secureFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    String? input = await _showPasswordDialog();
    if (input == '1234') {
      setState(() {
        authenticated = true;
      });
      _loadSecureFolder();
    } else {
      if (input != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Incorrect password. Please try again.")));
        _authenticate();
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = "";
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Password"),
          content: TextField(
            decoration: const InputDecoration(border: OutlineInputBorder(), hint: Text("Type your password here...")),
            obscureText: true,
            onChanged: (value) {
              password = value;
            },
          ),
          actions: [
            Row(
              children: [
                
                
                Expanded(
                  flex: 1,
                  child: ExpressiveOutlinedButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 8,),
                Expanded(
                  flex: 1,
                  child: ExpressiveFilledButton(
                      onPressed: () {
                        Navigator.pop(context, password);
                      },
                      child: const Text("Confirm")),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Future<void> _loadSecureFolder() async {
    String securePath =
        path.join("/storage/emulated/0", "RawFileManager", "SecureFolder");
    Directory secureDir = Directory(securePath);
    if (!(await secureDir.exists())) {
      await secureDir.create(recursive: true);
    }
    List<FileSystemEntity> files = await secureDir.list().toList();
    setState(() {
      secureFiles = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!authenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Secure Folder"),
          leading: const SizedBox(),
        ),
        body: Center(
          child: ExpressiveLoadingIndicator(
            contained: false,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      );
    }
    return OrientationBuilder(builder: (context, orientation) {
      // 判断是否为横屏
      bool isLandscape = orientation == Orientation.landscape;

      return Scaffold(
        appBar: AppBar(
          title: const Text("Secure Folder"),
          leading: isLandscape ? null : const SizedBox(),
        ),
        body: ExpressiveRefreshIndicator.contained(
          onRefresh: _loadSecureFolder,
          child: ListView.builder(
            itemCount: secureFiles.length,
            itemBuilder: (context, index) {
              FileSystemEntity entity = secureFiles[index];

              return ListTile(
                leading: Icon(entity is Directory
                    ? Icons.folder
                    : Icons.insert_drive_file),
                title: Text(path.basename(entity.path)),
                onTap: () {
                  // Only navigate if the entity is a file.
                  if (entity is File) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SecureFilePreviewPage(file: entity)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Directories are not supported.")));
                  }
                },
              );
            },
          ),
        ),
      );
    });
  }
}
