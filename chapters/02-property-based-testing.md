
# Beyond Unit Tests: Property-based Testing

In a [previous article](01-automated-test-case-generation.md), we looked at the use of [EvoSuite](http://www.evosuite.org/) framework for automated test case generation in Java. As mentioned in that article, EvoSuite uses _search-based_ and _constraint-based_ methods for generation of test cases. These methods are guided by coverage criteria (e.g. branch coverage) and ability to explore different paths in the program. The test cases generated by these methods may not capture the intended behavior of the program. In today's article we will see how we can generate test cases that capture certain behaviors about programs. This can be done using _property-based_ testing.

[JUnit-QuickCheck](https://github.com/pholser/junit-quickcheck) is a library that provides _property-based_ testing for Java programs. It is inspired by the [QuickCheck](http://en.wikipedia.org/wiki/QuickCheck) library for Haskell that first pioneered this approach for automated testing. The library makes use of JUnit's [Theory](https://github.com/junit-team/junit/wiki/Theories) feature to support parameterized test cases. These test cases allow the developer to specify the property that the method under test should satisfy. JUnit-QuickCheck then uses randomly generated values to test the property. The following example shows how to use the `@Theory` annotation to specify a test method:

````
@RunWith(Theories.class)
public class PropertyJUnitTest {
  @Theory public void testEncodeBase64(@ForAll byte [] src){
    byte [] ec = EncodeBase64.encode(src);
    byte [] dec = EncodeBase64.decode(ec);
    Assert.assertArrayEquals(src,dec);
  }
}
````

This unit test is calling the `encode` and `decode` functions of the `EncodeBase64`
class from the [wox cross platform serialization library](https://github.com/codelion/wox).
The property of interest here is the _idempotence_ of `decode(encode())` operation. In other words, we want to check that encoding a byte array and then decoding it back leads to the same byte array. The `assertArrayEquals` at the last line ensures that this property is satisfied. This property is tested by randomly generating a large number (100 by default) of byte arrays and calling the `testEncodeBase64` with those values as input. The `@ForAll` annotation is provided by the JUnit-QuickCheck library and takes care of generating the appropriate random inputs. 

If there are two inputs to the method, then all possible combinations of the randomly generated inputs are tested. In order to avoid running so many tests we can specify
constraints on the input as shown below:

````
  @Theory public void testEncodeBase64withLength(@ForAll byte [] src){
    assumeThat(src.length, greaterThan(32)); 
    byte [] ec = EncodeBase64.encode(src);
    byte [] dec = EncodeBase64.decode(ec);
    Assert.assertArrayEquals(src,dec);
  }
````

The `assumeThat` ensures that only byte arrays with length greater than 32 are generated.
The library already comes with generators for all primitive Java types and there is also a separate module `junit-quickcheck-guava` containing generators for [Guava](https://code.google.com/p/guava-libraries/) types. However, if we need to generate inputs of custom type we need to provide a generator. It can be done by extending the `Generator` class
and overriding the `generate` method. The following example shows one possible way to generate random inputs of the `org.jdom2.Element` type.

````
public class ElementGenerator extends Generator<Element> {

 public ElementGenerator() {
    super(Element.class);
  }
  
@Override
  public Element generate(SourceOfRandomness rand, GenerationStatus gs) {
    Element e = new Element(RandomStringUtils.randomAlphabetic(16));
    int numofAttr = rand.nextInt(8);
    for(int i=0; i<numofAttr;i++){
     e.setAttribute(RandomStringUtils.randomAlphabetic(8),RandomStringUtils.randomAlphabetic(8));
    }
    e.addContent(RandomStringUtils.randomAlphabetic(rand.nextInt(16)));
    return e;
  }
  
}

````

Every time the `generate` method is called, it creates a random alphabetic string that is used as the name of the element and adds up to 8 random attribute values in it. To use this generator for the `Element` type we need to specify the class with the `@From` annotation after the `@Forall` in the test method as shown below:

````
  @Theory public void testElement2String(@ForAll @From(ElementGenerator.class) Element e)
            throws Exception {
    String s = element2String(e);
  }
````

The use of custom generators allows us to use _property-based_ testing for arbitrary classes and methods with little effort. The source code for all the tests is available under the [wox repository](https://github.com/codelion/wox/tree/master/java/src/test/java/wox/serial/tests) on GitHub. In addition, some other frameworks (under active development) providing similar functionality for Java are [Quickcheck](https://bitbucket.org/blob79/quickcheck) and [ScalaCheck](http://www.scalacheck.org/). However, JUnit-QuickCheck is the only one to use the Theory support in JUnit which makes it a lot easier to integrate in the development workflow.