DMDScript
=========

An implementation of the ECMA 262 (Javascript) programming language


## about myfork

# !!!THIS BRANCH IS UNDER CONSTRUCTION!!!
**IN SPITE OF THE RIGHT SCRIPTS, THE INTERPRETER MAY CRASH!**
**I CANNOT DO ANY TESTS NOW!**


### main goals
1. Update DMDScript to ECMA262 v7.
2. Be merged to the master. (but, could be?)

### pros
* I'm alive!

### cons
* Say goodbye to the C++ implementation.
* The contributor is a hobby programmer, lol.


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
* [ ] Run test262.(629/23509)
      + [x] language/comments/*
      + [x] language/line-terminators/*
      + [x] language/source-text/*
      + [x] language/white-space/*
      + [x] language/reserved-word/* (see below.)
      + [x] language/identifiers/*
      + [x] language/asi/*
      + [x] language/future-reserved-words/*
      + [x] language/types/boolean/*
      + [x] language/types/list/*
      + [x] language/types/null/*
      + [x] language/types/number/* (see below.)
      + [x] language/types/string/*
      + [x] language/types/undefined/*
* [ ] Read the specification again. (0/586)
* [ ] Make pull requests?(0/???)

### problems.
* __language/reserved-words/await-script.js and await-module.js__
  The former one means that "Parse this script as a script.", The latter one means that "Parse this script as a module.".
  But, test262-harness-py doesn't enforce that.

* __language/types/number/S8.5_A2.1.js and S8.5_A2.2.js__
  D's double type doesn't suit for this. How could I solve?

