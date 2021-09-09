library flutter_reorderable_list;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'dart:collection';
import 'dart:math';
import 'dart:async';
import 'dart:ui' show lerpDouble;

typedef bool ReorderItemCallback(Key draggedItem, Key newPosition);
typedef void ReorderCompleteCallback(Key draggedItem);

// Represents placeholder for currently dragged row including decorations
// (i.e. before and after shadow)
class DecoratedPlaceholder {
  DecoratedPlaceholder({
    required this.offset,
    required this.widget,
  });

  // Height of decoration before widget
  final double offset;
  final Widget widget;
}

// Decorates current placeholder widget
typedef DecoratedPlaceholder DecoratePlaceholder(
  Widget widget,
  double decorationOpacity,
);

// Can be used to cancel reordering (i.e. when underlying data changed)
class CancellationToken {
  void cancelDragging() {
    for (final callback in _callbacks) {
      callback();
    }
  }

  final _callbacks = <VoidCallback>[];
}

class ReorderableList extends StatefulWidget {
  ReorderableList({
    Key? key,
    required this.child,
    required this.onReorder,
    this.onReorderDone,
    this.cancellationToken,
    this.decoratePlaceholder = _defaultDecoratePlaceholder,
  }) : super(key: key);

  final Widget child;

  final ReorderItemCallback onReorder;
  final ReorderCompleteCallback? onReorderDone;
  final DecoratePlaceholder decoratePlaceholder;

  final CancellationToken? cancellationToken;

  @override
  State<StatefulWidget> createState() => _ReorderableListState();
}

enum ReorderableItemState {
  /// Normal item inside list
  normal,

  /// Placeholder, used at position of currently dragged item;
  /// Should have same dimensions as [normal] but hidden content
  placeholder,

  // Proxy item displayed during dragging
  dragProxy,

  // Proxy item displayed during finishing animation
  dragProxyFinished
}

typedef Widget ReorderableItemChildBuilder(
  BuildContext context,
  ReorderableItemState state,
);

class ReorderableItem extends StatefulWidget {
  /// [key] must be unique key for every item. It must be stable and not change
  /// when items are reordered
  ReorderableItem({
    required Key key,
    required this.childBuilder,
  }) : super(key: key);

  final ReorderableItemChildBuilder childBuilder;

  @override
  createState() => _ReorderableItemState();
}

typedef ReorderableListenerCallback = bool Function();

class ReorderableListener extends StatelessWidget {
  ReorderableListener({
    Key? key,
    this.child,
    this.canStart,
  }) : super(key: key);
  final Widget? child;

