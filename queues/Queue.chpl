/*
  A data structure that allows for parallel-safe storage of elements. This Queue offers
  two variants: A FIFO Queue, which is the typical First-In-First-Out ordering as to
  be expected of a Queue, and the second being a 'Work' Queue, which does not impose
  any ordering whatsoever and aims to satiate the desire for high performance. Furthermore,
  we offer two further variants for each: a local version that is optimized for a single locale,
  and a distributed version that is optimized for multiple locales.

  A queue may also be 'frozen', in which it becomes immutable. A queue that is immutable
  offers different semantics to one that is mutable; iteration no longer consumes elements,
  allowing for reduction, mapping, and zipping operations with the benefit of parallel-safety,
  as well as making it a proper source for concatenation with other queues.
  A queue may be concatenated with many different sources, from queues, to arrays, to arbitrary
  objects that support serial iteration, which append the other source's elements with
  itself. As well, for queues that are bounded, we have an optional (but default)
  transactional approach to adding elements: either all elements are added, or none are
  (with exceptions).

  If the queue is unbounded, it will always succeed with concatenation,
  but if the queue is bounded it may return false if not enough space is
  available. If the operation is 'transactional', then if there is not enough
  space, none of the elements are added to the queue; if the operation is not
  transactional, it will add as many elements as possible

  Open Question: Queue concatenation semantics...

  <code>
    // FIFO queue with capacity of one item...
    var q1 : Queue(int) = makeBoundedFIFO(1);
    // Adds the element '1' to the queue...
    q1 += 1;
    // Ensures we do not consume it when we concatenate in next step
    q1.freeze();
    // Constructs a new queue that inherits the bounded property of the source queue.
    // Since the elements exceeds the max boundary of the original queue, the bounds
    // of q2 will be 5. Furthermore, the queue will be frozen after creation.
    // Note that, in this way, if we had nice inheritence for records we could easily
    // manage creation of multiple queues like this. What if we had C++ rvalue move-constructors
    // as well to make stuff like this efficient?
    var q2 = q1 + (2,3,4,5);
    // Can also be: + reduce (q1 + 1 + (2,3,4,5))
    // But the above requires memory management of the temporary queue created midway.
    var result = + reduce q2;
  </code>
*/
class Queue {
  /*
    The type of the element.
  */
  type eltType;

  /*
    Adds all elements to the queue, if successful. Elements are added in the
    order they are passed.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: (bool, int)
  */
  proc enqueue(elts : eltType ... ?nElts, transactional : bool = true) : (bool, int)
  {halt();}

  /*
    Adds all elements to the queue. Elements are added in the
    order they in the array.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: (bool, int)
  */
  proc enqueue(elts : [?n] eltType, transactional : bool = true) : (bool, int)
  {halt();}

  /*
    Adds all elements to the queue. Elements are added in a more optimized way
    depending on the underlying type of the queue, and maintain the weakest ordering
    of both queues.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: (bool, int)
  */
  proc enqueue(queue : Queue(eltType), transactional : bool = true) : bool {halt();}

  /*
    Adds all elements yielded by the `iterObj`. In the case where not all
    elements can be added, then it is up to the user to be able to 'replay'
    elements not consumed and dropped. Elements are added in the order they are
    yielded.

    :returns: If the enqueue is successful, and how many elements are added.
    :rtype: (bool, int)
  */
  proc enqueue(iterObj, transactional : bool = true) : bool {halt();}

  /*
    Remove an element from thr queue.

    :returns: If the queue is not empty and the item taken if any.
    :rtype: (bool, eltType)
  */
  proc dequeue() : (bool, eltType) {halt();}

  /*
    Remove at most `nElems` elements from the queue.

    :returns: If the queue is not empty and an array of items taken, if any.
    :rtype: (bool, [] eltType)
  */
  proc dequeue(nElems) : (int, [] eltType) {halt();}

  /*
    Freezes the queue, making it immutable, if supported.

    :returns: If it is a supported operation.
    :rtype: bool
  */
  proc freeze() : bool {halt();}

  /*
    Unfreezes the queue, making it mutable, if supported.

    :returns: If it is a supported operation.
    :rtype: bool
  */
  proc unfreeze() : bool {halt();}

  /*
    Alias for enqueue.
  */
  proc +=(elt : eltType ... ?nElts) : bool {halt();}

  /*
    Alias for enqueue.
  */
  proc +=(queue : Queue(eltType)) {halt();}

  /*
    Feedback needed...
  */
  proc +(elt : eltType ... ?nElts) {halt();}

  /*
    Feedback needed...
  */
  proc +(queue : Queue(eltType)) {halt();}

  /*
    Iterates over all elements in the queue. If the queue is frozen, then iteration
    is read-only in that it will iterate over all elements without consuming them;
    a normal iteration is equivalent to a more optimized sequence of dequeue operation.
  */
  iter these() {halt();}
}

class QueueFactory {
  /*
    (WIP - In Planning)

    Creates a bounded strict First-In-First-Out Queue. The queue utilizes a distributed
    array and provides wait-free dequeue operations. The queue is dervied from the
    'FFQ: A Fast Single-Producer/Multiple-Consumer Concurrent FIFO Queue' seen here:
    http://se.inf.tu-dresden.de/pubs/papers/ffq2017.pdf

    To allow safe concurrent enqueuers, an extension is required that combines the
    high performance of the CC-Synch algorithm to create a derived variant of H-Synch
    I call the 'FCHLock', or the 'Flat Combining Hierarichal Lock'. An extremely helpful
    slide can be seen here:
    https://opencourses.uoc.gr/courses/pluginfile.php/17173/mod_resource/content/0/HY586-Section3.pdf

    :type eltType: Element type

    :arg maxElems: Maximum number of elements in the queue; halts if value is 0.
    :type maxElems: uint

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: [] locales

    :rtype: DistributedBoundedFIFO(eltType)
  */
  proc makeDistributedBoundedFIFO(
    type eltType,
    maxElems : uint = 0,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  // Local variant
  proc makeBoundedFIFO(
    type eltType,
    maxElems : uint = 0
  ) : Queue(eltType) {halt();}

  /*
    Creates an unbounded strict First-In-First-Out Queue. In this queue, each locale is
    given their own queue, which uses a wait-free round robin algorithm to fairly
    distribute computation, memory, and bandwidth and offers scalable performance.
    The queue also allows the user to use their own custom backbone queues but defaults
    to Michael Scott's two-locked synchronized queue, seen here:
    https://www.research.ibm.com/people/m/michael/podc-1996.pdf

    :type eltType: Element type

    :arg targetLocales: Locales to distribute across.
    :type targetLocales: [] locales

    :rtype: DistributedUnboundedFIFO(eltType)
  */
  proc makeDistributedUnboundedFIFO(
    type eltType,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  // Local variant
  proc makeUnboundedFIFO(
    type eltType
  ) : Queue(eltType) {halt();}

  /*
    (WIP - Implementing)

  */
  proc makeDistributedWorkQueue(
    type eltType,
    targetLocales : [] locale = Locales
  ) : Queue(eltType) {halt();}

  // Local variant
  proc makeWorkQueue(
    type eltType
  ) : Queue(eltType) {halt();}
}
