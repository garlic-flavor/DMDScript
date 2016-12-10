/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * D2 port by Dmitry Olshansky 
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */

module dmdscript.script;

import dmdscript.primitive : tstring;
debug import std.stdio;
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

//
struct CallContext
{
    import dmdscript.dobject : Dobject;
    import dmdscript.program : Program;
    import dmdscript.functiondefinition : FunctionDefinition;

    Dobject[] scopex; // current scope chain
    Dobject            variable;         // object for variable instantiation (is scopex[scoperoot-1] is scopex[$-1])
    Dobject            global;           // global object (is scopex[globalroot - 1])
    const uint               scoperoot;        // number of entries in scope[] starting from 0
                                         // to copy onto new scopes
    const uint               globalroot;       // number of entries in scope[] starting from 0
                                         // that are in the "global" context. Always <= scoperoot
    // void*              lastnamedfunc;    // points to the last named function added as an event
    Program            prog;
    Dobject            callerothis;      // caller's othis
    Dobject            caller;           // caller function object
    FunctionDefinition callerf;

    bool                Interrupt;  // !=0 if cancelled due to interrupt

    @safe pure nothrow
    this(Program prog, Dobject global)
    {
        scopex = [global];
        variable = global;
        this.global = global;
        scoperoot = 1;
        globalroot = 1;
        this.prog = prog;
    }

    @safe pure nothrow
    this(ref CallContext cc, Dobject variable, Dobject caller,
         FunctionDefinition callerf)
    {
        scopex = cc.scopex ~ variable;
        this.variable = variable;
        global = cc.global;
        scoperoot = cc.scoperoot + 1;
        callerothis = cc.callerothis;
        prog = cc.prog;
        this.caller = caller;
        this.callerf = callerf;
    }
}

struct Global
{
    string copyright = "Copyright (c) 1999-2010 by Digital Mars";
    string written = "by Walter Bright";
}

Global global;

@trusted
string banner()
{
    import std.conv : text;
    return text(
               "DMDSsript-2 v0.1rc1\n",
               "Compiled by Digital Mars DMD D compiler\n",
               "http://www.digitalmars.com\n",
               "Fork of the original DMDScript 1.16\n",
               global.written,"\n",
               global.copyright
               );
}


@safe @nogc pure nothrow
int localeCompare(ref CallContext cc, tstring s1, tstring s2)
{   // no locale support here
    import std.string : cmp;
    return cmp(s1, s2);
}

