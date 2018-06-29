// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:math' as math;

class Histogram<T> {
  final Map<T, int> _counts = {};

  int get max => _counts.values.fold(0, math.max);
  int get totalCount => _counts.values.fold(0, (a, b) => a + b);

  // Note: Assumes T is int.
  int get sum {
    var result = 0;
    _counts.forEach((value, count) {
      result += (value as int) * count;
    });
    return result;
  }

  T get median {
    // TODO: Super hacky.
    var list = <T>[];
    _counts.forEach((value, count) {
      for (var i = 0; i < count; i++) list.add(value);
    });
    list.sort();
    return list[list.length ~/ 2];
  }

  int add(T object) {
    _counts.putIfAbsent(object, () => 0);
    return ++_counts[object];
  }

  int count(T object) {
    if (!_counts.containsKey(object)) return 0;
    return _counts[object];
  }

  List<T> ascending() {
    var objects = _counts.keys.toList();
    objects.sort((a, b) => _counts[a].compareTo(_counts[b]));
    return objects;
  }

  List<T> descending() {
    var objects = _counts.keys.toList();
    objects.sort((a, b) => _counts[b].compareTo(_counts[a]));
    return objects;
  }
}