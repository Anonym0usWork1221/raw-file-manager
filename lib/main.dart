import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/home_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/secure_folder_page.dart';
import 'pages/storage_analyzer_page.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'widgets/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RawFileManagerApp());
}

// 从 StatelessWidget 转换为 StatefulWidget
class RawFileManagerApp extends StatefulWidget {
  const RawFileManagerApp({super.key});

  @override
  State<RawFileManagerApp> createState() => _RawFileManagerAppState();
}

class _RawFileManagerAppState extends State<RawFileManagerApp> {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // 定义亮色和暗色主题色板
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // 使用系统动态颜色
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Color(lightDynamic.primary.toARGB32()),
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Color(darkDynamic.primary.toARGB32()),
            brightness: Brightness.dark,
          );
        } else {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );
        }

        return AnnotatedRegion(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor:
                Theme.brightnessOf(context) == Brightness.light
                    ? lightColorScheme.surface
                    : darkColorScheme.surface,
            systemNavigationBarIconBrightness:
                Theme.brightnessOf(context) == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
          ),
          child: MaterialApp(
            title: 'Raw File Manager',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  // Set the predictive back transitions for Android.
                  TargetPlatform.android:
                      PredictiveBackPageTransitionsBuilder(),
                },
              ),
              colorScheme: lightColorScheme,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  // Set the predictive back transitions for Android.
                  TargetPlatform.android:
                      PredictiveBackPageTransitionsBuilder(),
                },
              ),
              colorScheme: darkColorScheme,
              useMaterial3: true,
            ),
            // 使用系统默认的主题模式（跟随系统）
            themeMode: ThemeMode.system,
            home: const NavigatorHome(),
            routes: {
              '/recycle_bin': (_) => const RecycleBinPage(),
              '/secure_folder': (_) => const SecureFolderPage(),
              '/storage_analyzer': (_) => const StorageAnalyzerPage(),
            },
          ),
        );
      },
    );
  }
}

class NavigatorHome extends StatefulWidget {
  const NavigatorHome({super.key});

  @override
  State<NavigatorHome> createState() => _NavigatorHomeState();
}

class _NavigatorHomeState extends State<NavigatorHome> {
  int _pageIndex = 0;
  final List<Widget> _pages = const [
    HomePage(),
    RecycleBinPage(),
    SecureFolderPage(),
    StorageAnalyzerPage(),
    SettingsPage()
  ];

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      // 判断是否为横屏
      bool isLandscape = orientation == Orientation.landscape;

      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isLandscape)
            Expanded(
              flex: 1,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      const DrawerHeader(
                        child: Text(
                          "Raw File Manager",
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                      ListTile(
                        tileColor: _pageIndex == 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        leading: const Icon(Icons.home),
                        title: const Text("Home"),
                        onTap: () => setState(() => _pageIndex = 0),
                      ),
                      ListTile(
                        tileColor: _pageIndex == 1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        leading: const Icon(Icons.delete),
                        title: const Text("Recycle Bin"),
                        onTap: () => setState(() => _pageIndex = 1),
                      ),
                      ListTile(
                        tileColor: _pageIndex == 2
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        leading: const Icon(Icons.lock),
                        title: const Text("Secure Folder"),
                        onTap: () => setState(() => _pageIndex = 2),
                      ),
                      ListTile(
                        tileColor: _pageIndex == 3
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        leading: const Icon(Icons.pie_chart),
                        title: const Text("Storage Analyzer"),
                        onTap: () => setState(() => _pageIndex = 3),
                      ),
                      ListTile(
                        tileColor: _pageIndex == 4
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        leading: const Icon(Icons.settings),
                        title: const Text("Settings"),
                        onTap: () => setState(() => _pageIndex = 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Scaffold(
              drawerEdgeDragWidth: 0,
              drawer: isLandscape
                  ? null
                  : Drawer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            const DrawerHeader(
                              child: Text(
                                "Raw File Manager",
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            ListTile(
                              tileColor: _pageIndex == 0
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(128)),
                              ),
                              leading: const Icon(Icons.home),
                              title: const Text("Home"),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _pageIndex = 0);
                              },
                            ),
                            ListTile(
                              tileColor: _pageIndex == 1
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(128)),
                              ),
                              leading: const Icon(Icons.delete),
                              title: const Text("Recycle Bin"),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _pageIndex = 1);
                              },
                            ),
                            ListTile(
                              tileColor: _pageIndex == 2
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(128)),
                              ),
                              leading: const Icon(Icons.lock),
                              title: const Text("Secure Folder"),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _pageIndex = 2);
                              },
                            ),
                            ListTile(
                              tileColor: _pageIndex == 3
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(128)),
                              ),
                              leading: const Icon(Icons.pie_chart),
                              title: const Text("Storage Analyzer"),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _pageIndex = 3);
                              },
                            ),
                            ListTile(
                              tileColor: _pageIndex == 4
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(128)),
                              ),
                              leading: const Icon(Icons.settings),
                              title: const Text("Settings"),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _pageIndex = 4);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              body: _pages[_pageIndex],
              floatingActionButton: isLandscape
                  ? null
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 2),
                        DrawerButton(),
                      ],
                    ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.startTop,
            ),
          ),
        ],
      );
    });
  }
}

