use CyclicDist;
use LocalAtomicObject;
use Queue;
use SyncQueue;
use Random;
use ReplicatedDist;

/*
  A distributed FIFO queue.

  The queue makes use of a counter to cycle and to properly load-balance across
  all registered locales, where each locale has a per-locale queue. The per-locale
  queue further ensures a FIFO ordering, ensuring that any extra items enqueued
  after cycling through can be dequeued in the same order. This is because a FIFO
  of FIFOs is still a FIFO. For a useful diagram...

  Imagine there are N locales, where we denote a head at position Y as H_Y and a
  tail at position Z as T_Z.

  The Queue is empty:
    H_0, T_0 -- Note that the position just needs to be the same...

    In this case, if the head and tail are equal, then a dequeue will fail if it was read
    as such at the time, but an enqueue would be able to advance the tail.

  Enqueue:
    H_0, T_1

    In this case, the locale at position 0 mod N would end up with an enqueue.

  Dequeue:

    H_1, T_1

    There are two things that can happen: T_0 has not yet finished being enqueued,
    upon which it will spin until it has finished (I.E: by repeatedly attempting to dequeue
    if it is non-blocking), or it has finished, upon which will do a simple dequeue.
    Notice as well that while both Enqueue and Dequeue can be in progress, other tasks
    can advance the head and tail to obtain their next index. Overlapping operations are
    discussed below.

  The position can be obtained and updated in a non-blocking fashion, using the
  available atomic primitives such as Compare-And-Swap, of which is the only global
  synchronization actually needed. Since the only global synchronization is non-blocking,
  lock-free, and wait-free, this ensures scalability. To reduce communication as well,
  we perform atomically updating and obtaining the index on the locale owning the queue.
  The head and tail of the global counter denotes a sort of 'promise' that a task will,
  on enqueue add a new item, and on dequeue remove an existing item. Given that the global counter
  is linearizable, we know that the index obtained from the current counter is correct at the time
  it was retrieved, and enforcing that all tasks uphold such a promise will ensure it always remains
  correct.

  As each per-locale queue is updated on the locale it belongs to, meaning majority
  of the computation can be performed remotely, it ensures that the workload is very
  well balanced. In the cases of overlapping operations on a local queue, a non-blocking
  queue is the most optimal, as this would allow enqueues to be fully non-blocking and
  lock-free, as the counter is proven non-blocking, lock-free, and wait-free.
  While enqueues can be non-blocking (depending on queue implementation), a dequeues
  cannot be as it is possible for an enqueue to 'promise' but not finish before another
  dequeue on that node occurs. Due to this, a dequeue would need to spin as the index
  assigned to it is correct and that *one* of the enqueuers for that index has not completed
  but will eventually. In this regard, dequeue is *mostly* non-blocking.

  In terms of correctness for the per-locale queues, we know that we have a 'promise'
  to perform some task, but beyond that it is not guaranteed that the order that
  tasks that received their indices will perform them in the same order. That is
  if a task t1 obtained its indice before t2, and both t1 and t2 hash to the same index (read: locale),
  it is possible that t2 can complete its operation before t1, therefore it is non-deterministic
  in terms of order of completion. However, because overlapping concurrent operations
  are non-deterministic in nature, and that the FIFO ordering is in fact preserved on some
  level (on the per-locale queue), it is still a valid operation and transparent from the outside.
  Considering that PGAS ensures that multi-locale operations finish before continuing, we can
  verify that indeed an operation will finish in-order on a sequential task. The only way for
  operations to overlap is through overlapping tasks. Compare to a normal synchronized queue,
  and even if it is possible that t1 began its operation before t2, it is still possible for t2
  to obtain the lock before t1 in cases of unexpected delays. Therefore, the non-deterministic
  nature of the per-locale queues are nothing special, and if anything increase overall concurrency.
*/

config const NODES_PER_LOCALE = 512;

class WaitListNode {
  // Are we in use?
  var inUse : atomic bool;

  // Our served queue index
  var idx : int = -1;

  // If wait is false, we spin
  // If wait is true, but completed is false, we are the new combiner thread
  // If wait is true and completed is true, we are done and can exit
  var wait : atomic bool;
  var completed : bool;

  // Descriptor to next node in list. If it is 0, it is equivalent to nil
  var nextIdx : uint;
}

class DistributedFIFOQueue : Queue {
  // TODO: Let user specify their own background queue...

  // Two monotonically increasing counters used in deciding which locale to choose from
  var globalHead : atomic uint;
  var globalTail : atomic uint;

  // per-locale data
  var perLocaleSpace = { 0 .. 0 };
  var perLocaleDomain = perLocaleSpace dmapped Replicated();
  var localQueues : [perLocaleDomain] Queue(eltType);

  // Head wait-list needed to ensure forward progression and eliminate contention...
  var descriptorTable : [Locales.domain][{1 .. NODES_PER_LOCALE}] WaitListNode;
  var descriptorAllocIndexDom = {0 .. 0} dmapped Replicated();
  var descriptorAllocIndex : [descriptorAllocIndexDom] atomic uint;
  var headDescriptor : atomic uint;

