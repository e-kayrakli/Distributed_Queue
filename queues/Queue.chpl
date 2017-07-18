/*
  A data structure that allows for parallel-safe storage of elements. This Queue offers
  two variants: A FIFO Queue, which is the typical First-In-First-Out ordering as to
  be expected of a Queue, and the second being a 'Work' Queue, which does not impose
  any ordering whatsoever and aims to satiate the desire for high performance. Furthermore,
  we offer two variants for each variant: a local version that is optimized for a single locale,
  and a distributed version that is optimized for multiple locales.

  A queue may also be 'frozen', in which no modifications may take place on the queue.
  This allows for 'read-only' iteration semantics and makeas reduction on a queue possible,
  as well as concatenation of multiple frozen queues. A frozen queue can be unfrozen at
  any time as well, but the user must beware that unfreezing a queue while a concurrent operation
  is on-going is implementation-defined.

  A queue may be concatenated with many different sources, from queues, to arrays, to arbitrary
  objects that support serial iteration, which append the other source's elements with
  itself. As well, for queues that are bounded, we have an 'all-or-nothing' transactional
  approach to adding in bulk: either all elements are added, or none are.

  Open Questions:
  1) Frozen Queue Semantics
  2) Bounded Queue problem and transactional enqueues, issue with iterator objects that
    may result in 'dropping' items if we choose 'nothing'.
*/
class Queue {
  /*
    The type of the element.
  */
  type eltType;

  /*
    Adds all elements passed to the queue. If the queue is unbounded, it will always
  */
  proc enqueue(elt : eltType ... ?nElts) : bool {halt();}

  proc enqueue(elt : [?n] eltType) {halt();}

  // Adds in another queue's elements to our own in FIFO order. This operation is *not*
  // lineraizable.
  proc enqueue(queue : Queue(eltType)) {halt();}

  /*

  */
  proc enqueue(iterObj) {halt();}

  // Normal dequeue
  proc dequeue() : (bool, eltType) {halt();}

  // Dequeue *multiple* elements.
  proc dequeue(nElems) : (int, [?n] eltType) {halt();}

  /*
    (WIP - Planning)

    Freezes a queue...
  */
  proc freeze() {halt();}

  /*
    (WIP - Planning)

    Unfreezes a queue...
  */
  proc unfreeze() {halt();}

  proc +=(elt : eltType ... ?nElts) {halt();}

  proc +=(queue : Queue(eltType)) {halt();}

  proc +(elt : eltType ... ?nElts) {halt();}

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