  final ReorderableListenerCallback? canStart;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerEvent event) => _routePointer(event, context),
      child: child,
    );
  }

  void _routePointer(PointerEvent event, BuildContext context) {
    if (canStart == null || canStart!()) {
      _startDragging(context: context, event: event);
    }
  }

  @protected
  MultiDragGestureRecognizer createRecognizer({
    required Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) {
    return _Recognizer(
      debugOwner: debugOwner,
      supportedDevices: supportedDevices,
    );
  }

  void _startDragging({required BuildContext context, PointerEvent? event}) {
    _ReorderableItemState? state =
        context.findAncestorStateOfType<_ReorderableItemState>();

    final scrollable = Scrollable.of(context);

    final listState = _ReorderableListState.of(context)!;

    if (listState.dragging == null) {
      listState._startDragging(
        key: state!.key,
        event: event!,
        scrollable: scrollable,
        recognizer: createRecognizer(
          debugOwner: this,
          supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
      );
    }
  }
}

class DelayedReorderableListener extends ReorderableListener {
  DelayedReorderableListener({
    Key? key,
    Widget? child,
    ReorderableListenerCallback? canStart,
    this.delay = kLongPressTimeout,
  }) : super(key: key, child: child, canStart: canStart);

  final Duration delay;

  @protected
  MultiDragGestureRecognizer createRecognizer({
    required Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) {
    return DelayedMultiDragGestureRecognizer(
      delay: delay,
      debugOwner: debugOwner,
      supportedDevices: supportedDevices,
    );
  }
}

class _ReorderableListState extends State<ReorderableList>
    with TickerProviderStateMixin, Drag {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[widget.child, _DragProxy(widget.decoratePlaceholder)],
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.cancellationToken != null) {
      widget.cancellationToken!._callbacks.add(this._cancel);
    }
  }

  @override
  void dispose() {
    if (widget.cancellationToken != null) {
      widget.cancellationToken!._callbacks.remove(this._cancel);
    }
    _finalAnimation?.dispose();
    for (final c in _itemTranslations.values) {
      c.dispose();
    }
    _scrolling = false;
    _recognizer?.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_dragging != null) {
      if (_finalAnimation != null) {
        _finalAnimation!.dispose();
        _finalAnimation = null;
      }

      final dragging = _dragging!;
      _dragging = null;
      _dragProxy!.hide();

      var current = _items[_dragging];
      current?.update();

      if (widget.onReorderDone != null) {
        widget.onReorderDone!(dragging);
      }
    }
  }

  // Returns currently dragged key
  Key? get dragging => _dragging;

  Key? _dragging;
  MultiDragGestureRecognizer? _recognizer;
  _DragProxyState? _dragProxy;

  void _startDragging({
    Key? key,
    required PointerEvent event,
    MultiDragGestureRecognizer? recognizer,
    ScrollableState? scrollable,
  }) {
    _scrollable = scrollable;

    _finalAnimation?.stop(canceled: true);
    _finalAnimation?.dispose();
    _finalAnimation = null;

    if (_dragging != null) {
      var current = _items[_dragging];
      _dragging = null;
      current?.update();
    }

    _maybeDragging = key;
    _lastReportedKey = null;
    _recognizer?.dispose();
    _recognizer = recognizer;
    _recognizer!.onStart = _dragStart;
    _recognizer!.addPointer(event as PointerDownEvent);
  }

  Key? _maybeDragging;

  Drag _dragStart(Offset position) {
    if (_dragging == null && _maybeDragging != null) {
      _dragging = _maybeDragging;
      _maybeDragging = null;
    }
    _hapticFeedback();
    final draggedItem = _items[_dragging]!;
    draggedItem.update();
    _dragProxy!.setWidget(
        draggedItem.widget
            .childBuilder(draggedItem.context, ReorderableItemState.dragProxy),
        draggedItem.context.findRenderObject() as RenderBox);
    this._scrollable!.position.addListener(this._scrolled);

    return this;
  }

  void _draggedItemWidgetUpdated() {
    final draggedItem = _items[_dragging];
    if (draggedItem != null) {
      _dragProxy!.updateWidget(draggedItem.widget
          .childBuilder(draggedItem.context, ReorderableItemState.dragProxy));
    }
  }

  void _scrolled() {
    checkDragPosition();
  }

  void update(DragUpdateDetails details) {
    _dragProxy!.offset += details.delta.dy;
    checkDragPosition();
    maybeScroll();
  }

  ScrollableState? _scrollable;

  void maybeScroll() async {
    if (!_scrolling && _scrollable != null && _dragging != null) {
      final position = _scrollable!.position;

      double newOffset;
      int duration = 14; // in ms
      double step = 1.0;
      double overdragMax = 20.0;
      double overdragCoef = 10.0;

      MediaQueryData d = MediaQuery.of(context);

      double top = d.padding.top;
      double bottom =
          this._scrollable!.position.viewportDimension - d.padding.bottom;

      if (_dragProxy!.offset < top &&
          position.pixels > position.minScrollExtent) {
        final overdrag = max(top - _dragProxy!.offset, overdragMax);

        newOffset = max(
          position.minScrollExtent,
          position.pixels - step * overdrag / overdragCoef,
        );
      } else if (_dragProxy!.offset + _dragProxy!.height > bottom &&
          position.pixels < position.maxScrollExtent) {
        final overdrag = max<double>(
            _dragProxy!.offset + _dragProxy!.height - bottom, overdragMax);
        newOffset = min(position.maxScrollExtent,
            position.pixels + step * overdrag / overdragCoef);
      } else {
        return;
      }

      if ((newOffset - position.pixels).abs() >= 1.0) {
        _scrolling = true;
        await this._scrollable!.position.animateTo(newOffset,
            duration: Duration(milliseconds: duration), curve: Curves.linear);
        _scrolling = false;
        if (_dragging != null) {
          checkDragPosition();
          maybeScroll();
        }
      }
    }
  }

  bool _scrolling = false;

  void cancel() {
    end(null);
  }

  end(DragEndDetails? details) async {
    if (_dragging == null) {
      return;
    }

    _hapticFeedback();
    if (_scrolling) {
      var prevDragging = _dragging;
      _dragging = null;
      SchedulerBinding.instance!.addPostFrameCallback((Duration timeStamp) {
        _dragging = prevDragging;
        end(details);
      });
      return;
    }

    if (_scheduledRebuild) {
      SchedulerBinding.instance!.addPostFrameCallback((Duration timeStamp) {
        if (mounted) end(details);
      });
      return;
    }

    this._scrollable!.position.removeListener(this._scrolled);

    var current = _items[_dragging];
    if (current == null) return;

    final originalOffset = _itemOffset(current);
    final dragProxyOffset = _dragProxy!.offset;

    _dragProxy!.updateWidget(current.widget
        .childBuilder(current.context, ReorderableItemState.dragProxyFinished));

    _finalAnimation = AnimationController(
        vsync: this,
        lowerBound: 0.0,
        upperBound: 1.0,
        value: 0.0,
        duration: Duration(milliseconds: 300));

    _finalAnimation!.addListener(() {
      _dragProxy!.offset = lerpDouble(
        dragProxyOffset,
        originalOffset,
        _finalAnimation!.value,
      )!;
      _dragProxy!.decorationOpacity = 1.0 - _finalAnimation!.value;
    });

    _recognizer?.dispose();
    _recognizer = null;

    await _finalAnimation!.animateTo(1.0, curve: Curves.easeOut);

    if (_finalAnimation != null) {
      _finalAnimation!.dispose();
      _finalAnimation = null;

      final dragging = _dragging!;
      _dragging = null;
      _dragProxy!.hide();
      current.update();
      _scrollable = null;

      if (widget.onReorderDone != null) {
        widget.onReorderDone!(dragging);
      }
    }
  }

  void checkDragPosition() {
    if (_scheduledRebuild) {
      return;
    }
    final draggingState = _items[_dragging];
    if (draggingState == null) {
      return;
    }

    final draggingTop = _itemOffset(draggingState);
    final draggingHeight = draggingState.context.size!.height;

    _ReorderableItemState? closest;
    double closestDistance = 0.0;

    // These callbacks will be invoked on successful reorder, they will ensure that
    // reordered items appear on their old position and animate to new one
    List<Function> onReorderApproved = [];

    if (_dragProxy!.offset < draggingTop) {
      for (_ReorderableItemState item in _items.values) {
        if (item.key == _dragging) continue;
        final itemTop = _itemOffset(item);
        if (itemTop > draggingTop) continue;
        final itemBottom = itemTop +
            (item.context.findRenderObject() as RenderBox).size.height / 2;

        if (_dragProxy!.offset < itemBottom) {
          onReorderApproved.add(() {
            _adjustItemTranslation(item.key, -draggingHeight, draggingHeight);
          });
          if (closest == null ||
              closestDistance > (itemBottom - _dragProxy!.offset)) {
            closest = item;
            closestDistance = (itemBottom - _dragProxy!.offset);
          }
        }
      }
    } else {
      double draggingBottom = _dragProxy!.offset + draggingHeight;

      for (_ReorderableItemState item in _items.values) {
        if (item.key == _dragging) continue;
        final itemTop = _itemOffset(item);
        if (itemTop < draggingTop) continue;

        final itemBottom = itemTop +
            (item.context.findRenderObject() as RenderBox).size.height / 2;
        if (draggingBottom > itemBottom) {
          onReorderApproved.add(() {
            _adjustItemTranslation(item.key, draggingHeight, draggingHeight);
          });
          if (closest == null ||
              closestDistance > (draggingBottom - itemBottom)) {
            closest = item;
            closestDistance = draggingBottom - itemBottom;
          }
        }
      }
    }

    // _lastReportedKey check is to ensure we don't keep spamming the callback when reorder
    // was rejected for this key;
    if (closest != null &&
        closest.key != _dragging &&
        closest.key != _lastReportedKey) {
      SchedulerBinding.instance!.addPostFrameCallback((Duration timeStamp) {
        _scheduledRebuild = false;
      });
      _scheduledRebuild = true;
      _lastReportedKey = closest.key;

      if (widget.onReorder(_dragging!, closest.key)) {
        bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

        if (isIOS) {
          _hapticFeedback();
        }
        for (final f in onReorderApproved) {
          f();
        }
        _lastReportedKey = null;
      }
    }
  }

  void _hapticFeedback() {
    HapticFeedback.lightImpact();
  }

  bool _scheduledRebuild = false;
  Key? _lastReportedKey;

  final HashMap<Key?, _ReorderableItemState> _items =
      HashMap<Key, _ReorderableItemState>();

  void registerItem(_ReorderableItemState item) {
    _items[item.key] = item;
  }

  void unregisterItem(_ReorderableItemState item) {
    if (_items[item.key] == item) _items.remove(item.key);
  }

  double _itemOffset(_ReorderableItemState item) {
    final topRenderBox = context.findRenderObject() as RenderBox;
    return (item.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero, ancestor: topRenderBox)
        .dy;
  }

  static _ReorderableListState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ReorderableListState>();
  }

  //

  Map<Key, AnimationController> _itemTranslations = HashMap();

  double itemTranslation(Key key) {
    if (!_itemTranslations.containsKey(key))
      return 0.0;
    else
      return _itemTranslations[key]!.value;
  }

  void _adjustItemTranslation(Key key, double delta, double max) {
    double current = 0.0;
    final currentController = _itemTranslations[key];
    if (currentController != null) {
      current = currentController.value;
      currentController.stop(canceled: true);
      currentController.dispose();
    }

    current += delta;

    final newController = AnimationController(
        vsync: this,
        lowerBound: current < 0.0 ? -max : 0.0,
        upperBound: current < 0.0 ? 0.0 : max,
        value: current,
        duration: const Duration(milliseconds: 300));
    newController.addListener(() {
      _items[key]?.setState(() {}); // update offset
    });
    newController.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        newController.dispose();
        if (_itemTranslations[key] == newController) {
          _itemTranslations.remove(key);
        }
      }
    });
    _itemTranslations[key] = newController;

    newController.animateTo(0.0, curve: Curves.easeInOut);
  }

  AnimationController? _finalAnimation;
}

