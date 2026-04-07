import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

//
//  這裏是閑下來的時候自己寫的一些表現力組件。當然可以直接用哦，畢竟沒什麽技術含量
//  摸摸頭，愛你們喲 (＾Ｕ＾)ノ~ＹＯ
//

class ExpressiveFilledButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ExpressiveFilledButton(
      {super.key,
      required this.child,
      required this.onPressed,
      this.backgroundColor,
      this.foregroundColor});

  @override
  State<ExpressiveFilledButton> createState() => _ExpressiveFilledButtonState();
}

class _ExpressiveFilledButtonState extends State<ExpressiveFilledButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isAnimating = false; // 防止重复点击的锁
  bool _isHolding = false; // 标记是否正在按住
  late AnimationController _controller;
  late Animation<double> _borderRadiusAnimation;
  late Animation<double> _widthAnimation;
  final GlobalKey _containerKey = GlobalKey();
  double _childWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _borderRadiusAnimation = Tween<double>(
      begin: 48.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _widthAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChildWidth();
    });
  }

  void _updateChildWidth() {
    final RenderBox? renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _childWidth = renderBox.size.width;
      });
    }
  }

  // 开始按住动画
  Future<void> _startHoldAnimation() async {
    if (_isAnimating) return;
    _isHolding = true;
    _isAnimating = true;
    
    try {
      setState(() => _isPressed = true);
      // 正向播放动画到4px
      await _controller.forward().orCancel;
      // 如果还在按住状态（没有松手），保持在4px状态
      if (_isHolding && mounted) {
        setState(() => _isPressed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isPressed = false);
    }
  }

  // 结束按住动画（松手）
  Future<void> _endHoldAnimation({bool isClick = false}) async {
    _isHolding = false;
    
    try {
      // 如果动画还没完成（没到4px），先补完到4px
      if (_controller.value < 1.0) {
        await _controller.forward().orCancel;
      }
      
      // 执行点击回调（只有真正点击时才执行）
      if (isClick) {
        widget.onPressed();
      }
      
      // 反向播放动画复原
      await _controller.reverse().orCancel;
      if (mounted) setState(() => _isPressed = false);
    } catch (_) {
      if (mounted) setState(() => _isPressed = false);
    } finally {
      _isAnimating = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final splashColor = buttonColor.withOpacity(0.3);
    
    Widget coloredChild;
    if (widget.child is Icon) {
      coloredChild = Icon(
        (widget.child as Icon).icon,
        color:
            widget.foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
      );
    } else if (widget.child is Text) {
      coloredChild = Padding(
        padding: const EdgeInsets.only(left: 12, right: 12),
        child: Text(
          (widget.child as Text).data!,
          style: (widget.child as Text).style?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ) ??
              TextStyle(
                  color: widget.foregroundColor ??
                      Theme.of(context).colorScheme.onPrimary),
        ),
      );
    } else {
      coloredChild = widget.child;
    }
    
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return InkWell(
            key: _containerKey,
            // 动态匹配按钮当前的圆角
            borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
            // 涟漪效果配置
            splashColor: splashColor,
            highlightColor: Colors.transparent,
            // 手势处理
            onTapDown: (_) => _startHoldAnimation(),
            onTapUp: (_) => _endHoldAnimation(isClick: true),
            onTapCancel: () => _endHoldAnimation(isClick: false),
            // 使用Ink作为背景容器，让涟漪显示在背景之上
            child: Ink(
              width: _childWidth > 0 ? _childWidth * _widthAnimation.value : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
                color: buttonColor,
              ),
              padding: const EdgeInsets.all(12.0),
              child: Center(child: coloredChild),
            ),
          );
        },
      ),
    );
  }
}

class ExpressiveOutlinedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const ExpressiveOutlinedButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<ExpressiveOutlinedButton> createState() =>
      _ExpressiveOutlinedButtonState();
}

