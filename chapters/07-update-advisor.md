
# Proof Pearl: On the Correctness of Update Advisor

## Motivation

We developed a feature at SourceClear called Update Advisor: a static analysis which determines if a library upgrade would cause breakage when applied to a project.

To summarize the approach: given two consecutive versions of a library, $v1$ and $v2$, and a project that depends on $v1$, we first compute a _semantic_ diff $d$ between the public APIs of $v1$ and $v2$, then check if the project was calling any of the methods changed or removed in $d$; if so, we'd label the upgrade _breaking_. The diff is _semantic_ in the sense that it takes into account calling relationships.

We wanted users to be able to run this analysis on every commit in CI/CD. However, it involved building call graphs for arbitrarily complex open source libraries, which could take significant amounts of time and memory -- we knew this all too well from the experience of building call graphs for our [vulnerable methods analysis](https://arxiv.org/abs/1909.00973).

An obvious solution was to precompute these libraries diffs, but what would we store? Real-world libraries can have hundreds of versions, theoretically as many as [one per commit](https://mvnrepository.com/artifact/com.lihaoyi/ammonite-terminal). Seeing as a diff could be requested for any pair of versions in the range, storing $O(n^2)$ diffs didn't seem like a good idea.

The solution we came up with was to store a linear number of diffs -- only those between consecutive pairs of libraries -- and _compose_ them on request to derive diffs for arbitrary pairs of versions.

## Composing Diffs

What does it mean to compose diffs?

Intuitively, given three versions of a library:

```js
// version 1
function a() {
  return 1;
}
```

```js
// version 2
function a() {
  return 2;
}

function b() {
  return 2;
}
```

```js
// version 3
function b() {
  return 2;
}
```

- Function `a` was changed across versions 1 and 2, and deleted in version 3.
- Function `b` was added in version 2 and remained unchanged after.

The diffs might look like something this:

```yaml
# diff between version 1 and 2
a: CHANGED
b: ADDED
```

```yaml
# diff between version 2 and 3
a: DELETED
b: UNCHANGED
```

Say we're upgrading a user project from versions _1_ to _3_ directly and need the diff between those. The actual diff is:

```yaml
a: DELETED
b: ADDED
```

It seems reasonable that there must be some relationship between the actual diff and the intermediate diffs we saw:

```yaml
a: DELETED = compose(CHANGED, DELETED)?
b: ADDED = compose(ADDED, UNCHANGED)?
```

## A Closer Look

A diff is a set of pairs of an API function and some _diff operation_ which describes how the function changed across versions. We define 5 primitive operations: insertion (I), deletion (D), being changed (C), remaining unchanged (U), and being missing altogether (M).

Let's try to figure out the full composition function. There are a few easy ones, but it gets tricky.

```idris
-- The two from above
compose Changed Deleted = Deleted
compose Inserted Unchanged = Inserted

-- This seems reasonable too: it was a net insertion
compose Inserted Changed = Inserted

-- Hmm...
compose Inserted Deleted = Missing or Unchanged?
compose Deleted Inserted = Unchanged or Changed?

-- Huh?
compose Inserted Inserted = ?
```

This leads us into what it means for the diff composition function to be _correct_. A working specification could be that each pair of inputs has an unambiguous result, given justifcation of some kind, and always approximates the actual diff conservatively. The existence of absurd combinations like `Inserted` and  `Inserted` is another clue that there is some underlying structure to these operations.

That structure is _whether or not the associated API function of each operation is present in the library versions the diff was computed from_. Say we have library versions $v1$, $v2$, and $v3$. Given an API function $f$ and that the diff between $v1$ and $v2$ has the operation `Inserted`, $f$ must have been absent from $v1$ and present in $v2$. The same argument extends to $v2$ and $v3$. Composing the two insertions then makes no sense because $f$ cannot simultaneously be absent and present in $v2$. It's as if `Inserted` has the type `Absent -> Present`, which prevents it from being composed with itself.

With this intuition, we model diff operations as types (in [Idris](https://www.idris-lang.org/), because of its magical ability to finish programs for us). An API function is either absent or present:

```idris
data State = Absent | Present
```

Diff operations have their corresponding types:

```idris
data Diff : State -> State -> Type where
  Insert : Diff Absent Present
  Change : Diff Present Present
  Delete : Diff Present Absent
  Unchanged : Diff Present Present
  Missing : Diff Absent Absent
```

The composition has a familiar type:

```idris
compose : Diff a b -> Diff b c -> Diff a c
```

Case-splitting on `compose` and methodically using [Idris' proof search](http://docs.idris-lang.org/en/latest/tutorial/interactive.html#proofsearch) reveals that there is an unambiguous answer for most cases; furthermore, invalid cases do not even have to be represented, and Idris allows us to leave them out.

```idris
compose Inserted Changed = Inserted
compose Inserted Deleted = Missing
compose Inserted Unchanged = Inserted
compose Changed Deleted = Deleted
compose Deleted Missing = Deleted
compose Unchanged Deleted = Deleted
compose Missing Inserted = Inserted
compose Missing Missing = Missing
```

The only cases which aren't unambiguous are those involving `Changed` or `Unchanged`, because they have the [same type](https://github.com/quchen/articles/blob/master/algebraic-blindness.md). As this is a static analysis, we err on the side of caution and pick the more conservative answer -- whenever possible, assume something is changed. We could formalize this further with a lattice, but seeing as there as there are only five cases left...

```idris
compose Changed Changed = Changed -- only thing that makes sense
compose Changed Unchanged = Changed -- more conservative
compose Deleted Inserted = Changed -- more conservative
compose Unchanged Changed = Changed -- more conservative
compose Unchanged Unchanged = Unchanged -- only thing that makes sense
```

This gives us the following table:

|       | I | C | D | U | M |
|-------|---|---|---|---|---|
| **I** | $\bot$ | I | M | I | $\bot$ |
| **C** | $\bot$ | C | D | C | $\bot$ |
| **D** | C | $\bot$ | $\bot$ | $\bot$ | D |
| **U** | $\bot$ | C | D | U | $\bot$ |
| **M** | I | $\bot$ | $\bot$ | $\bot$ | M |

We are also in a better position now to think about our earlier definitions:

**Why not express C in terms of I and D?** So we don't lose information. For example, if a function is deleted and later inserted, we want to be able to express that it might have changed.

**Why distinguish U and M?** U and M operate on functions with different state.

Composition is not symmetric:

```
I . D = M
D . I = C
```

However, it is associative (proven by exhaustion).

## Conflating U and M

It turns out that we can conflate U and M into a single operation, _unknown_ (?), since they occur in mutually exclusive scenarios. This is useful in practice because when we compute diffs, we want to store just the changes instead of also keeping track of everything that remained unchanged. Also, this doesn't change composition semantics (proven by exhaustion).

Implementing this change gives us the following table.

|       | I | C | D | ? |
|-------|---|---|---|---|
| **I** | $\bot$ | I | ? | I |
| **C** | $\bot$ | C | D | C |
| **D** | C | $\bot$ | $\bot$ | D |
| **?** | I | C | D | ? |

More details are available in our [FSE2018 paper](https://asankhaya.github.io/pdf/Efficient-Static-Checking-of-Library-Updates.pdf).

## Final Thoughts

What does it mean for a function to be [correct](https://en.wikipedia.org/wiki/Correctness_(computer_science))? Correctness only makes sense in the presence of a specification; here ours was that composition was umambiguous, or that the results were at least justifiable, and would always conservatively approximate the actual diff. I'd say we achieved that here, to the end of gaining more confidence that we could build Update Advisor on the idea of diff composition.

The use of formal methods on day-to-day software problems is still costly enough nowadays that it is not mainstream, and often not as readily applicable as simply writing more (types of) tests, as we have done in the earlier parts of this book. Nevertheless, tools like TLA+, Alloy, or even proof assistants and dependently-typed languages like Coq and Idris are essential additions to one's toolbox; they are useful when the kernel of a problem can be distilled and formalized, so we can be sure the software built atop it has robust foundations.
