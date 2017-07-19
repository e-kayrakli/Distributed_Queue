use GlobalAtomicObject;
use Time;

config const nOpsPerLocale = 1000000;
config const isGlobalAtomic : bool;
config param useOnStmt : bool;
config const isSync : bool;
config const logNodes : bool;

proc syncTest() {
  class node {
    var idx : int;
    var next : node;
  }

  class list {
    var head : node;
    var tail : node;
  }
  var lst = new list();
  var lock$ : sync bool;

  var time = new Timer();
  time.start();
  coforall loc in Locales do on loc {
    coforall tid in 0 .. #here.maxTaskPar {
      for i in 1 .. nOpsPerLocale / here.maxTaskPar {
        var n = new node();
        if useOnStmt {
          on lst {
            lock$ = true;
            if lst.tail == nil {
               lst.tail = n;
               lst.head = n;
            } else {
               lst.tail.next = n;
               lst.tail = n;
            }
            lock$;
          }
        } else {
          lock$ = true;
          if lst.tail == nil {
             lst.tail = n;
             lst.head = n;
          } else {
             lst.tail.next = n;
             lst.tail = n;
          }
          lock$;
        }
      }
    }
  }
  time.stop();

  return time.elapsed();
}

proc gaoTest() {
  class node {
    var fence : atomic int;
    var next : node;
  }

  class list {
    var tail : GlobalAtomicObject(node);
    var head : GlobalAtomicObject(node);
  }
  var lst = new list();

  var time = new Timer();
  time.start();
  coforall loc in Locales do on loc {
    coforall tid in 0 .. #here.maxTaskPar {
      for i in 1 .. nOpsPerLocale / here.maxTaskPar {
        var n = new node();
        var tailNode = lst.tail.exchange(n);
        if tailNode == nil {
           lst.head.write(n);
        } else {
           tailNode.next = n;
           tailNode.fence.fetchAdd(1); /* Full memory barrier */
        }
      }
    }
  }
  time.stop();

  return time.elapsed();
}

config const nTrials = 4;

proc main() {

  writeln("NumLocales: ", numLocales);

  if isGlobalAtomic {
    var gaoTimes : [{1 .. nTrials}] real;
    for i in 1 .. nTrials {
      if i == 1 then gaoTest();
      gaoTimes[i] = gaoTest();
      writeln("GlobalAtomicObject Trial ", i, "/", nTrials, ": ", gaoTimes[i]);
    }
    var gaoAvg = (+ reduce gaoTimes) / nTrials;
    writeln("GlobalAtomicObject Avg: ", gaoAvg);
  }

  if isSync {
    var syncTimes : [{1 .. nTrials}] real;
    for i in 1 .. nTrials {
      if i == 1 then syncTest();
      syncTimes[i] = syncTest();
      writeln("Sync Trial ", i, "/", nTrials, ": ", syncTimes[i]);
    }
    var syncAvg = (+ reduce syncTimes) / nTrials;
    writeln("Sync Avg: ", syncAvg);
  }
}
