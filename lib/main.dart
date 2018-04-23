import 'package:flutter/material.dart';
import 'reorderable_list.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Rerderable List',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Flutter Reorderable List'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class ItemData {
  ItemData(this.title, this.key);

  final String title;
  final Key key;
}

class _MyHomePageState extends State<MyHomePage> {
  List<ItemData> _items;

  _MyHomePageState() {
    _items = <ItemData>[
      ItemData("Hello", new ValueKey(1)),
      ItemData("Cruel", new ValueKey(2)),
      ItemData("World", new ValueKey(3)),
      ItemData("Whatever", new ValueKey(4)),
      ItemData("Hello", new ValueKey(5)),
      ItemData("Cruel", new ValueKey(6)),
      ItemData("World", new ValueKey(7)),
      ItemData("Whatever", new ValueKey(8)),
      ItemData("Hello", new ValueKey(9)),
      ItemData("Cruel", new ValueKey(10)),
      ItemData("World", new ValueKey(11)),
      ItemData("Whatever", new ValueKey(12)),
      ItemData("Hello", new ValueKey(13)),
      ItemData("Cruel", new ValueKey(14)),
      ItemData("World", new ValueKey(15)),
      ItemData("Whatever", new ValueKey(16)),
      ItemData("Whatever", new ValueKey(17)),
      ItemData("Hello", new ValueKey(18)),
      ItemData("Cruel", new ValueKey(19)),
      ItemData("World", new ValueKey(20)),
      ItemData("Whatever", new ValueKey(21)),
      ItemData("Whatever", new ValueKey(22)),
      ItemData("Whatever", new ValueKey(23)),
      ItemData("Hello", new ValueKey(24)),
      ItemData("Cruel", new ValueKey(25)),
      ItemData("World", new ValueKey(26)),
      ItemData("Whatever", new ValueKey(27))
    ];
  }

  int _indexOfKey(Key key) {
    for (int i = 0; i < _items.length; ++i) {
      if (_items[i].key == key) return i;
    }
    return -1;
  }

  bool reorderCallback(Key item, Key newPosition) {
    int draggingIndex = _indexOfKey(item);
    int newPositionIndex = _indexOfKey(newPosition);

    // if (newPositionIndex % 2 == 1)
    //   return false;

    final draggedItem = _items[draggingIndex];
    setState(() {
      debugPrint(
          "Reordering " + item.toString() + " -> " + newPosition.toString());
      _items.removeAt(draggingIndex);
      _items.insert(newPositionIndex, draggedItem);
    });
    return true;
  }

  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: ReorderableList(
            onReorder: this.reorderCallback,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (BuildContext c, index) => new Item(_items[index]),
            )));
  }
}

class Item extends StatelessWidget {
  Item(this.itemData);

  final ItemData itemData;

  @override
  Widget build(BuildContext context) {
    return ReorderableItem(
        key: itemData.key,
        child: Container(
            decoration: BoxDecoration(color: Colors.white),
            child: new Text(itemData.title,
                style: Theme.of(context).textTheme.subhead),
            padding:
                new EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0)));
  }
}
