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
* [ ] Read the ECMA262 v7 specification, and implement it.
      + [ ] Declaration.(175/586)
      + [ ] Implementation.
            - [ ] Template Literal
* [ ] Run test262.(0/23509)
* [ ] Make pull requests?(0/???)