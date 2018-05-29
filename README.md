DMDScript
=========

An implementation of the ECMA 262 (Javascript) programming language


## about myfork

# !!!THIS BRANCH IS UNDER CONSTRUCTION!!!
**IN SPITE OF THE RIGHT SCRIPTS, THE INTERPRETER MAY CRASH!**
**THE CURRENT VERSION HAS AN AT LEAST IMPLEMENTATION FOR PROGRESSING TEST262!**


### main goals
1. Update DMDScript to ECMA262 v7.
2. Be merged to the master. (but, could be?)

### pros
* I'm alive!

### cons
* Say goodbye to the C++ implementation.
* The contributor is a hobby programmer, lol.


### Current development environment.
|              |    version |
| ------------ | ---------- |
| Architecture |        x86 |
| OS           | Windows 10 |
| dmd          |    2.080.0 |
| test262      | #3bfad28cc |

### about harness.d
This aims to alternate test262-harness-py.

#### expected layout of directories.

	--+-- DMDScript --+   cwd
	  |               +-- dmdscript.exe
	  |               +-- harness.d
	  |               +-- test262.json
	  |
	  +-- test262 --+-- test -- ...  <- all tests are here.
	                +-- harness -- ... <- sta.js and assert.js are here.

#### how to run tests in specific directory.
	>rdmd harness.d run -p language/white-space

### progress
* [x] Read the ECMA262 v3 specification (roughly).
* [x] Read original source codes.
* [x] Rewrite codes with recent D's style to make development easy.
    + [x] Remove the undead module.
    + [x] Replace some functions with phobos's one.
    + [x] Reduce Super-Hacker's magic.
    + [x] Reduce pointers.
    + [x] Reduce global variables.
    + [x] Reduce bare member variables. (use capsuled objects.)
    + [x] Economize namespaces.
    + [x] Add function attributes.
    + [x] Capsulelize more. (use 'private', and property methods.)
    + [x] Add manual stack tracing.
    + [x] Use local importing.
* [x] Read the ECMA262 v7 specification (roughly).
* [ ] Run test262.(1382/59240)
* [ ] Implement test262-harness-d.
    + [x] The first compile.
    + [x] Run a script marked with 'module' as module.
    + [x] Run a script with strict mode.
    + [ ] Implement very useful functionalities.
* [ ] Read the specification again. (0/586)
* [ ] Make pull requests?(0/???)

### Passed directories.
* ..\test262\test\language\types\list
* ..\test262\test\language\identifiers
* ..\test262\test\language\types\reference
* ..\test262\test\annexB\language\literals\numeric
* ..\test262\test\language\literals\numeric
* ..\test262\test\language\white-space
* ..\test262\test\language\types\string
* ..\test262\test\language\literals\boolean
* ..\test262\test\language\literals\null
* ..\test262\test\language\asi
* ..\test262\test\language\types\object
* ..\test262\test\language\types\boolean
* ..\test262\test\language\types\null
* ..\test262\test\language\future-reserved-words
* ..\test262\test\language\line-terminators
* ..\test262\test\language\types\undefined
* ..\test262\test\annexB\language\comments
* ..\test262\test\language\reserved-words

### Failed directories.
* ..\test262\test\language\comments
* ..\test262\test\language\types\number

### Progressing directories.
* ..\test262\test\language\expressions\delete
* ..\test262\test\language\expressions\assignment

### Failed tests.
* ..\test262\test\language\comments\S7.4_A5.js on non strict mode.
  A invalid Unicode sequence is not allowed.
* ..\test262\test\language\comments\S7.4_A5.js on strict mode.
  A invalid Unicode sequence is not allowed.
* ..\test262\test\language\comments\S7.4_A6.js on non strict mode.
  A invalid Unicode sequence is not allowed.
* ..\test262\test\language\comments\S7.4_A6.js on strict mode.
  A invalid Unicode sequence is not allowed.
* ..\test262\test\language\expressions\delete\white-space-line-terminator-between-delete-unaryexpression-allowed.js on non strict mode.
  failed.
* ..\test262\test\language\types\number\S8.5_A2.1.js on non strict mode.
  do this later.
* ..\test262\test\language\types\number\S8.5_A2.1.js on strict mode.
  do this later.
* ..\test262\test\language\types\number\S8.5_A2.2.js on non strict mode.
  do this later.
* ..\test262\test\language\types\number\S8.5_A2.2.js on strict mode.
  do this later.

### problems.
* __test262-harness-py seems to be outdated.__
  ~~This is a problem.~~
  Introduce test262-harness-d.(2018/05/07)

* __about character encoding.__
  test262 assumes that the encoding is UTF16. And illegal Unicode sequences are permitted sometimes.
  Otherwise, DMDScript choose UTF8 and any illegal Unicode sequences are not permitted as dmd is.
  So, some codes are not compatible with another implementation of ECMAScript.
  For example, the length of a surrogate pair is not 2 but 1.
  this may change.

* ~~__CESU8__~~
  ~~I introduced CESU-8 as an internal representation of a string.~~
  ~~CESU-8 = Compatibility Encoding Scheme for UTF-16.~~
  ~~CESU-8 is almost same with UTF-8, but CESU-8 takes 6 bytes to represent a surrogate pair.~~
  ~~See Also https://en.wikipedia.org/wiki/UTF-8#CESU-8 .~~
  ~~I don't know this is OK or NG.~~
  ~~so, this feature may be changed.~~
  I change my mind.

* ~~__language/reserved-words/await-script.js and await-module.js__~~
  ~~The former one means that "Parse this script as a script.", The latter one means that "Parse this script as a module.".~~
  ~~But, test262-harness-py doesn't enforce that.~~
  test262-harness-d does this.(2018/05/22)

* __language/types/number/S8.5_A2.1.js and S8.5_A2.2.js__
  D's double type doesn't suit for this. How could I solve?

* __language/literals/string/7.8.4-1-s.js__
  ~~DMDScript has no 'strict mode', now.~~(2018/05/24)

* __language/literals/regexp/u-invalid-identity-escape.js__
  What does this mean? I'll do this later. XD

* __language/literals/regexp/u-invalid-non-empty-class-ranges-no-dash-a.js__
  __language/literals/regexp/u-invalid-non-empty-class-ranges-no-dash-ab.js__
  __language/literals/regexp/u-uniocde-esc-non-hex.js__
  These differences are came from D's implmementation of regular expressions.
  so, I'll do this later too.
