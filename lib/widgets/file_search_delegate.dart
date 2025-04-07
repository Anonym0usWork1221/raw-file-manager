import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class FileSearchDelegate extends SearchDelegate {
  final Function(String) onSearch;
  final List<FileSystemEntity> initialFiles;
  FileSearchDelegate({required this.onSearch, required this.initialFiles});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = "";
            onSearch(query);
          })
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          close(context, null);
        });
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    return Center(
      child: Text("Searching for \"$query\""),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    List<FileSystemEntity> suggestions = initialFiles
        .where((entity) =>
        path.basename(entity.path).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        FileSystemEntity entity = suggestions[index];
        return ListTile(
          leading: Icon(entity is Directory ? Icons.folder : Icons.insert_drive_file),
          title: Text(path.basename(entity.path)),
          onTap: () {
            close(context, null);
          },
        );
      },
    );
  }
}