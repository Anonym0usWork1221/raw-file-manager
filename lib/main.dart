import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/secure_folder_page.dart';
import 'pages/storage_analyzer_page.dart';


void main() {
  runApp(const RawFileManagerApp());
}

class RawFileManagerApp extends StatelessWidget {
  const RawFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raw File Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
      routes: {
        '/recycle_bin': (_) => const RecycleBinPage(),
        '/secure_folder': (_) => const SecureFolderPage(),
        '/storage_analyzer': (_) => const StorageAnalyzerPage(),
      },
    );
  }
}