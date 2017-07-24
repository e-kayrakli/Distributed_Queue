# Chapel Queue API

Link to the chpldocs can be seen [here](https://louisjenkinscs.github.io/Distributed_Queue/modules/queues/Queue.html).

## The QueueFactory

Emulates [Go's 'make'](https://golang.org/pkg/builtin/#make).

### Open Questions

* Should we maintain an interface at all?
   * If not, then should we make each data structure a `record` instead?
   * Resilience to Change vs Flexibility

## Proposed Additions

### 'Freezing' the Queue

While parallel-safe data structures are desired, not all things can be done in a
parallel-safe manner. For these situations, I believe the queue should be armed with two
states: Mutable (unfrozen) and Immutable (frozen). The benefit is two-fold, as it
enables optimizations such as adopting a more optimistic manner of accessing data
by not contesting for locks meaning more performance, and the user has the benefit
of enforcing immutability across nodes without need for external synchronization. 
I believe that this is the only 'safe' way to allow things like reduction, zipper, 
and mapping iterations without modifying the queue while providing a significant performance boost.

#### Open Questions

* Are the semantic changes of having dual-mode operations too confusing?
* What happens to concurrent ongoing operations while freezing/unfreezing the queue?
   * Should we halt? Block until unfrozen? Make it 'implementation-defined' behavior?

### Iteration

Iteration allows for the queue to become more than just a simple container, making things
such as reductions, zipper-iterables, and mappings possible.

### Open Questions

* Should we allow read-only iteration or 'draining' iteration, perhaps both?
   * Proposal: Based on if the queue is 'frozen' or 'unfrozen'.

### Transactional Additions

Enqueue adding in bulk 'all-or-nothing' transactional approach.

#### Open Questions

* Should we allow adding non-scalar types? From other queues

### Operator Overloading

While some operators can be helpful, others can be rendered irrelevant. Syntactic
sugar operators such as `+=` can help produce more readable code and are easy
to overload. Perhaps the `=` operator can be overloaded to perform a 'clear-and-add'
kind of operation? What say you?

```chpl
var queue : Queue(int) = makeBoundedFIFO(int, 100);
queue = (1,2,3,4,5);
for i in 6 .. 100 do queue += i;
// Would it be possible to create 'Queue literals' this way... 
// It would default to a fixed-sized bounded queue with the items given to it
// if the left hand side is nil? Furthermore, would it be useful?
var queueLiteral : Queue(int) = (1,2,3,4,5);
```