class _ExpressiveOutlinedButtonState extends State<ExpressiveOutlinedButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isAnimating = false; // 防止重复点击的锁
  bool _isHolding = false; // 标记是否正在按住
  late AnimationController _controller;
  late Animation<double> _borderRadiusAnimation;
  late Animation<double> _widthAnimation;
  final GlobalKey _containerKey = GlobalKey();
  double _childWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _borderRadiusAnimation = Tween<double>(
      begin: 48.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _widthAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChildWidth();
    });
  }

  void _updateChildWidth() {
    final RenderBox? renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _childWidth = renderBox.size.width;
      });
    }
  }

  // 开始按住动画
  Future<void> _startHoldAnimation() async {
    if (_isAnimating) return;
    _isHolding = true;
    _isAnimating = true;
    
    try {
      setState(() => _isPressed = true);
      // 正向播放动画到4px
      await _controller.forward().orCancel;
      // 如果还在按住状态，保持在4px状态
      if (_isHolding && mounted) {
        setState(() => _isPressed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isPressed = false);
    }
  }

  // 结束按住动画（松手）
  Future<void> _endHoldAnimation({bool isClick = false}) async {
    _isHolding = false;
    
    try {
      // 如果动画还没完成，先补完到4px
      if (_controller.value < 1.0) {
        await _controller.forward().orCancel;
      }
      
      // 执行点击回调（只有真正点击时才执行）
      if (isClick) {
        widget.onPressed();
      }
      
      // 反向播放动画复原
      await _controller.reverse().orCancel;
      if (mounted) setState(() => _isPressed = false);
    } catch (_) {
      if (mounted) setState(() => _isPressed = false);
    } finally {
      _isAnimating = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final splashColor = primaryColor.withOpacity(0.1);
    
    Widget coloredChild;
    if (widget.child is Icon) {
      coloredChild = Icon(
        (widget.child as Icon).icon,
        color: primaryColor,
      );
    } else if (widget.child is Text) {
      coloredChild = Padding(
        padding: const EdgeInsets.only(left: 12, right: 12),
        child: Text(
          (widget.child as Text).data!,
          style: (widget.child as Text).style?.copyWith(
                    color: primaryColor,
                  ) ??
              TextStyle(color: primaryColor),
        ),
      );
    } else {
      coloredChild = widget.child;
    }
    
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return InkWell(
            key: _containerKey,
            // 动态匹配按钮当前的圆角
            borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
            // 涟漪效果配置
            splashColor: splashColor,
            highlightColor: Colors.transparent,
            // 手势处理
            onTapDown: (_) => _startHoldAnimation(),
            onTapUp: (_) => _endHoldAnimation(isClick: true),
            onTapCancel: () => _endHoldAnimation(isClick: false),
            // 轮廓按钮使用Container + 透明Ink
            child: Container(
              width: _childWidth > 0 ? _childWidth * _widthAnimation.value : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
                border: Border.all(
                    color: primaryColor, width: 1),
              ),
              padding: const EdgeInsets.only(top: 11, bottom: 11, left: 12, right: 12),
              child: Ink(
                color: Colors.transparent,
                child: Center(child: coloredChild),
              ),
            ),
          );
        },
      ),
    );
  }
}