class _ReorderableItemState extends State<ReorderableItem> {
  get key => widget.key;

  @override
  Widget build(BuildContext context) {
    // super.build(context);
    _listState = _ReorderableListState.of(context);

    _listState!.registerItem(this);
    bool dragging = _listState!.dragging == key;
    double translation = _listState!.itemTranslation(key);
    return Transform(
      transform: Matrix4.translationValues(0.0, translation, 0.0),
      child: widget.childBuilder(
          context,
          dragging
              ? ReorderableItemState.placeholder
              : ReorderableItemState.normal),
    );
  }

  @override
  void didUpdateWidget(ReorderableItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    _listState = _ReorderableListState.of(context);
    if (_listState!.dragging == this.key) {
      _listState!._draggedItemWidgetUpdated();
    }
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void deactivate() {
    _listState?.unregisterItem(this);
    _listState = null;
    super.deactivate();
  }

  _ReorderableListState? _listState;
}

class _DragProxy extends StatefulWidget {
  final DecoratePlaceholder decoratePlaceholder;

  @override
  State<StatefulWidget> createState() => _DragProxyState();

  _DragProxy(this.decoratePlaceholder);
}

class _DragProxyState extends State<_DragProxy> {
  Widget? _widget;
  Size _size = Size.zero;
  double _offset = 0;
  double _offsetX = 0;

