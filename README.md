# DFUnit - DataFlex Unit Testing Framework

**DFUnit** is a renewed DataFlex testing framework. It was originally forked from [https://github.com/olaeld/DFUnit](https://github.com/olaeld/DFUnit). Data Access originally forked it to accommodate the framework for multiple reporters like seen in frameworks like doctest. Most importantly support for build-servers was added using a new Console reporter and exit codes. It supports outputting to one of the most used test-data formats **JUnit** which will help for a steady CI flow. The framework is and will stay free.

### Getting Started (DataFlex 26+: add it as a package)

From DataFlex 26 the quickest route is to add DFUnit as a package and copy in the
starter files. Two steps, and nothing in this repository has to be edited:

**1. Add the package.** In the Studio: select the package-manager > Add Package,
or from a command prompt in the workspace folder:

```
df-cli package install <YourWorkspace>.sws https://github.com/NilsSve/Library-DFUnit.git
```

The package lands under the workspace's `DfPkg` folder. Those files are **read-only by
design** - the package manager owns them and replaces them on every update, so nothing
you write should ever live there.

> **The repository was adjusted to not generate any compile warnings**  The folder structure was simplified - everything that used
> to sit under `DFUnit/` is now at the root. A git dependency records **two coupled
> fields**, the commit and the manifest's path *inside the repo at that commit*, so
> `"sws": "DFUnit/DFUnit-26.0.sws"` has to become `"sws": "DFUnit-26.0.sws"` in the same
> edit that moves `"version"` forward. Change one without the other and df-cli reports
> *Failed to configure* and leaves the workspace **BROKEN** - and `package uninstall`
> cannot rescue it, because uninstall configures the workspace first. Removing the
> dependency and adding the package again is the clean route.

```
SetupUnitTests.bat -AddProject
```

> A dependency added as a **local path** rather than a package gets none of this -
> *"Library ... is a local library and therefore its install files are ignored."* Run the
> `SetupUnitTests.bat` inside the library folder instead.

That drops four files into `AppSrc` and adds `UnitTests.src` to the workspace's project
list (drop `-AddProject` to add the project yourself in the Studio):

| Copied out as | What it is |
|---|---|
| `AppSrc\UnitTests.src` | The test program. **This is the one you add as a project and compile.** You should not need to edit it again. |
| `AppSrc\UnitTests.cfg` | Its project settings: 64-bit, and manifest generation off for build-server compatibility. |
| `AppSrc\oUnit_Tests.pkg` | The root fixture - **the only file you edit to add tests**: one `Use` line per test file. |
| `AppSrc\oExample-Tests.pkg` | A worked example showing the fixture shape and the common assertions. Copy it, rename it, delete it when you are done with it. |

> **A project's `.src` must live in the workspace's OWN `AppSrc`** - DataFlex resolves a
> project name against that path only, never against a library's. So nothing inside the
> package can be added as a project, which is why step 2 exists and why the templates
> carry a `.template` suffix. Add one anyway and the Studio reports no error at all: it
> simply does nothing. `df-cli` is more forthcoming -
> *"Project ... could not be found in any AppSrc paths"*.

Compile `UnitTests` and run it. The runner window opens and the example tests pass. From
then on, adding tests is: copy `oExample-Tests.pkg` to `o<Subject>-Tests.pkg`, write the
`{ Published=True }` procedures, add one `Use` line in `oUnit_Tests.pkg`.

For a build server, run it unattended - `Programs\UnitTests64.exe -c -o test_results.xml`
writes JUnit XML and exits 0 when everything passed, -1 when something failed.

### Why the sources live in a `DFUnit` folder

The layout is deliberate, and worth leaving alone.

A library's AppSrc path joins the consuming workspace's include search path. DFUnit's
AppSrc path is the **package root**, and the framework sits one level below it in `DFUnit`,
so every internal include is written `Use DFUnit\Testing\Assert.pkg` and the only bare name
the library contributes to your workspace is `DFUnit.pkg` - the one you actually call.

Put those files directly on the search path instead and they stop being namespaced. Names
like `Globals.pkg`, `Application.pkg`, `Version.pkg` and `Utils.pkg` are ordinary things for
a DataFlex application to have, and the consequence is not a warning - it is a workspace
that will not build, with every error pointing inside DFUnit:

```
While compiling ErrorSystem.pkg:
    (119,1) Error 4328: Undefined symbol in argument GHOERRORTRACKER
While compiling Assert.pkg:
    (13,1) Error 4328: Undefined symbol in argument GHOTESTAPPLICATION
```

That is a real run against a workspace whose only crime was having its own `Globals.pkg`:
it shadowed DFUnit's, so the globals were never defined. A same-basename clash across the
search path resolves by an order the workspace file cannot steer, so it can only be fixed
at the source - which is exactly what the folder prevents.

### Getting Started (DataFlex 20 - 25)


The framework code itself is self-sustaining aside from the DataFlex APIs and still compiles from DataFlex 20.0 up. Below DataFlex 26 there is no package manager, so add DFUnit the classic way - a library entry pointing at a workspace file for your release - and set the test program up by hand: copy the four files from `Templates` into your workspace's `AppSrc` and drop the `.template` suffix.

**Two workspace files ship: `DFUnit-26.0.sws` and `DFUnit-25.0.sws`.** A DataFlex 25 Studio cannot read the JSON one, so the INI file for 25.0 is kept alongside it; point your library entry at `DFUnit-25.0.sws`. The ones for 20.0 - 24.0 were removed. If you need one, they are six lines and the 25.0 file is the template - only `Version=` changes:

```ini
[Properties]
Version=24.0
[WorkspacePaths]
ConfigFile=.\Config.ws
[Conditionals]
Is$WebApp=False
```

or recover an original with `git show a2e8850:DFUnit/DFUnit-24.0.sws`.

Now let's walk through the essentials:

#### Project setup

Should you wish to create a new project that is build-server compatible perform the following actions:

1. Disable the following project options in the studio<sup>1:</sup>
    - Build Manifest
    - Embed Manifest
2. Disable suffixes on 64-bit if your build script expects an unsuffixed executable name.

<sup>1</sup>Is needed as studio settings might interfere with the console compiler's settings from the workspace.

#### Project source

Everything within DFUnit is single-header based, which means that you only ever need to include DFUnit.pkg. From then on it works the same as working with a Windows or Web Application.

1. Create a cApplication instance which will cover ghoApplication and; 
    - Opens the workspace.
    - Parses the command line.
2. Create a cDFUnitTestApplication instance which is our root parent. 
    1. You can Include files within the application to nest the individual fixtures and tests.
    2. You can embed a cTestFixture.
    3. You can embed a cTest.
    4. You can declare published procedures like below.

```DataFlex
Use DFUnit.pkg

Object oApplication is a cApplication
End_Object

Object oTestApplication is a cDFUnitTestApplication
	... Use {file}
    ... Create a fixture
    ... Create a test
    ... Create a published procedure as test
    { Published=True }
    Procedure TrueIsTrue
        Send Assert True "True should be True."
    End_Procedure
End_Object

// Parses the command line, then either shows the test-runner window or runs the
// tests on the console and exits 0 (all passed) / -1 (a test failed).
Send AutoRun of ghoTestApplication
```

3. Call `AutoRun` once, at the bottom of the `.src`. It arbitrates the command line
   (see **Console options** below) and then either opens the test-runner window or
   runs the tests on the console and exits with the appropriate code.

#### Using fixtures

Fixtures have different setup and teardown events. These events are all called before a test is executed. Know that they are recursive; as you start nesting fixtures executing a test will recursively call Setup upward and TearDown the same way afterwards.

In-between there are some events which will give you more flexibility which are also called in the following order.;

- BeforeSetupOneTime
- SetupOneTime
- AfterSetupOneTime
- BeforeSetup
- Setup
- AfterSetup
- BeforeTearDown
- TearDown
- AfterTearDown
- BeforeTearDownOneTime
- TearDownOneTime
- AfterTearDownOneTime

The OneTime events are called before and after each fixture itself but not the individual tests.

#### Using tests

All tests should use the assertion functions which are defined for each type.

```DataFlex
Procedure Assert Boolean bCondition String sAssertMessage
Procedure AssertFalse Boolean bCondition String sAssertMessage
Procedure AssertIAreEqual Integer Expected Integer Actual String sAssertMessage
Procedure AssertNAreEqual Number Expected Number Actual String sAssertMessage
Procedure AssertSAreEqual String Expected String Actual String sAssertMessage
Procedure AssertDTAreEqual DateTime Expected DateTime Actual String sAssertMessage
...
```

#### Using tests with Errors

DataFlex works with error numbers and as such we are able to expect them in block-like statements like the following.

```DataFlex
{ Published=True }
Procedure ExpectingAnError
    Send ExpectError DFERR_PROGRAM
        Error DFERR_PROGRAM "An expected error."
    Send UnExpectError DFERR_PROGRAM
End_Procedure
```

### Application options

`psTestFixtureName`, Defines the name of the root fixture (The TestApplication).

`pbAutoRun`, **\[Advanced\]** Should you have custom Run() code that invokes the Test Application you can turn this to false.

`pbAutoRunTests`, If using the UI this will immediately start the unit tests instead of waiting for a button click.

`pbUseUIIfInDebugger`, Should `pbUseUI` be false this could override that property if using the debugger.

`pbUseUI`, Indicates whether the UI or Console should run by default.

`pbUseBuiltInUI`, Whether `AutoRun` may open the framework's own test-runner window.
Leave it True unless your program builds a runner window of its own - and even then you
normally need not touch it: `AutoRun` skips the built-in window automatically whenever
the program already has a main panel, so a host with its own view keeps full control.

### Console options

`--help (-h)`, will print the DFUnit framework information.

`--console (-c)`, will override the `pbUseUI` to False.

`--gui (-g)`, will override the `pbUseUI` to True.

`--no-autorun (-n)`, will override the `pbAutoRunTests` to False.

`--output (-o)`, will output the test data to the designated file **(JUnit-XML only for now)**.
