# Don't Just Move User Stores to Done, Let's Execute Them!

## Let's build something!

```
Product Owner: "Let's build something that brings me across the Atlantic Ocean."
Developer: (Builds a plane...)
Product Owner: "Uh... I actually just needed a ship."
Developer: Uh... ok...
```

Although the above scenario sounds contrived, this happens a lot in a smaller
scale in most software teams. Requirements from product management are
sometimes poorly specified and it means that developers have to guess what's on
the product owner's mind. In most cases this can be resolved by simply talking
to the product owner. However, most product folks are non-technical and might
not know what they actually want. This leads to developers coming up with
products that are over-engineered or worse, the implementation sometimes misses
the mark and fails to build the intended product.

## What can we do about it?

We need something to bridge the gap between the product owner and the
developer. Something that can describe exactly what is being build and ensures
that the right thing is being build. A tool that tries to solve this is
[Cucumber](https://cucumber.io/). Cucumber is a testing tool that supports
[behavior driven development (BDD)](https://cucumber.io/docs/bdd/).  Behavior
driven development is an extension of test driven development (TDD). In TDD,
developers write tests before writing code, whereas in BDD, the specifications
(or behaviors, hence BDD) are written before code is written.  These
specifications are what the user actually wants in the product.  In Cucumber,
these feature specifications are usually written by the product owner in
collaboration with the development team. The developers would then implement
them. After it's implemented, Cucumber would run the specifications to ensure
that the specifications are actually working as intended. In some sense, the
specifications are now the tests and they can be run as part of the CI
pipeline.

In summary a BDD cycle would look like this:
- Product owner writes feature specifications in collaboration with the development team.
- Developers implement the feature.
- Tester or developer runs the Cucumber tests to ensure specifications were built.

## Example of a feature specificaton

In Cucumber, product specifications are written in features files, these
feature files uses a Domain Specific Language (DSL) known as Gherkin. It uses a
Given-When-Then language that is close to natural language. Here's an example
of a feature file in Cucumber that specifies a feature for a calculator
program:

```
Feature: Addition
  Scenario: Calculate the sum of two integers
    Given two integers
    When the add button is pressed
    Then the sum of the two integers should be displayed
```

Being very close to a natural language, it is readable by stakeholders in the
organization and non-technical product owners. In the above example it is clear
how the user is interacting with the program, what the inputs and preconditions
are, and what should be expected. These properties are described using the
Given-When-Then language:

- `Given`: describes the preconditions of the feature
- `When`: describes the action that the user carries out in the feature
- `Then`: desribes what's expected after the action is performed

In Cucumber, these are known as steps, each step when evaluated has a
predefined behavior. Although Cucumber already come with some predefined steps,
developers and testers can extend the language to suit their application. For
example, the following step uses the `click_on` method defined in the
`capybara` ruby gem. It navigates to the home page when Cucumber sees a step
that says `When the home button is clicked`:

```
When(/^the home button is clicked$/) do
  click_on 'Home'
end
```

## Executable user stories

In an agile team, this feature file is also known as a user story. It defines a
user's requirements in the way the user would interact with the software. Apart
from being just a document to communicate the requirements of a user, this
feature file can be executed and ran against the product to ensure that the
product meets the user's requirement and use case as described in the story. To
do so, Cucumber evaluates the Gherkin language, populates the test environment
with the preconditions and input, and then simulates the interaction with the
program, and lastly it checks the actual behavior of the program against the
desired behavior as specified in the feature file.

## Closing thoughts

Cucumber and BDD closes the gap between the non-technical requirements and
technical implementation. It also closes the gap between the product owners and
the developers. When writting in Gherkin, software teams have to think about
the requirements in a user centric way. Requirements are no longer just "Build
a calculator that adds", with the Given-When-Then language, developers have to
think harder about preconditions, inputs, and expectations of each feature.
What's more, with Cucumber, these files are executable, they ensure that the
working implementation of the program runs exactly in the way that is described
in the feature file.
