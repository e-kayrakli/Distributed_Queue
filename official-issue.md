# Chapel Queue API

Chpldocs Link:

## The QueueFactory

TODO: Describe rationale, such as being resistant to change.

Emulates [Go's 'make'](https://golang.org/pkg/builtin/#make).

## Proposed Additions

### Iteration

TODO: Iterating over elements in the queue

### Open Question: Read-only iteration or 'draining' iteration?

TODO: What would be default if both are added?

Should iteration consume elements in the queue, or should it merely be 'read-only'?
In the case of approving 'frozen' queue semantics, could we alternate between the two?
In the case of disapproving 'frozen' queue semantics, would the potential loss in
performance of acquiring locks be acceptable? If you're against both 'frozen' semantics
and against potential performance loss, would you advocate for a more 'let-it-crash-and-burn'
approach if the user attempts to concurrently use the queue during iteration? Furthermore,
should we offer both types of iteration, and if so which should be the default?

### Transactional Additions

TODO: Enqueue adding in bulk 'all-or-nothing' transactional approach...

#### Open Question: Dropped Objects

TODO: When enqueue fails in transaction, but needs to 'rollback' the state of the
iterator.

### 'Freezing' the Queue

While parallel-safe data structures are desired, not all things can be done in a
parallel manner. For these situations, I believe the queue should be armed with two
states: Mutable (unfrozen) and Immutable (frozen). The benefit is two-fold, as it
enables optimizations such as adopting a more optimistic manner of accessing data
by not contesting for locks meaning more performance, and the user has the benefit
of enforcing immutability across nodes. In my opinion, this is the only 'safe' way
to allow things like reduction, zipper, and mapping iterations without modifying
the queue while allowing a significant performance boost.

#### Open Question: Semantic Changes

TODO: Dual-Mode operation may be too confusing?

#### Open Question: Concurrent Ongoing Operations

TODO: What happens when an operation is ongoing when we attempt to freeze? Halt?
Block? Impl.-Defined behavior?

### Operator Overloading

While some operators can be helpful, others can be rendered irrelevant. Syntactic
sugar operators such as `+=` can help produce more readable code and are easy
to overload. Perhaps the `=` operator can be overloaded to perform a 'clear-and-add'
kind of operation? What say you?

```chpl
var queue : Queue(int) = makeBoundedFIFO(int, 100);
queue = (1,2,3,4,5);
for i in 6 .. 100 do queue += i;
// Interesting application: Queue literals... defaults to fixed-sized bounded queue
var queueLiteral : Queue(int) = (1,2,3,4,5);
```