class ExpressiveFloatingActionButton extends StatefulWidget {
  final List<ActionItem> actionItems;
  final IconData defaultIcon; // 默认为加号
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ExpressiveFloatingActionButton({
    super.key,
    required this.actionItems,
    this.defaultIcon = Icons.add, // 未展开默认显示加号
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<ExpressiveFloatingActionButton> createState() =>
      _ExpressiveFloatingActionButtonState();
}

class _ExpressiveFloatingActionButtonState
    extends State<ExpressiveFloatingActionButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onActionTap(VoidCallback onTap) {
    onTap();
    _toggleExpand();
  }

  @override
  Widget build(BuildContext context) {
    // 基础颜色配置
    final theme = Theme.of(context);
    final defaultBgColor =
        widget.backgroundColor ?? theme.colorScheme.primaryContainer;
    final expandedBgColor = theme.colorScheme.primary; // 展開後背景色
    final defaultFgColor =
        widget.foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final expandedFgColor = theme.colorScheme.onPrimary; // 展開後前景色

    final screenSize = MediaQuery.of(context).size;

    return Stack(
      alignment: Alignment.bottomRight, // 保持FAB在右下角
      children: [
        if (_isExpanded)
          Container(
          width: screenSize.width,
          height: screenSize.height,
          color: Colors.black.withOpacity(0),
            child: GestureDetector(
              // 點擊空白處收起FAB
              onTap: _toggleExpand,
              behavior: HitTestBehavior.translucent,
              child: AnimatedOpacity(
                opacity: _isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black.withOpacity(0),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(0.0), // 保持FAB右下角邊距
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 展開的動作卡片列表
              if (_isExpanded)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: widget.actionItems
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _ActionCapsule(
                                icon: item.icon,
                                label: item.label,
                                onTap: () => _onActionTap(item.onTap),
                              ),
                            ))
                        .toList(),
                  ),
                ),

              // 主FAB按鈕
              SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  onPressed: _toggleExpand,
                  backgroundColor: _isExpanded ? expandedBgColor : defaultBgColor,
                  foregroundColor: _isExpanded ? expandedFgColor : defaultFgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_isExpanded ? 28 : 16),
                  ),
                  elevation: 6,
                  child: _isExpanded
                      ? const Icon(Icons.close, size: 24)
                      : Icon(widget.defaultIcon, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCapsule extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCapsule({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 工具枚舉
class ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// 独立的 Material 3 风格的 Expressive Loading Indicator
/// 可直接在任意地方使用，无需依赖下拉刷新逻辑
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({
    super.key,
    this.color,
    this.backgroundColor,
    this.polygons,
    this.constraints,
    this.semanticsLabel,
    this.semanticsValue,
    this.contained = false, // 是否使用带背景的容器样式
  });

  /// 指示器颜色
  final Color? color;
  
  /// 容器背景色（仅contained=true时生效）
  final Color? backgroundColor;
  
  /// 自定义变形多边形列表
  final List<RoundedPolygon>? polygons;
  
  /// 指示器尺寸约束
  final BoxConstraints? constraints;
  
  /// 语义标签
  final String? semanticsLabel;
  
  /// 语义值
  final String? semanticsValue;
  
  /// 是否使用带圆形背景的容器样式
  final bool contained;

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with TickerProviderStateMixin {
  static final List<RoundedPolygon> _defaultPolygons = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.gem,
    MaterialShapes.flower,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
    MaterialShapes.cookie12Sided
  ];

  static final  BoxConstraints _defaultConstraints = BoxConstraints(
    minWidth: 48.0,
    minHeight: 48.0,
    maxWidth: 48.0,
    maxHeight: 48.0,
  );

  // 动画常量
  static const int _globalRotationDurationMs = 4666;
  static const int _morphIntervalMs = 650;
  static const double _fullRotation = 360.0;
  static const double _quarterRotation = _fullRotation / 4;

  late final List<RoundedPolygon> _polygons;
  late final List<Morph> _morphSequence;
  late final AnimationController _morphController;
  late final AnimationController _globalRotationController;
  late final Color _effectiveColor;
  late final Color _effectiveBackgroundColor;

  int _currentMorphIndex = 0;
  double _morphRotationTargetAngle = _quarterRotation;
  Timer? _morphTimer;

  // 弹簧动画配置
  final _morphAnimationSpec = SpringSimulation(
    SpringDescription.withDampingRatio(ratio: 0.6, stiffness: 200.0, mass: 1.0),
    0.0,
    1.0,
    5.0,
    tolerance: const Tolerance(velocity: 0.1, distance: 0.1),
  );

  @override
  void initState() {
    super.initState();
    
    // 初始化颜色
    _effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;
    _effectiveBackgroundColor = widget.backgroundColor ?? 
        Theme.of(context).colorScheme.primaryContainer;

    // 初始化多边形和变形序列
    _polygons = widget.polygons ?? _defaultPolygons;
    _morphSequence = _createMorphSequence(_polygons, circularSequence: true);

    // 初始化动画控制器
    _morphController = AnimationController.unbounded(vsync: this);
    _globalRotationController = AnimationController(
      duration: const Duration(milliseconds: _globalRotationDurationMs),
      vsync: this,
    );

    // 启动动画
    _startAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 处理主题变化
    if (_effectiveColor == widget.color && widget.color == null) {
      _effectiveColor = Theme.of(context).colorScheme.primary;
    }
    if (_effectiveBackgroundColor == widget.backgroundColor && widget.backgroundColor == null) {
      _effectiveBackgroundColor = Theme.of(context).colorScheme.primaryContainer;
    }
  }

  @override
  void didUpdateWidget(covariant ExpressiveLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 更新颜色
    if (oldWidget.color != widget.color) {
      setState(() {
        _effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;
      });
    }
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      setState(() {
        _effectiveBackgroundColor = widget.backgroundColor ?? 
            Theme.of(context).colorScheme.primaryContainer;
      });
    }
    // 更新多边形
    if (oldWidget.polygons != widget.polygons) {
      setState(() {
        _polygons = widget.polygons ?? _defaultPolygons;
        _morphSequence = _createMorphSequence(_polygons, circularSequence: true);
      });
    }
  }

  @override
  void dispose() {
    // 清理资源
    _morphTimer?.cancel();
    _morphController.dispose();
    _globalRotationController.dispose();
    super.dispose();
  }

  /// 创建变形序列
  List<Morph> _createMorphSequence(List<RoundedPolygon> polygons,
      {required bool circularSequence}) {
    final morphs = <Morph>[];
    for (int i = 0; i < polygons.length; i++) {
      if (i + 1 < polygons.length) {
        morphs.add(Morph(polygons[i], polygons[i + 1]));
      } else if (circularSequence) {
        morphs.add(Morph(polygons[i], polygons[0]));
      }
    }
    return morphs;
  }

  /// 启动动画
  void _startAnimations() {
    // 无限循环全局旋转
    _globalRotationController.repeat();

    // 定时切换变形
    _morphTimer = Timer.periodic(
      const Duration(milliseconds: _morphIntervalMs),
      (_) => _startMorphCycle(),
    );

    // 启动第一个变形周期
    _startMorphCycle();
  }

  /// 开始变形周期
  void _startMorphCycle() {
    if (!mounted) return;

    // 更新变形索引和旋转角度
    _currentMorphIndex = (_currentMorphIndex + 1) % _morphSequence.length;
    _morphRotationTargetAngle =
        (_morphRotationTargetAngle + _quarterRotation) % _fullRotation;

    // 重置并启动变形动画
    _morphController.reset();
    _morphController.animateWith(_morphAnimationSpec).then((_) {
      if (mounted && _morphController.value != 1.0) {
        _morphController.value = 1.0;
      }
    });
  }

  /// 计算缩放因子
  double _calculateScaleFactor(List<RoundedPolygon> polygons) {
    var scaleFactor = 1.0;
    for (final polygon in polygons) {
      final bounds = polygon.calculateBounds();
      final maxBounds = polygon.calculateMaxBounds();

      final boundsWidth = bounds[2] - bounds[0];
      final boundsHeight = bounds[3] - bounds[1];
      final maxBoundsWidth = maxBounds[2] - maxBounds[0];
      final maxBoundsHeight = maxBounds[3] - maxBounds[1];

      final scaleX = boundsWidth / maxBoundsWidth;
      final scaleY = boundsHeight / maxBoundsHeight;

      scaleFactor = math.min(scaleFactor, math.max(scaleX, scaleY));
    }
    return scaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final constraints = widget.constraints ?? _defaultConstraints;
    final activeIndicatorScale = 38.0 /
        math.min(constraints.maxWidth, constraints.maxHeight);
    final shapesScaleFactor =
        _calculateScaleFactor(_polygons) * activeIndicatorScale;

    // 核心指示器部件
    Widget indicator = AnimatedBuilder(
      animation: Listenable.merge(
          [_morphController, _globalRotationController]),
      builder: (context, child) {
        final morphProgress = _morphController.value.clamp(0.0, 1.0);
        final globalRotationDegrees =
            _globalRotationController.value * _fullRotation;

        // 计算总旋转角度
        final totalRotationDegrees = morphProgress * 90 +
            _morphRotationTargetAngle +
            globalRotationDegrees;
        final totalRotationRadians =
            totalRotationDegrees * (math.pi / 180.0);

        return Transform.rotate(
          angle: totalRotationRadians,
          child: CustomPaint(
            painter: _MorphPainter(
              morph: _morphSequence[_currentMorphIndex],
              progress: morphProgress,
              color: _effectiveColor,
              scaleFactor: shapesScaleFactor,
              morphIndex: _currentMorphIndex,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );

    // 如果是容器样式，添加圆形背景
    if (widget.contained) {
      indicator = Container(
        decoration: BoxDecoration(
          color: _effectiveBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: indicator,
      );
    }

    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: widget.semanticsLabel,
        value: widget.semanticsValue,
      ),
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: constraints,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: indicator,
          ),
        ),
      ),
    );
  }
}

/// 变形绘制器
class _MorphPainter extends CustomPainter {
  final Morph morph;
  final double progress;
  final Color color;
  final double scaleFactor;
  final int morphIndex;

  _MorphPainter({
    required this.morph,
    required this.progress,
    required this.color,
    this.scaleFactor = 1.0,
    this.morphIndex = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.0 || color.alpha == 0) return;

    // 限制进度范围
    final clampedProgress = progress.clamp(0.0, 1.0);

    // 创建变形路径
    final path = morph.toPath(progress: clampedProgress);
    final processedPath = _processPath(path, size);

    // 绘制路径
    canvas.drawPath(
      processedPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) {
    return oldDelegate.morph != morph ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.scaleFactor != scaleFactor ||
        oldDelegate.morphIndex != morphIndex;
  }

  /// 处理路径：缩放并居中
  Path _processPath(Path path, Size size) {
    // 缩放路径
    final Matrix4 scaleMatrix = Matrix4.diagonal3Values(
      size.width * scaleFactor,
      size.height * scaleFactor,
      1,
    );
    final Path scaledPath = path.transform(scaleMatrix.storage);

    // 居中路径
    final Rect bounds = scaledPath.getBounds();
    final Offset translation =
        Offset(size.width / 2, size.height / 2) - bounds.center;
    final Path finalPath = scaledPath.shift(translation);

    return finalPath;
  }
}

