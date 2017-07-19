use LocalAtomicObject;
use Queue;

/*
  A prototype for a global list that makes use of global atomics by allowing enqueue
  to be effectively wait-free but 'lazy' in that, while it remains in the correct order,
  a node will not show up until it or it's predecessor finishes registering their own.
  A node is already visible will always be visible, but any 'new' ones are in a transient
  state. Dequeue would require a Compare-And-Swap strategy which will not scale, and hence
  forth uses Flat Combination to allow mutual exclusion as necessary while remaining relatively
  scalable.

  Note as well, this list provides next to no guarantees even for sequential operation; you can
  add an element to the list and then poll it for it to come back empty because a predecessor
  did not finish. The usefulness of this list is limited, but may be useful when you know
  when the list should and should not be empty.
*/

class LazyListNode {
  type eltType;
  var elt : eltType;
  var fence : atomic uint;
  var next : LazyListNode(elem.type);
}

class LazyList : Queue {
  var nElems : atomic int;
  var head = LocalAtomicObject(LazyListNode(eltType));
  var tail = LocalAtomicObject(LazyListNode(eltType));

  proc enqueue(elt : eltType) {
    var node = new LazyListNode(eltType, elt);

    while true {
      if nElems.fetchAdd(1) >= 0 then break;
    }

    var prev = tail.exchange(node);
    if prev == nil {
      head.write(node);
    } else {
      prev.next = node;
      prev.fence.fetchAdd(1);
    }
  }


  proc dequeue() : (bool, eltType) {
    if nElem.fetchSub(1) <= 0 {
      return (false, _defaultOf(eltType));
    }

    // Bottleneck...
    while true {
      var h = head.read();
      if h == nil {
        chpl_task_yield();
        continue;
      }
      head.compareExchangeStrong(h, h.next);
    }
  }
}
