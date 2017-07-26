proc +=(c : Collection(?eltTyp), e : eltType) : bool {
  return c.add(e);
}

/*
  A data structure.
*/
class Collection {
  type eltType;
  proc add(elt : eltType) : bool {halt();}
  proc remove(elt : eltType) : bool {halt();}
  proc contains(elt : eltType) : bool {halt();}
  proc clear() {halt();}
  proc isEmpty : bool {halt();}
  proc size : int {halt();}
  iter these() : eltType {halt();}

  // TODO: Should this be in a separate interface?
  proc canFreeze() : bool {halt();}
  proc freeze() : bool {halt();}
  proc isFrozen() : bool {halt();}
  proc unfreeze() : bool {halt();}
}

module Queue {
  /*
    A First-In-First-Out data structure.
  */
  class Queue : Collection {
    proc enqueue(elt : eltType) : bool {halt();}
    proc dequeue(elt : eltType) : (bool, eltType) {halt();}
  }

  /*
    A queue that is bounded; may or may not support resizing.
  */
  class BoundedQueue : Queue {
    proc cap : int {halt();}
    proc resize(newSize : int) : bool {halt();}
  }
}

module List {
  /*
    A list that supports some ordering that allows it to be indexed, such as the
    order in which elements are inserted. Note that this does not mean it is a
    sorted list.
  */
  class OrderedList : Collection {
    proc get(idx : int) : (bool, eltType) {halt();}
    proc indexOf(elt : eltType) : int {halt();}
    proc add(idx : int, elt : eltType) : bool {halt();}
    proc split(start : int, end : int = -1) : List(eltType) {halt();}
  }

  /*
    A list that does not allow proper indexing, but does allow removal of arbitary
    elements therein.
  */
  class UnorderedList : Collection {
    proc remove() : (bool, eltType) {halt();}
  }
}
