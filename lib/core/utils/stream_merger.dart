import 'dart:async';

Stream<List<T>> mergeListStreams<T>(
  Stream<List<T>> streamA,
  Stream<List<T>> streamB,
  int Function(T, T) compare,
) {
  final controller = StreamController<List<T>>();
  List<T> lastA = [];
  List<T> lastB = [];
  bool hasA = false;
  bool hasB = false;

  StreamSubscription? subA;
  StreamSubscription? subB;

  void emit() {
    final Map<String, T> uniqueMap = {};
    
    String getId(dynamic item) {
      try {
        return item.id.toString();
      } catch (_) {
        return item.hashCode.toString();
      }
    }

    for (var item in lastA) {
      uniqueMap[getId(item)] = item;
    }
    for (var item in lastB) {
      uniqueMap[getId(item)] = item;
    }

    final merged = uniqueMap.values.toList();
    merged.sort(compare);
    controller.add(merged);
  }

  subA = streamA.listen(
    (data) {
      lastA = data;
      hasA = true;
      emit();
    },
    onError: controller.addError,
    onDone: () {
      if (controller.isClosed) return;
      if (!hasB) controller.close();
    },
  );

  subB = streamB.listen(
    (data) {
      lastB = data;
      hasB = true;
      emit();
    },
    onError: controller.addError,
    onDone: () {
      if (controller.isClosed) return;
      if (!hasA) controller.close();
    },
  );

  controller.onCancel = () {
    subA?.cancel();
    subB?.cancel();
  };

  return controller.stream;
}
