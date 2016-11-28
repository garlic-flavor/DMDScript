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


module dmdscript.program;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dglobal;
import dmdscript.functiondefinition;
import dmdscript.statement;
import dmdscript.value;
import dmdscript.opcodes;
import dmdscript.darray;
import dmdscript.parse;
import dmdscript.scopex;
import dmdscript.text;
import dmdscript.property;
import dmdscript.identifier;
import dmdscript.ddate;

debug import std.stdio;

class Program
{
    uint errors;        // if any errors in file
    CallContext callcontext;
    FunctionDefinition globalfunction;
    // static Program program;//per thread global associated data

    // Locale info
    uint lcid;          // current locale
    d_string slist;     // list separator

    this()
    {
        dobject_init();
        callcontext = CallContext(this, new Dglobal(null));
/*
        callcontext = new CallContext();

        CallContext* cc = callcontext;

        // Do object inits
        dobject_init();

        cc.prog = this;

        // Create global object
        cc.global = new Dglobal(null);

        Dobject[] scopex;
        scopex ~= cc.global;

        cc.variable = cc.global;
        cc.scopex = scopex;
        cc.scoperoot++;
        cc.globalroot++;

*/
        assert(Ddate.getPrototype.proptable.length != 0);
    }

    /**************************************************
     * Two ways of calling this:
     * 1. with text representing group of topstatements (pfd == null)
     * 2. with text representing a function name & body (pfd != null)
     */

    void compile(d_string progIdentifier, d_string srctext,
                 FunctionDefinition* pfd)
    {
        TopStatement[] topstatements;
        d_string msg;

        //writef("parse_common()\n");
        Parser p = new Parser(progIdentifier, srctext,
                              Parser.UseStringtable.Yes);

        if(auto exception = p.parseProgram(topstatements))
        {
            topstatements = null;
            throw exception;
        }

        if(pfd)
        {   // If we are expecting a function, we should have parsed one
            assert(p.lastnamedfunc);
            *pfd = p.lastnamedfunc;
        }

        // Build empty function definition array
        // Make globalfunction an anonymous one (by passing in null for name) so
        // it won't get instantiated as a property
        globalfunction = new FunctionDefinition(
            srctext, 0, 1, Identifier.build(progIdentifier), null, null);

        // Any functions parsed in topstatements wind up in the global
        // object (cc.global), where they are found by normal property lookups.
        // Any global new top statements only get executed once, and so although
        // the previous group of topstatements gets lost, it does not matter.

        // In essence, globalfunction encapsulates the *last* group of topstatements
        // passed to script, and any previous version of globalfunction, along with
        // previous topstatements, gets discarded.

        globalfunction.topstatements = topstatements;

        // If pfd, it is not really necessary to create a global function just
        // so we can do the semantic analysis, we could use p.lastnamedfunc
        // instead if we're careful to insure that p.lastnamedfunc winds up
        // as a property of the global object.

        Scope sc;
        sc.ctor(this, globalfunction);  // create global scope
        sc.src = srctext;
        globalfunction.semantic(&sc);

        if (sc.exception !is null)
            msg = sc.exception.msg;
        if(msg)                         // if semantic() failed
        {
            globalfunction.topstatements[] = null;
            globalfunction.topstatements = null;
            globalfunction = null;
            throw sc.exception;
        }

        if(pfd)
            // If expecting a function, that is the only topstatement we should
            // have had
            (*pfd).toIR(null);
        else
        {
            globalfunction.toIR(null);
        }

        // Don't need parse trees anymore, so null'ing the pointer allows
        // the garbage collector to find & free them.
        globalfunction.topstatements[] = null;
        globalfunction.topstatements = null;
    }

    /*******************************
     * Execute program.
     * Throw ScriptException on error.
     */

    void execute(d_string[] args)
    {
        // ECMA 10.2.1
        //writef("Program.execute(argc = %d, argv = %p)\n", argc, argv);
        //writef("Program.execute()\n");

        // initContext();

        Value[] locals;
        Value ret;
        DError* result;
        CallContext* cc = &callcontext;
        Darray arguments;
        Dobject dglobal = cc.global;
        //Program program_save;

        // Set argv and argc for execute
        arguments = new Darray();
        dglobal.Put(Text.arguments, arguments,
                    Property.Attribute.DontDelete |
                    Property.Attribute.DontEnum, *cc);
        arguments.length.put(args.length);
        for(int i = 0; i < args.length; i++)
        {
            arguments.Put(i, args[i], Property.Attribute.DontEnum, *cc);
        }

        Value[] p1;
        Value* v;
        version(Win32)          // eh and alloca() not working under linux
        {
            import core.sys.posix.stdlib : alloca;

            if(globalfunction.nlocals < 128)
                v = cast(Value*)alloca(globalfunction.nlocals * Value.sizeof);
        }
        if(v)
            locals = v[0 .. globalfunction.nlocals];
        else
        {
            p1 = new Value[globalfunction.nlocals];
            locals = p1;
        }

        // Instantiate global variables as properties of global
        // object with 0 attributes
        globalfunction.instantiate(cc.scopex, cc.variable,
                                   Property.Attribute.DontDelete);

//	cc.scopex.reserve(globalfunction.withdepth + 1);

        // The 'this' value is the global object
        //FIXED: NOT any longer in D 2.0, any global data is actually thread-local, so stripped all this 'saving global object' crap
        //printf("cc.scopex.ptr = %x, cc.scopex.length = %d\n", cc.scopex.ptr, cc.scopex.length);
        //program_save = getProgram();

        // setProgram(this);
        ret.putVundefined();
        result = IR.call(*cc, cc.global, globalfunction.code, ret, locals.ptr);
        if(result)
        {
            auto exception = result.toScriptException;
            p1 = null;
            exception.addTrace(
                globalfunction.name !is null ? globalfunction.name.toString
                : "anonymous",
                globalfunction.srctext);
            throw exception;
        }
        //writef("-Program.execute()\n");


        delete p1;
    }

    void toBuffer(scope void delegate(in tchar[]) sink)
    {
        if(globalfunction)
            globalfunction.toBuffer(sink);
    }

    /***********************************************
     * Get/Set Program associated with this thread.
     * This enables multiple scripts (Programs) running simultaneously
     * in different threads.
     * It is needed because which Program is being run is essentially
     * global data - and this makes it thread local data.
     */

/+
deprecated
    static Program getProgram()
    {
        return program;
    }

deprecated
    static void setProgram(Program p)
    {
        program = p;
    }
+/
}

