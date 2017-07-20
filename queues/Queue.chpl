/*
  A data structure that allows for parallel-safe storage of elements. This Queue offers
  two variants: A FIFO Queue, which is the typical First-In-First-Out ordering as to
  be expected of a Queue, and the second being a 'Work' Queue, which does not impose
  any ordering whatsoever and aims to satiate the desire for high performance. Furthermore,
  we offer two further variants for each: a local version that is optimized for a single locale,
  and a distributed version that is optimized for multiple locales.
*/
class Queue {
  /*
    The type of the element.
  */
  type eltType;

  /*
    Adds all elements to the queue, if successful. Elements are added in the
    order they are passed.

    If the queue is unbounded, it will always succeed with concatenation,
    but if the queue is bounded it may return false if not enough space is
    available.

    :arg elts: Tuple of elements
    :type elts: :type:`eltType`
    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: :type:`(bool, int)`
  */
  proc enqueue(elts : eltType ... ?nElts) : (bool, int) {halt();}

  /*
    Adds all elements to the queue. Elements are added in the order they in the array.
    See the first :proc:`enqueue` for more details.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: :type:`(bool, int)`
  */
  proc enqueue(elts : [?n] eltType) : (bool, int) {halt();}

  /*
    Adds all elements to the queue. Elements are added in a more optimized way
    depending on the underlying type of the queue, and maintain :attr:`this` ordering.
    See the first :proc:`enqueue` for more details.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: :type:`(bool, int)`
  */
  proc enqueue(queue : Queue(eltType)) : (bool, int) {halt();}

  /*
    Adds all elements yielded by the `iterObj`. In the case where not all
    elements can be added, then it is up to the user to be able to 'replay'
    elements not consumed and dropped. Elements are added in the order they are
    yielded. See the first :proc:`enqueue` for more details.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: :type:`(bool, int)`
  */
  proc enqueue(iterObj) : (bool, int) {halt();}

  /*
    Remove an element from thr queue.

    :returns: If the queue is not empty and the item taken if any.
    :rtype: :type:`(bool, int)`
  */
  proc dequeue() : (bool, eltType) {halt();}

  /*
    Remove at most `nElems` elements from the queue.

    :returns: If the queue is not empty and an array of items taken, if any.
    :rtype: :type:`(bool, [?n] eltType)`
  */
  proc dequeue(nElems) : (int, [?n] eltType) {halt();}

  /*
    Freezes the queue, making it immutable, if supported.

    :returns: If it is a supported operation.
    :rtype: :type:`bool`
  */
  proc freeze() : bool {halt();}

  /*
    Unfreezes the queue, making it mutable, if supported.

    :returns: If it is a supported operation.
    :rtype: :type:`bool`
  */
  proc unfreeze() : bool {halt();}

  /*
    Determines if the queue is frozen (immutable).

    :returns: If queue is frozen
    :rtype: :type:`bool`
  */
  proc isFrozen() : bool {halt();}

  /*
    If the queue is frozen, iteration will iterate over all elements in the list
    without consuming them. If the queue is unfrozen, then iteration will consume
    all elements in the list equivalent to a highly optimized sequence of dequeues.

    :yields: Elements in the queue.
    :ytype: :type:`eltType`
  */
  iter these() {halt();}
}

class QueueFactory {
  /*
    Creates a distributed bounded strict First-In-First-Out Queue.

    :type eltType: Element type

    :arg maxElems: Maximum number of elements in the queue; halts if value is 0.
    :type maxElems: uint

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: :type:`[] locales`
  */
  proc makeDistributedBoundedFIFO(
    type eltType,
    maxElems : uint = 0,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  /*
    Creates a local bounded strict First-In-First-Out Queue.

    :type eltType: Element type

    :arg maxElems: Maximum number of elements in the queue; halts if value is 0.
    :type maxElems: :type:`uint`
  */
  proc makeBoundedFIFO(
    type eltType,
    maxElems : uint = 0
  ) : Queue(eltType) {halt();}

  /*
    Creates a distributed unbounded strict First-In-First-Out Queue.

    :type eltType: Element type

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: :type:`[] locales`
  */
  proc makeDistributedUnboundedFIFO(
    type eltType,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  /*
    Creates a local unbounded strict First-In-First-Out Queue.

    :type eltType: Element type
  */
  proc makeUnboundedFIFO(
    type eltType
  ) : Queue(eltType) {halt();}

  /*
    Creates a distributed work stealing unbounded queue.

    :type eltType: Element type

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: :type:`[] locales`
  */
  proc makeDistributedBalancedQueue(
    type eltType,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  /*
    Creates a distributed work stealing unbounded queue.

    :type eltType: Element type

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: :type:`[] locales`
  */
  proc makeBalancedQueue(
    type eltType
  ) : Queue(eltType) {halt();}
}