  _DragProxyState();

  void setWidget(Widget widget, RenderBox position) {
    setState(() {
      _decorationOpacity = 1.0;
      _widget = widget;
      final state = _ReorderableListState.of(context)!;
      RenderBox renderBox = state.context.findRenderObject() as RenderBox;
      final offset = position.localToGlobal(Offset.zero, ancestor: renderBox);
      _offsetX = offset.dx;
      _offset = offset.dy;
      _size = position.size;
    });
  }

  void updateWidget(Widget widget) {
    _widget = widget;
  }

  set offset(double newOffset) {
    setState(() {
      _offset = newOffset;
    });
  }

  double get offset => _offset;

  double get height => _size.height;

  double _decorationOpacity = 0.0;

  set decorationOpacity(double val) {
    setState(() {
      _decorationOpacity = val;
    });
  }

  void hide() {
    setState(() {
      _widget = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _ReorderableListState.of(context)!;
    state._dragProxy = this;

    if (_widget != null) {
      final w = IgnorePointer(
        child: MediaQuery.removePadding(
          context: context,
          child: _widget!,
          removeTop: true,
          removeBottom: true,
        ),
      );

      final decoratedPlaceholder =
          widget.decoratePlaceholder(w, _decorationOpacity);
      return Positioned(
        child: decoratedPlaceholder.widget,
        left: _offsetX,
        width: _size.width,
        top: offset - decoratedPlaceholder.offset,
      );
    } else {
      return Container(width: 0.0, height: 0.0);
    }
  }

  @override
  void deactivate() {
    _ReorderableListState.of(context)?._dragProxy = null;
    super.deactivate();
  }
}

class _VerticalPointerState extends MultiDragPointerState {
  _VerticalPointerState(Offset initialPosition, PointerDeviceKind kind)
      : super(initialPosition, kind) {
    _resolveTimer = Timer(Duration(milliseconds: 150), () {
      resolve(GestureDisposition.accepted);
      _resolveTimer = null;
    });
  }

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.dy.abs() > pendingDelta!.dx.abs())
      resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
    _resolveTimer?.cancel();
    _resolveTimer = null;
  }

