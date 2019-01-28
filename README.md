# Reorderable List in Flutter

iOS-like proof of concept reorderable list with animations

## Preview

<img src="https://i.imgur.com/nuHCTdP.gif" width="300">

## Getting Started

See `example/lib/main.dart` for example usage

## Highlights

* Smooth reordering animations
* Supports large lists (thousands of items)
* Supports different item heights
* iOS like reordering with drag handle 
* Android like (long touch) reordering 

## Caveats

There are no API stability guarantees. 

If you used previous version of reorderable list keep in mind that `ReorderableListener` now needs to be placed somewhere in `ReorderableItem` hierarchy in order to detect touch and trigger actual reordering (see the example).

Alternatively, you can wrap entire row in `DelayedReorderableListener` to get material like long-press reordering behavior.
