import 'package:flutter/material.dart'
    hide ReorderableList, ReorderableListState;
import 'package:reorderable_list/drawer.dart';
import 'package:flutter_reorderable_list/flutter_reorderable_list.dart';

class Category {
  String name;
  List<Channel> channels;
  bool collapse;
  Category({
    required this.name,
    required this.channels,
    this.collapse = false,
  });
  get key => ValueKey("Category:" + name);
}

class Channel {
  String name;
  bool forceDisplay;
  Channel({
    required this.name,
    this.forceDisplay = false,
  });
  get key => ValueKey("Channel:" + name);
}

class IndexPath {
  int section;
  int index;
  IndexPath({
    required this.section,
    this.index = -1,
  });
}

class NestingExample extends StatefulWidget {
  const NestingExample({Key? key}) : super(key: key);

  @override
  State<NestingExample> createState() => _NestingExampleState();
}

class _NestingExampleState extends State<NestingExample> {
  final List<Category> _categories = [
    Category(name: '', channels: [
      Channel(name: 'announcements'),
    ]),
    Category(name: 'HELP AND DEVELOPMENT', channels: [
      Channel(name: 'install-and-setup'),
      Channel(name: 'general'),
      Channel(name: 'state-and-architecture'),
      Channel(name: 'ui-and-layout'),
      Channel(name: 'code-review'),
      Channel(name: 'performance'),
      Channel(name: 'tests'),
      Channel(name: 'pure-dart'),
    ]),
    Category(name: 'PLATFORM SPECIFIC', channels: [
      Channel(name: 'android'),
      Channel(name: 'ios'),
      Channel(name: 'web'),
      Channel(name: 'windows'),
      Channel(name: 'macos'),
      Channel(name: 'linux'),
      Channel(name: 'embedding'),
    ]),
    Category(name: 'SERVER SIDE', channels: [
      Channel(name: 'firebase'),
      Channel(name: 'aws-amplify'),
      Channel(name: 'backends'),
    ]),
  ];

  IndexPath? _indexPathOfKey(Key key) {
    for (int i = 0; i < _categories.length; i++) {
      if (_categories[i].key == key) {
        return IndexPath(section: i);
      }
      for (int j = 0; j < _categories[i].channels.length; j++) {
        if (_categories[i].channels[j].key == key) {
          return IndexPath(section: i, index: j);
        }
      }
    }
    return null;
  }

  bool _reorderIndexCallback(Key dragPrositionKey, Key dropPositionKey) {
    IndexPath? dragProsition = _indexPathOfKey(dragPrositionKey);
    IndexPath? dropPosition = _indexPathOfKey(dropPositionKey);

    if (dropPosition == null || dragProsition == null) {
      return false;
    }

    if (dropPosition.index == -1 &&
        dropPosition.section <= dragProsition.section &&
        dropPosition.section == 0) {
      return false;
    }

    final draggedItem =
        _categories[dragProsition.section].channels[dragProsition.index];
    setState(() {
      draggedItem.forceDisplay = true;

      _categories[dragProsition.section].channels.removeAt(dragProsition.index);
      if (dropPosition.index == -1) {
        if (dropPosition.section > dragProsition.section) {
          _categories[dropPosition.section].channels.insert(0, draggedItem);
        } else {
          int section = dropPosition.section - 1;
          if (section >= 0) {
            _categories[section].channels.add(draggedItem);
          }
        }
      } else {
        _categories[dropPosition.section]
            .channels
            .insert(dropPosition.index, draggedItem);
      }
    });
    return true;
  }

  void _reorderIndexDone(Key dragPrositionKey) {
    IndexPath? dragProsition = _indexPathOfKey(dragPrositionKey);
    if (dragProsition == null) {
      return;
    }
    final draggedItem =
        _categories[dragProsition.section].channels[dragProsition.index];
    setState(() {
      draggedItem.forceDisplay = false;
    });
  }

  bool _reorderSectionCallback(Key dragPrositionKey, Key dropPositionKey) {
    IndexPath? dragProsition = _indexPathOfKey(dragPrositionKey);
    IndexPath? dropPosition = _indexPathOfKey(dropPositionKey);

    if (dropPosition == null || dragProsition == null) {
      return false;
    }

    if (dropPosition.section == 0) {
      return false;
    }

    final draggedItem = _categories[dragProsition.section];
    setState(() {
      _categories.removeAt(dragProsition.section);
      _categories.insert(dropPosition.section, draggedItem);
    });
    return true;
  }