enum AppThemeMode { day, night, followSystem }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 滚动控制器，用于监听滚动偏移
  final ScrollController _scrollController = ScrollController();
  // 折叠进度（0=完全展开，1=完全折叠）
  double _collapseProgress = 0.0;
  // SliverAppBar展开高度
  final double _expandedHeight = 120.0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听回调
  void _onScroll() {
    // 计算滚动偏移量（相对于SliverAppBar的展开高度）
    double offset = _scrollController.offset;
    // 计算折叠进度（0~1）
    double progress = offset / (_expandedHeight - kToolbarHeight);
    // 限制进度在0~1之间
    _collapseProgress = progress.clamp(0.0, 1.0);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;

    AppThemeMode _selectedThemeMode = AppThemeMode.followSystem;

    return OrientationBuilder(builder: (context, orientation) {
      bool isLandscape = orientation == Orientation.landscape;
      bool hasLeading = !isLandscape;

      double titleLeftPaddingCollapsed = isLandscape ? 16 : 72;

      // 动态计算标题left padding：
      // 未滚动（0）→ 16，完全折叠（1）→ 72
      double titleLeftPadding =
          16 + (titleLeftPaddingCollapsed - 16) * _collapseProgress;

      return Scaffold(
        body: CustomScrollView(
          controller: _scrollController, // 绑定滚动控制器
          slivers: [
            SliverAppBar(
              expandedHeight: _expandedHeight,
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: surfaceColor,
              elevation: 0,
              //leading: hasLeading ? const DrawerButton() : null,
              titleSpacing: 0,
              collapsedHeight: kToolbarHeight,
              surfaceTintColor: surfaceColor,

              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                titlePadding: EdgeInsets.only(
                  left: titleLeftPadding, // 动态padding
                  bottom: 16,
                ),
                // 使用AnimatedBuilder确保平滑过渡
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    return const Text(
                      "Settings",
                      style: TextStyle(fontSize: 22),
                    );
                  },
                ),
                background: Container(
                  color: surfaceColor,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Card(
                            shadowColor: Colors.transparent,
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(
                                top: 12,
                                bottom: 12,
                                right: 18,
                                left: 18,
                              ),
                              child: Text(
                                "Interface",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Card(
                        margin: const EdgeInsets.all(1),
                        shadowColor: Colors.transparent,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.brush),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          title: const Text("Theme"),
                          subtitle: const Text(
                              "Edit the theme mode of this application."),
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(
                                      builder: (context, setState) {
                                    return AlertDialog(
                                      title: const Text("Theme"),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RadioListTile<AppThemeMode>(
                                            shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(24),
                                                    topRight:
                                                        Radius.circular(24),
                                                    bottomLeft:
                                                        Radius.circular(4),
                                                    bottomRight:
                                                        Radius.circular(4))),
                                            tileColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLow,
                                            title: const Text("Follow system"),
                                            value: AppThemeMode.followSystem,
                                            groupValue: _selectedThemeMode,
                                            onChanged: (value) {
                                              setState(() =>
                                                  _selectedThemeMode = value!);
                                            },
                                          ),
                                          const SizedBox(
                                            height: 2,
                                          ),
                                          RadioListTile<AppThemeMode>(
                                            shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                    topRight:
                                                        Radius.circular(4),
                                                    bottomLeft:
                                                        Radius.circular(4),
                                                    bottomRight:
                                                        Radius.circular(4))),
                                            tileColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLow,
                                            title: const Text("Day"),
                                            value: AppThemeMode.day,
                                            groupValue: _selectedThemeMode,
                                            onChanged: (value) {
                                              setState(() =>
                                                  _selectedThemeMode = value!);
                                            },
                                          ),
                                          const SizedBox(
                                            height: 2,
                                          ),
                                          RadioListTile<AppThemeMode>(
                                            shape: const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                    topRight:
                                                        Radius.circular(4),
                                                    bottomLeft:
                                                        Radius.circular(24),
                                                    bottomRight:
                                                        Radius.circular(24))),
                                            tileColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerLow,
                                            title: const Text("Night"),
                                            value: AppThemeMode.night,
                                            groupValue: _selectedThemeMode,
                                            onChanged: (value) {
                                              setState(() =>
                                                  _selectedThemeMode = value!);
                                            },
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: ExpressiveOutlinedButton(
                                                  child: const Text("Cancel"),
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop()),
                                            ),
                                            const SizedBox(
                                              width: 8,
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: ExpressiveFilledButton(
                                                  onPressed: () {
                                                    Navigator.pop(context,
                                                        _selectedThemeMode);
                                                  },
                                                  child: const Text("Confirm")),
                                            ),
                                          ],
                                        )
                                      ],
                                    );
                                  });
                                });
                          },
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.all(1),
                        shadowColor: Colors.transparent,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLowest,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.color_lens),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          title: const Text("Theme color"),
                          subtitle: const Text(
                              "Edit the accent color of this application."),
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Card(
                            shadowColor: Colors.transparent,
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(
                                top: 12,
                                bottom: 12,
                                right: 18,
                                left: 18,
                              ),
                              child: Text(
                                "Behavior",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ]),
              ),
            )
          ],
        ),
      );
    });
  }
}