  // TODO: Custom Locales
  proc DistributedFIFOQueue(type eltType) {
    var numDescriptors : atomic int;
    forall loc in Locales {
      on loc {
        localQueues[0] = new SyncQueue(eltType);
        numDescriptors.add(here.maxTaskPar);
      }
    }

    // Allocate descriptors...
    forall localeIdx in Locales.domain {
      for descrIdx in 1 .. NODES_PER_LOCALE {
          descriptorTable[localeIdx][descrIdx] = new WaitListNode();
      }
    }

    // Initially set for our locale...
    headDescriptor.write(getNextDescriptorIndex());
  }

  // Upper bits have locale index encoded... Lower bits have index of node for that locale...
  inline proc getNextDescriptorIndex() : uint {
    var lower = descriptorAllocIndex[0].fetchAdd(1) % NODES_PER_LOCALE : uint + 1;
    var upper = here.id;
    return upper << 32 | lower;
  }

  // Upper 32 bits
  inline proc getLocaleIndex(descrIdx) : uint {
    return descrIdx >> 32;
  }

  // Lowest 32 bits
  inline proc getNodeIndex(descrIdx) : uint {
    return descrIdx & 0xFFFFFFFF;
  }

  // Obtain node from descriptor...
  inline proc getDescriptorNode(descrIdx) : WaitListNode {
    return descriptorTable[getLocaleIndex(descrIdx) : int][getNodeIndex(descrIdx) : int];
  }

  proc getNextHeadIndex() : int {
    // We want to ensure we do not serve more than the number of tasks
    // that can potentially run on a node. This is so we don't end up serving repeated
    // requesters and get starved, and (presumably) it is large enough to serve
    // most use-cases and scenarios.
    var requestsServed = 0;

    // Our dummy node, of which we need to recycle. We need to spin until its available.
    var nextNodeIdx = getNextDescriptorIndex();
    var nextNode = getDescriptorNode(nextNodeIdx);
    // Test-And-Test-And-Set...
    while true {
      nextNode.inUse.waitFor(false);
      if nextNode.inUse.compareExchangeStrong(false, true) {
        break;
      }
    }

    // Setup our dummy node...
    // TODO: Find a way to have this be one communication?
    nextNode.wait.write(true);
    nextNode.completed = false;
    nextNode.nextIdx = 0;

    // Register our dummy node...
    var currNodeIdx = headDescriptor.exchange(nextNodeIdx);
    var currNode = getDescriptorNode(currNodeIdx);
    currNode.nextIdx = nextNodeIdx;

    // Spin until we are alerted...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread. We have officially been served...
    if currNode.completed {
      var retval = currNode.idx;
      currNode.inUse.write(false);
      return retval;
    }

    // TODO: Perhaps try jumping to Locale #0?
    // If we are not marked as complete, we *are* the combiner thread, so begin
    // serving everyone's request. As the combiner, it is our sole obligation to
    // contest for our global lock.
    var tmpNode = currNode;
    var tmpNodeNext : WaitListNode;
    const maxRequests = here.maxTaskPar;

    while (tmpNode.nextIdx != 0 && requestsServed < maxRequests) {
      requestsServed = requestsServed + 1;
      // Ensures we do not touch after the node is recycled by owning task...
      tmpNodeNext = getDescriptorNode(tmpNode.nextIdx);

      // Update head...
      var _tail = globalTail.read();
      var _head = globalHead.read();
      if _head != _tail {
        globalHead.write(_head + 1);
        tmpNode.idx = (_head % numLocales : uint) : int;
      }

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner. Also recycle our node...
    tmpNode.wait.write(false);
    var ourIdx = currNode.idx;
    currNode.inUse.write(false);
    return ourIdx;
  }

  proc enqueue(elt : eltType) {
    var idx : int = (globalTail.fetchAdd(1) % numLocales : uint) : int;
    on Locales[idx] {
      localQueues[0].enqueue(elt);
    }
  }

  proc dequeue() : (bool, eltType) {
    var (hasElem, elem) = (true, _defaultOf(eltType));
    var idx = getNextHeadIndex();
    if idx == -1 {
      return (false, _defaultOf(eltType));
    }

    // Now we get our item from the queue
    // Note that at the index given, its possible that an enqueueing task has not
    // finished yet, but we know there *should* be at least something for us, so we can
    // spin until it has what we want.
    on Locales[idx] do {
      var retval : (bool, eltType);
      while !retval[1] {
        retval = localQueues[0].dequeue();

        if (!retval[1]) {
          writeln(here, ": Spinning... HasElem: ", hasElem, ";", "head: ", globalHead.peek(), ", tail: ", globalTail.peek());
          chpl_task_yield();
        }
      }

      (hasElem, elem) = retval;
    }
    return (hasElem, elem);
  }
}

config const nElementsForFIFO = 1000000;
proc main() {
  writeln("Starting FIFOQueue Proof of Correctness Test ~ nElementsForFIFO: ", nElementsForFIFO);
  var queue = new DistributedFIFOQueue(int);
  for i in 1 .. nElementsForFIFO {
    on Locales[i % numLocales] do queue.enqueue(i);
  }

  for i in 1 .. nElementsForFIFO {
    on Locales[i % numLocales] {
      var (hasElem, elem) = queue.dequeue();
      if !hasElem || elem != i {
        halt("FAILED TEST! Expected: ", i, ", Received: ", elem, "; HasElem: ", hasElem);
      }
    }
  }

  writeln("PASSED!");
}
