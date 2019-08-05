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