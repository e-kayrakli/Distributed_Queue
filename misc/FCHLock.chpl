use GlobalAtomicObject;
use LocalAtomicObject;
use ReplicatedDist;
use Time;


/*
  The Flat-Combining Hierarichal Lock

  A Work-In-Progress - Do Not Use!
*/

class FCHFunctor {
  type dataType;

  proc this(ref data : dataType) {
    halt("Bad Functor (by Ref)...");
  }

  /*proc this(data : dataType) where isClass(dataType) {
    halt("Bad Functor...");
  }*/
}

class FCHLocalNode {
  type dataType;
  var request : FCHFunctor(dataType);
  var wait : atomic bool;
  var completed : bool;
  var next : FCHLocalNode(dataType);
};

class FCHGlobalNode {
  var isCombiner : atomic bool;
  var fence : atomic uint;
  var next : FCHGlobalNode;
}

class FCHLock {
  var data;
  var combinerList : GlobalAtomicObject(FCHGlobalNode);

  // We maintain local wait list that a combiner must serve on it's own node.
  var perLocaleSpace = { 0 .. 0 };
  var perLocaleDomain = perLocaleSpace dmapped ReplicatedDist();
  var publicationList : [perLocaleDomain] LocalAtomicObject(FCHLocalNode(data.type));
  var recycledCombinerNode : [perLocaleDomain] FCHGlobalNode;
  var combinerStatus : atomic bool;

  /*
    Register ourselves as a potential combiner for our node.
    Returns the node and descriptor needed to advance us.
  */
  proc waitForCombiner() : FCHGlobalNode {
    // Create our node and register it.
    var node = recycledCombinerNode[0];
    if node == nil {
      node = new FCHGlobalNode();
      recycledCombinerNode[0] = node;
    }
    node.next = nil;
    node.isCombiner.write(false);
    var prev = combinerList.exchange(node);

    // Someone else is ahead of us, append ourselves and wait...
    if prev != nil {
      prev.next = node;
      prev.fence.fetchAdd(1);
      node.isCombiner.waitFor(true);
    }

    // We are now the combiner... We need to keep track of our node and descriptor
    // to unregister ourselves later, so return it.
    return node;
  }

  /*
    Relinquish duty as sole combiner for our node and allow other nodes to have a go.
  */
  proc giveUpCombiner(node) {
    // If we are the only one, then we attempt to set the tail to nil to make it
    // easier for combiners to register later.
    node.fence.fetchAdd(1);
    if node.next == nil {
      // Fast path: Next task attempting to become the combiner will easily
      // have no problems.
      if combinerList.compareExchange(node, nil) {
        return;
      }

      // At this point, someone has already set themselves as the tail (but has not
      // yet appended themselves) so we must wait until they finish.
      var next : FCHGlobalNode;
      while true {
        node.fence.fetchAdd(1);
        next = node.next;

        // They've finished... Set them as combiner...
        if next != nil {
          next.isCombiner.write(true);
          return;
        }
        chpl_task_yield();
      }
    }
    node.next.isCombiner.write(true);
  }


  proc synchronize(request : FCHFunctor(data.type)) {
    var nextNode = new FCHLocalNode(data.type);
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node so that the next task can add theirs safely,
    // then fill out the node we assigned to use
    var currNode = publicationList[0].exchange(nextNode);
    currNode.request = request;
    currNode.next = nextNode;

    // Spin until we are finished...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread
    if currNode.completed {
      delete currNode;
      return;
    }

    /*var ourNode = waitForCombiner();*/

    // If we are not marked as complete, we *are* the combiner thread
    var tmpNode = currNode;
    var tmpNodeNext : FCHLocalNode(data.type);
    const maxServed = here.maxTaskPar;
    var served = 0;

    while (tmpNode.next != nil && served < maxServed) {
      served = served + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      tmpNode.request(data);

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    /*giveUpCombiner(ourNode);*/

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner.
    tmpNode.wait.write(false);
    delete currNode;
  }

  proc FCHLock(data) {
    forall loc in Locales {
      on loc {
        publicationList[0].write(new FCHLocalNode(data.type));
      }
    }
  }
}

proc main() {
  var nElems = 1000000;

  class MultiplyFunctor : FCHFunctor {
    var mult = 2;
    proc this(ref data : dataType) {
      data = data * mult;
    }
  }

  class PrinterFunctor : FCHFunctor {
    proc this(ref data : dataType) {
      writeln(data);
    }
  }

  var timer = new Timer();

  timer.clear();
  var lock = new FCHLock(data=1);
  timer.start();
  coforall loc in Locales {
    var func = new MultiplyFunctor(int);

      on loc {
        var node = lock.waitForCombiner();
        forall i in 1 .. nElems {
          lock.synchronize(func);
        }
        lock.giveUpCombiner(node);
      }
  }
  lock.synchronize(new PrinterFunctor(int));
  timer.stop();
  writeln("FCHLock (Fetch&Multiply) ~ ", timer.elapsed(), " seconds");


  timer.clear();
  var counter : atomic uint;
  counter.write(1);
  timer.start();
  coforall loc in Locales do on loc do forall i in 1 .. nElems do {
    while true {
      var count = counter.read();
      if counter.compareExchangeStrong(count, count * 2) then break;
    }
  }
  timer.stop();
  writeln("Atomic (Fetch&Multiply) ~ ", timer.elapsed(), " seconds");

  class syncCounterWrapper {
    var x : int;
  }
  timer.clear();
  var counterLock$ : sync bool;
  var syncCounter = new syncCounterWrapper(x=1);
  timer.start();
  coforall loc in Locales do on loc do forall i in 1 .. nElems do {
    counterLock$ = true;
    syncCounter.x = syncCounter.x * 2;
    counterLock$;
  }
  timer.stop();
  writeln("Sync (Fetch&Multiply) ~ ", timer.elapsed(), " seconds");
}
