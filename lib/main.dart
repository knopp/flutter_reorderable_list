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
        dividerColor: new Color(0x50000000),
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
    _items = new List();
    for (int i = 0; i < 100; ++i)
      _items.add(new ItemData("List Item " + i.toString(), new ValueKey(i)));
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
      debugPrint("Reordering " + item.toString() + " -> " + newPosition.toString());
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
        body: Column(children: <Widget>[
          Expanded(
              child: ReorderableList(
                  onReorder: this.reorderCallback,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (BuildContext c, index) => new Item(
                        data: _items[index],
                        first: index == 0,
                        last: index == _items.length - 1),
                  )))
        ]));
  }
}

class Item extends StatelessWidget {
  Item({this.data, this.first, this.last});

  final ItemData data;
  final bool first;
  final bool last;

  BoxDecoration _buildDecoration(BuildContext context, bool dragging) {
    return BoxDecoration(
        border: Border(
            top: first && !dragging ? Divider.createBorderSide(context) : BorderSide.none,
            bottom:
                last && dragging ? BorderSide.none : Divider.createBorderSide(context)));
  }

  Widget _buildChild(BuildContext context, bool dragging) {
    return Container(
        decoration: BoxDecoration(color: dragging ? Color(0xD0FFFFFF) : Colors.white),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(data.title, style: Theme.of(context).textTheme.subhead)),
            Icon(Icons.reorder, color: dragging ? Color(0xFF555555) : Color(0xFF888888)),
          ],
        ),
        padding: new EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0));
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableItem(
        key: data.key, childBuilder: _buildChild, decorationBuilder: _buildDecoration);
  }
}