  void dispose() {
    _resolveTimer?.cancel();
    _resolveTimer = null;
    super.dispose();
  }

  Timer? _resolveTimer;
}

//
// VerticalDragGestureRecognizer waits for kTouchSlop to be reached; We don't want that
// when reordering items
//
class _Recognizer extends MultiDragGestureRecognizer {
  _Recognizer({
    required Object? debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          debugOwner: debugOwner,
          supportedDevices: supportedDevices,
        );

  @override
  _VerticalPointerState createNewPointerState(PointerDownEvent event) {
    return _VerticalPointerState(event.position, event.kind);
  }

  @override
  String get debugDescription => "Vertical recognizer";
}

DecoratedPlaceholder _defaultDecoratePlaceholder(
    Widget widget, double decorationOpacity) {
  final double decorationHeight = 10.0;

  final decoratedWidget = Builder(builder: (BuildContext context) {
    final mq = MediaQuery.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Opacity(
              opacity: decorationOpacity,
              child: Container(
                height: decorationHeight,
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0x50000000),
                          width: 1.0 / mq.devicePixelRatio)),
                  gradient: LinearGradient(
                    begin: Alignment(0.0, -1.0),
                    end: Alignment(0.0, 1.0),
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0x10000000),
                      Color(0x30000000)
                    ],
                  ),
                ),
              )),
          widget,
          Opacity(
              opacity: decorationOpacity,
              child: Container(
                height: decorationHeight,
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Color(0x50000000),
                          width: 1.0 / mq.devicePixelRatio)),
                  gradient: LinearGradient(
                    begin: Alignment(0.0, -1.0),
                    end: Alignment(0.0, 1.0),
                    colors: <Color>[
                      Color(0x30000000),
                      Color(0x10000000),
                      Color(0x00000000)
                    ],
                  ),
                ),
              )),
        ]);
  });
  return DecoratedPlaceholder(
    offset: decorationHeight,
    widget: decoratedWidget,
  );
}
