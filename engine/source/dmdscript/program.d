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

debug import std.stdio;

class Program
{
    import dmdscript.primitive : string_t, char_t;
    import dmdscript.callcontext : CallContext;
    import dmdscript.functiondefinition : FunctionDefinition;

    this()
    {
        import dmdscript.dobject : dobject_init;
        import dmdscript.dglobal : Dglobal;

        dobject_init();
        callcontext = CallContext(this, new Dglobal(null));

        debug
        {
            import dmdscript.ddate : Ddate;
            assert(Ddate.getPrototype.proptable.length != 0);
        }
    }

    //--------------------------------------------------------------------
    /**
    Two ways of calling this:
    1. with text representing group of topstatements (pfd == null)
    2. with text representing a function name & body (pfd != null)
    */
    void compile(string_t progIdentifier, string_t srctext,
                 FunctionDefinition* pfd)
    {
        import dmdscript.statement : TopStatement;
        import dmdscript.parse : Parser;
        import dmdscript.primitive : StringKey;
        import dmdscript.scopex : Scope;

        TopStatement[] topstatements;
        string_t msg;

        Parser p = new Parser(progIdentifier, srctext,
                              Parser.UseStringtable.Yes);

        if(auto exception = p.parseProgram(topstatements))
        {
            topstatements = null;
            throw exception;
        }

        debug
        {
            if (dumpMode & DumpMode.Statement)
                TopStatement.dump(topstatements).writeln;
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
            srctext, 0, 1, StringKey.build(progIdentifier), null,
            topstatements);

        // Any functions parsed in topstatements wind up in the global
        // object (cc.global), where they are found by normal property lookups.
        // Any global new top statements only get executed once, and so although
        // the previous group of topstatements gets lost, it does not matter.

        // In essence, globalfunction encapsulates the *last* group of
        // topstatements passed to script, and any previous version of
        // globalfunction, along with previous topstatements, gets discarded.

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

        debug
        {
            if (dumpMode & DumpMode.Semantics)
                TopStatement.dump(topstatements).writeln;
        }

        if(pfd)
            // If expecting a function, that is the only topstatement we should
            // have had
            (*pfd).toIR(null);
        else
        {
            globalfunction.toIR(null);
        }

        debug
        {
            import dmdscript.opcodes;
            if (dumpMode & DumpMode.IR)
                IR.toString(globalfunction.code).writeln;
        }

        // Don't need parse trees anymore, so null'ing the pointer allows
        // the garbage collector to find & free them.
        globalfunction.topstatements = null;
    }

    //--------------------------------------------------------------------
    /**
    Execute program.
    Throw ScriptException on error.
    */
    void execute(string_t[] args)
    {
        import dmdscript.primitive : Key;
        import dmdscript.value : Value, DError;
        import dmdscript.darray : Darray;
        import dmdscript.dobject : Dobject;
        import dmdscript.property : Property;
        import dmdscript.opcodes : IR;

        // ECMA 10.2.1

        Value[] locals;
        Value ret;
        DError* result;
        Darray arguments;
        Dobject dglobal = callcontext.scopex.global;

        // Set argv and argc for execute
        arguments = new Darray();
        dglobal.Set(Key.arguments, arguments,
                    Property.Attribute.DontDelete |
                    Property.Attribute.DontEnum, callcontext);
        arguments.length.put(args.length);
        for(int i = 0; i < args.length; i++)
        {
            arguments.Set(i, args[i], Property.Attribute.DontEnum, callcontext);
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
        globalfunction.instantiate(callcontext, Property.Attribute.DontDelete);
//	cc.scopex.reserve(globalfunction.withdepth + 1);

        ret.putVundefined();
        result = IR.call(callcontext, callcontext.scopex.global,
                         globalfunction.code, ret, locals.ptr);
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

        delete p1;
    }

    //--------------------------------------------------------------------
    ///
    void toBuffer(scope void delegate(in char_t[]) sink)
    {
        if(globalfunction)
            globalfunction.toBuffer(sink);
    }

    //====================================================================
private:

    CallContext callcontext;
    FunctionDefinition globalfunction;

debug public:
    enum DumpMode
    {
        None       = 0x00,
        Statement  = 0x01,
        Semantics  = 0x02,
        IR         = 0x04,
        All        = 0x07,
    }
    DumpMode dumpMode;
}

