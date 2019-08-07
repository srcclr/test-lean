
# Automated Unit Test Generation for Java

Unit testing is an important aspect of software development. Having a proper test suite for your project can help detect bugs early and prevent regressions. Wouldn't it be great if we could generate unit test cases automatically? Well, it is certainly possible and I will explain in this article how you can do so for Java.

Recently, I had a chance to look at unit test case generation for Java. I had forked an old cross platform serialization library [wox](https://github.com/codelion/wox) and it did not come with a test suite. I had to make a few changes and fix some bugs in the library to make it work with the current version of Java platform. I wanted to ensure that the changes I made did not break any existing functionality. Since the wox library did not come with its own set of test cases it was difficult to check that no regression bugs were introduced.

After searching online, I found an automated test suite generation framework for Java - [EvoSuite](http://www.evosuite.org/). The EvoSuite framework automatically generates test cases for Java classes based on maximizing a coverage criteria, like branch coverage. I used their standalone jar to add a test suite to the wox library. It was surprisingly easy to set up and use.

In order to generate the test suite we use the following command : 

````
java -jar evosuite.jar -generateTests <target> [options]
````

The **\<target>** can be either a jar file of a folder containing your class files. This would generate the test cases in a folder named "evosuite-tests" in the current directory.
The test cases generated use JUnit and can be run separately from an IDE as well.
The **[options]** control various parameters including coverage criteria, the default criteria
is branch coverage. Thus the generated tests cover all the branches in the methods. If you are using some external library then make sure that it is available in the class path otherwise EvoSuite will not be able to create test cases with objects that are defined in that library. This is because to create objects during generation of test cases EvoSuite needs to call appropriate constructors for those objects.

For test case generation, EvoSuite has a bunch of different strategies including _search-based_ and _constraint-based_ algorithms. 

- _Search Based Test Generation_ : Uses a [genetic algorithm](http://en.wikipedia.org/wiki/Genetic_algorithm) to evolve the population of candidate test cases that satisfy a particular fitness function
 
- _Constraint Based Test Generation_ : Uses [symbolic execution](http://en.wikipedia.org/wiki/Symbolic_execution) to generate constraints and solve those constraints to explore different paths in the program.

Their [ASE 2011 paper](http://www.evosuite.org/wp-content/papercite-data/pdf/ase11.pdf) explains  both the above techniques and how they can be combined and used together.

In terms of the quality of the automated generated test cases, it seems to do a good job of capturing the current behavior of the methods while providing good branch coverage. As an example consider the following method from the **wox.serial.Util** class :

````
 /**
     * Returns true if the class which name is passed as parameter is <i>stringable</i>.
     * In other words, returns true if objects of the class can go easily to a string
     * representation.
     * @param name The name of the class to test.
     * @return True if the class is stringable. False otherwise.
     */
    public static boolean stringable(String name) {
        try {
            Class realDataType = (Class)TypeMapping.mapWOXToJava.get(name);
            //if the data type was found in the mapWOXToJava then it is "stringable"
            if (realDataType!=null){
                return true;
            }
            else{
                return false;
            }
        } catch(Exception e) {
            return false;
        }
    }
````

The **stringable** method has two branches that correspond to whether the input **name** can be converted to a string by the **mapWOXToJava.get** method. EvoSuite generates the following two test cases for this method. **test02** covers the branch where the conditional is true whole **test03** covers the else branch. Also note that it is automatically able to create the inputs for **name** argument that drive the execution to the different branches.

````
  //Test case number: 2
  /*
   * 1 covered goal:
   * 1 wox.serial.Util.stringable(Ljava/lang/String;)Z: I10 Branch 21 IFNULL L125 - false
   */

  @Test
  public void test02()  throws Throwable  {
      boolean boolean0 = Util.stringable("charWrapper");
      assertEquals(true, boolean0);
  }

  //Test case number: 3
  /*
   * 1 covered goal:
   * 1 wox.serial.Util.stringable(Ljava/lang/String;)Z: I10 Branch 21 IFNULL L125 - true
   */

  @Test
  public void test03()  throws Throwable  {
      boolean boolean0 = Util.stringable("2p8f2V@rzS");
      assertEquals(false, boolean0);
  }
````

You can have a look at the entire test suite generated for the wox library at the [GitHub repo](https://github.com/codelion/wox/tree/master/java/evosuite-tests/wox/serial). For the purpose of creating a regression test suite for a library that did not have one it seems to be quite effective. Now, if I make some changes in the wox library I can run the tests again and check if leads to any test failures. In general, automated test cases may not be as good as hand written ones. Another potential issue is the evolution of the test suite. Generating new tests with EvoSuite for each release may not be the right thing to do. Nevertheless the automated test suite can be used as a base for writing your own more comprehensive test cases, which is what I plan to do with the wox library.

There are several other tools (under active development) for Java that also produce automated unit test cases. I haven't had a chance to use them yet but I list them here for reference - [CATG](https://github.com/ksen007/janala2), [Randoop](http://code.google.com/p/randoop) and [Symbolic Pathfinder](http://babelfish.arc.nasa.gov/trac/jpf/wiki/projects/jpf-symbc). An experience report, titled [EvoSuite at the Second
Unit Testing Tool Competition](http://www.evosuite.org/wp-content/papercite-data/pdf/fittest2014.pdf) provides more details on using EvoSuite and how it compares with other similar tools.

## Property-based Testing for Java

In a [previous article](https://blog.sourceclear.com/automated-unit-test-generation-for-java/), we looked at the use of [EvoSuite](http://www.evosuite.org/) framework for automated test case generation in Java. As mentioned in that article, EvoSuite uses _search-based_ and _constraint-based_ methods for generation of test cases. These methods are guided by coverage criteria (e.g. branch coverage) and ability to explore different paths in the program. The test cases generated by these methods may not capture the intended behavior of the program. In today's article we will see how we can generate test cases that capture certain behaviors about programs. This can be done using _property-based_ testing.

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
