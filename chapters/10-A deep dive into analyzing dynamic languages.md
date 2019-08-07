# A deep dive into analyzing dynamic languages

Analyzing programs written in dynamic languages presents some unique challenges. Here's a bit of a deep dive into how we do it. First, what exactly is a dynamic language? For the purposes of this article, we will define a dynamic language as one where types are checked for safety only at runtime. Languages like Ruby, Python, and JavaScript follow this model, in contrast with static languages like Java and C#, where type safety is ensured at compile time.

The analysis of programs written in dynamic languages is challenging for a number of reasons:

* **Impurity:** Some dynamic languages allow and encourage side effects. Local variables are reassignable, data structures in the heap are mutable, and so on. For reasons of *expressiveness*, even meta-language constructs like prototypes and metaclasses are reified into data structures, and are thus subject to the same rife mutability. This makes it harder to reason about programs.
* **Higher-order functions:** These languages support defining functions that can operate on other functions, e.g. the `functools` module in Python. This complicates things, as control flow analysis becomes dependent on data flow analysis.
* **Coercions:** A coercion is the translation of value of one type into value of another type. Python and Ruby have coercions for numeric values, while JavaScript has more complicated coercion rules. When analyzing a program, it is difficult to tell if an implicit coercion was intended or not, complicating reasoning.

### A core dynamic language

In the interest of keeping our discussion language-agnostic, let's consider a simple core language which illustrates these challenges.

```
<constant> ::= true | false | integers | strings


<val> ::= <constant>
| func (x, …) { e }          [function]
| { f : v, … }               [object literal]


<exp> ::= <val> 		
| x                          [variable]
| e(f)                       [call]
| e = f                      [assignment]
| let x = e                  [binding]
| if e then f else g         [if-then-else]
| e.f                        [field load]
| e.f = e                    [field store]
| op e                       [unary operator]
| e op e                     [binary operator]
| e ; f                      [sequencing]
```


This can be thought of as a tiny subset of JavaScript, but it is representative of Ruby or Python as well.

Here's an example program written in this language.

```js
let pair = { x: 12, y: 30 };
let fst = func(arg) { arg.x };
let snd = func(arg) { arg.y };
fst(pair) + snd(pair)
```

It returns `42` when run.

### Types

Let's imagine trying to analyze this program. What can we say about it without executing it?

A simple static analysis that we're probably all familiar with is static type inference. Can we annotate the variables and fields in this program with tags representing the set of values that they may have at runtime?

Some problems immediately stand out. For example, what is the type of `fst`? It's the same as the type of the `x` property of some object `arg` -- but we don't know what `arg` looks like. How do we give `x` a type?

### Union types

The core language allows values of three primitive types (boolean values, integers, and strings) and two composite types: one is `object`, and the other is the type of functions, which we'll express as `a → b`.

Variables in this language can have any of these types, so we can't give a variable just one; we'll have to give it *all* of them. We'll use a *union* of types to express this.

```js
bool | int | str | obj | function
```

We can say that every variable has this type without having to execute the program. Are we done?

Kind of, but this isn't very useful. It's not at all specific to the different programs we want to write. We want to do better than this and infer more specific types where possible -- but this gives us a starting point.

### Dependencies

Remember how we needed to know what `arg` looked like in order to know what `x` looked like? Just as the value of `x` depends on the value of `arg`, the type of `x` depends on the type of `arg`. There are dependencies between the types of things in the program. This is something we can wrangle information out of.

We'll write an interpreter that goes over the program as an actual interpreter might, respecting the dependencies between values -- only we won't actually evaluate the program. Instead, we'll just gather information about what the types look like.

Let's look at a few examples.

```js
let a = true;
a = 1
```

After the first line, we can conclusively say that `a` has type `bool`. We want to get as specific as possible, so we'll leave at that.

After the second line, we know that `a` could also be of type `int`. We'll generalise this and give it the type `bool | int`. Any time we see `a`, we have to consider the possibility that it might have either of these types.

So far so good. How about when there are functions involved?

```js
let f = func(x) { x + 1 }
```

`x` must be numeric, because it has to support an addition operation... or it might be `string`, if we support implicitly coercing `1` to a string, making `+` stand for string concatenation. The result of `f` should be of the same type, so the type of `f` might be `(int | string) → (int | string)`. The use of the variable gave us a clue about its type here.

```js
let id = func(x) { x }
```

Hmm, we don't have any clues here. What can we say about this function? Nothing, really, since `id` might be called with any value. Returning a union of all possible types would be correct, but not very useful. If the entire program is as follows:

```js
let id = func(x) { x };
id(1)
```

It would be obvious to a developer that `id` has type `int → int`, and we should be able to do at least as well.

We need a way to defer our decisions about types: a way to express that the type has a certain shape, but leave blanks to be filled in later. We might say that `id` in isolation has type `a → a` for some concrete `a` that we don't know yet. That seems decent. When we get to the rest of the program, we'll be able to replace `a` with something.

`a` is a *concrete type variable*. It's useful as a placeholder. With all of this combined, we can give reasonably specific types to the programs in this core language.

What we've described very informally is an approach known as abstract interpretation: we go over the program as an interpreter might, computing some abstraction of its actual result. That happens to be types here.

What we can do next is to develop a *semantics* for our core language: specify the meaning of programs written in it very precisely. For example, we can say where type variables can appear, and how they can be filled in, how exactly types may be coerced to other types, and so on.

### Control flow analysis

Now that we've managed to infer types for the values in our programs, we'll continue on to something more interesting: given a program, we want to produce a graph that represents its control flow.