  void _reorderSectionDone(Key dragPrositionKey) {
    // IndexPath? dragProsition = _indexPathOfKey(dragPrositionKey);
    // if (dragProsition == null) {
    //   return;
    // }
    // final draggedItem = _categories[dragProsition.section];
  }

  final GlobalKey<ReorderableListState> sectionListKey = GlobalKey();
  final GlobalKey<ReorderableListState> indexListKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nesting"),
      ),
      drawer: const NavigationDrawer(),
      body: Container(
        width: 240,
        decoration: const BoxDecoration(
          color: Color(0xFFF2F3F5),
        ),
        child: ReorderableList(
          key: sectionListKey,
          onReorder: _reorderSectionCallback,
          onReorderDone: _reorderSectionDone,
          child: ReorderableList(
            key: indexListKey,
            onReorder: _reorderIndexCallback,
            onReorderDone: _reorderIndexDone,
            child: ListView(
              padding: const EdgeInsets.only(right: 8),
              children: [
                for (var v in _categories)
                  ChannelSection(
                      sectionListKey: sectionListKey,
                      indexListKey: indexListKey,
                      category: v)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChannelSection extends StatefulWidget {
  final Category category;
  final GlobalKey<ReorderableListState> sectionListKey;
  final GlobalKey<ReorderableListState> indexListKey;

  const ChannelSection({
    Key? key,
    required this.sectionListKey,
    required this.indexListKey,
    required this.category,
  }) : super(key: key);

  @override
  _ChannelSectionState createState() => _ChannelSectionState();
}

class _ChannelSectionState extends State<ChannelSection> {
  Widget _buildCategory(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.category.collapse = !widget.category.collapse;
        });
      },
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            const SizedBox(width: 2),
            Icon(
                widget.category.collapse
                    ? Icons.navigate_next
                    : Icons.expand_more,
                color: const Color(0xFF6C747F),
                size: 12),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                widget.category.name,
                style: const TextStyle(
                  color: Color(0xFF6C747F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannel(BuildContext context, Channel v) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.tag, color: Color(0xFF6C747F), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v.name,
                style: const TextStyle(
                  color: Color(0xFF6C747F),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableItem(
        key: widget.category.key,
        listKey: widget.sectionListKey,
        childBuilder:
            (BuildContext context, ReorderableItemDisplayState state) {
          BoxDecoration? decoration;

          if (state == ReorderableItemDisplayState.dragProxy ||
              state == ReorderableItemDisplayState.dragProxyFinished) {
            decoration = const BoxDecoration(color: Color(0xD0FFFFFF));
          }

          final showSection = state != ReorderableItemDisplayState.placeholder;

/*
There is a issue here:
If you use `Opacity` to control the category display or not here.
You will got a render assert error when you drag one channel in the first category(without title) down.
I dont know why. It may be a bug about `Opacity` nesting.
So here I avoid Opacity nesting to avoid this issue.
*/
          return Container(
            decoration: decoration,
            child: Column(
              children: [
                ReorderableListener(
                  child: ReorderableItem(
                    key: widget.category.key, //
                    listKey: widget.indexListKey,
                    childBuilder: (BuildContext context,
                        ReorderableItemDisplayState state) {
                      return Opacity(
                        opacity: !showSection ? 0.0 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.only(top: 16),
                          child: widget.category.name.isEmpty
                              ? Container()
                              : _buildCategory(context),
                        ),
                      );
                    },
                  ),
                ),
                for (var v in widget.category.channels)
                  if (!widget.category.collapse || v.forceDisplay)
                    ReorderableItem(
                      key: v.key,
                      listKey: widget.indexListKey,
                      childBuilder: (BuildContext context,
                          ReorderableItemDisplayState state) {
                        BoxDecoration? decoration;

                        if (state == ReorderableItemDisplayState.dragProxy ||
                            state ==
                                ReorderableItemDisplayState.dragProxyFinished) {
                          decoration =
                              const BoxDecoration(color: Color(0xD0FFFFFF));
                        }

                        return ReorderableListener(
                          child: Opacity(
                            opacity: !showSection ||
                                    state ==
                                        ReorderableItemDisplayState.placeholder
                                ? 0.0
                                : 1.0,
                            child: Container(
                              decoration: decoration,
                              child: _buildChannel(context, v),
                            ),
                          ),
                        );
                      },
                    )
              ],
            ),
          );
        });
  }
}