Why is this useful? It enables other practical analyses, like [*taint analysis*](https://blog.sourceclear.com/comparing-vulnerable-methods-with-static-analysis/), which checks if our programs are using external input in unsafe ways.

```js
let g = func(x) { x };
let f = func(x) { g(x) };
f(1)
```

The control flow graph for this program would look like this.

It's rather simple so far: we put an edge between `f` and `g`, because they have a caller-callee relationship. The edge is directed, pointing from `f` to `g`, because `f` calls `g`. The nodes in our program are the functions. To keep things simple, we'll assume that functions in our core language always have some canonical name, i.e. we won't consider higher-order functions yet.

How accurate should this call graph be? It should certainly be conservative: if there is a possible execution of the program that involves a call of `b` from `a`, there should be an edge in the call graph between `a` and `b`. A simple solution to this is… a complete graph; maximally conservative, accounting for every possibility, always correct, but really not that useful. The ideal call graph is minimal.

We may wonder why types are needed to build a call graph. It seems obvious enough that `f` and `g` are related, once we know that they are functions. What we really need is *name resolution*: figuring out what the variables in the program refer to.

```js
let f = func(x) { g(x) }; // what is g?
```

If we look at just one statement in the program in isolation, it may not necessarily make sense; we need to know its *context* to figure out what the `g` in it means.

As part of the process of inferring types, the *context* is constructed in table form. It may look something like this.

| Name | Type | Reference |
|---|---|---|
| f | a → a | g |
| g | a → a |  |

It maps names to their types, but it may be augmented with other information, such as the fact that `f` makes a reference to some `g` in the context, whatever that is.

Given this information, constructing a call graph is now a matter of piecing together the information from the table.

### Real-world dynamic languages

We kept our core language deliberately simple, so we could focus on the essence of problems, without having to be bogged down with details. Getting these ideas to work on real-world dynamic languages, however, requires lots of extensions. We'll cover a few of them the issues that one would face in practice.

### Modules

Python packages are contained in modules, which act as a namespaces for source code. A typical Python script imports names from a bunch of modules.

```python
# main.py
from django.utils import formats

if __name__ == '__main__':
    formats.get_format()
```

We can simulate modules with the objects in our core language. The django module might be represented in it as a nested object, for example:


```js
let get_format = func(arg) { 1 }
let django = { utils: { formats: { get_format: get_format } } };
```

If we're able to find the source code of `django` as we're scanning `main.py`, we can resolve names using all the techniques we've developed so far.

### Overloaded operators

Ruby allows operator overloading. It's part of what allows nice-looking DSLs.

```ruby
class Vec
  attr_reader :elements

  def initialize(*elts)
    @elements = elts
  end

  # element-wise addition
  def +(other)
     @elements.zip(other.elements).map { |x, y| x + y }
  end

  def to_s
    @elements.to_s
  end
end


a = Vec.new(1, 2, 3)
b = Vec.new(4, 5, 6)
print a + b
```

Notably, `+` being overloaded in this manner means that we can no longer use it to give clues about the types of its operands, i.e. it becomes equivalent to a regular method call. Other mechanisms are required to tell us about the types of `a` and `b` here.

### Higher-order functions

In the presence of higher-order functions, the problem of building a call graph becomes much more complicated. Consider this function:

```js
let apply = func(x, y) { x(y) }
```
To know what edges originate from `apply`, we need more information about `x`; specifically, what values `x` may take on at runtime. In other words, control flow in our programs now depends on data flow.

So-called *smearing algorithms*, conceptually similar to what we did when we hand-waved over the types of values with a union type, are the simplest solution to this.

There must be a finite set of values that `apply` is called with, one might say. If we know where `apply` is called directly, and can get some smeared approximation of where it is passed as a higher-order function, we should be able to figure out the edges that originate from it. In any case, the number of outgoing edges cannot exceed *all* the functions defined in the program, right?

Right, in this case. Unfortunately, lexical scope adds another layer of complexity. Consider this example, where `apply` takes a parameter from its environment:

```js
let id = func(x) { x };

let loop(f) = func(x) {
    let double = func(x) { f(x) * 2 };
    print(f(1));
    loop(double)
};

loop(id)
```

When we allow the context of a program to be passed to functions as a parameter, we end up with an infinite number of functions (due to the infinite number of possible contexts) that a `loop` may have edges going to. This in turn requires more calculated smearing to deal with.

More accurate alternatives to smearing algorithms track possible paths through programs, but are more computationally expensive; tradeoffs must be made depending on the application.

### Object-oriented programming

Lots of dynamic languages are object-oriented, or at least have support for OO features. With this comes some notion of classes, some way to dispatch to parent classes (prototypes, metaclasses), and ways to change objects and the hierarchy at runtime.

Due to the last one, it's difficult to consider instances of classes as static. A straightforward way to model objects is to simply treat them as sets of fields, treat methods like functions nested in object fields, and consider each object in isolation.

```js
let obj = { f: func(x) { x } };
obj.f(x)
```

It seems that the outgoing edges from `obj.f` depends on the possible values of `f`, which in turn depends on the value of `obj`. This is very similar to the issue we faced when thinking about higher-order functions. Fundamentally, dynamic dispatch and higher-order functions have the same issues: control flow depending on data flow, and on the set of possible values variables may have. As such, the same techniques may be used to address them.

### Conclusion

Analysis of dynamic languages is complicated by the presence of *dynamic* features, which depend on information only knowable at runtime. Nevertheless, we can come up with approximations for lots of things which perform decently in practice.

Dependence on data flow is a common theme, and is why flow-sensitive approaches are used in the industry, for example in Facebook's Flow. The approach is similar to our very informal presentation of abstract interpretation.
