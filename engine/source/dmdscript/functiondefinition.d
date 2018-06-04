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


module dmdscript.functiondefinition;

debug import std.stdio;

import dmdscript.primitive;
import dmdscript.callcontext;
import dmdscript.statement;
import dmdscript.dfunction;
import dmdscript.scopex;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.ddeclaredfunction;
import dmdscript.symbol;
import dmdscript.dobject;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.value;
import dmdscript.property;

/* ========================== FunctionDefinition ================== */

class FunctionDefinition : TopStatement
{
    // Maybe the following two should be done with derived classes instead
    import std.bitmanip : bitfields;
    mixin(bitfields!(
        bool, "isglobal", 1,         // !=0 if the global anonymous function
        bool, "isliteral", 1,        // !=0 if function literal
        bool, "iseval", 1,           // !=0 if eval function
        int, "_padding", 5));

    Identifier name;             // null for anonymous function
    Identifier[] parameters;      // array of Identifier's
    TopStatement[] topstatements; // array of TopStatement's
    bool strictMode;

    Identifier[] varnames;       // array of Identifier's
    /*    private*/ FunctionDefinition[] functiondefinitions;
//    private FunctionDefinition enclosingFunction;
    private int nestDepth;
    int withdepth;              // max nesting of ScopeStatement's

    SymbolTable* labtab;        // symbol table for LabelSymbol's

    IR* code;
    size_t nlocals;

    @safe @nogc pure nothrow
    this(TopStatement[] topstatements, bool strictMode = false)
    {
        super(0);
        this.isglobal = 1;
        this.topstatements = topstatements;
        this.strictMode = strictMode;
    }

    @safe @nogc pure nothrow
    this(uint linnum, bool isglobal, Identifier name, Identifier[] parameters,
         TopStatement[] topstatements, bool strictMode = false)
    {
        super(linnum);
        this.isglobal = isglobal;
        this.name = name;
        this.parameters = parameters;
        this.topstatements = topstatements;
        this.strictMode = strictMode;
    }

    final @safe @nogc pure nothrow
    int isAnonymous() const
    {
        return name is null;
    }

    override FunctionDefinition semantic(Scope* sc)
    {
        uint i;
        TopStatement ts;
        FunctionDefinition fd;

        // writeln("FunctionDefinition::semantic(",
        //         name !is null ? name.text: "", ")");

        // Log all the FunctionDefinition's so we can rapidly
        // instantiate them at runtime
        fd = /*enclosingFunction =*/ sc.funcdef;
        // But only push it if it is not already in the array
        for(i = 0;; i++)
        {
            if(i == fd.functiondefinitions.length)      // not in the array
            {
                fd.functiondefinitions ~= this;
                break;
            }
            if(fd.functiondefinitions[i] is this)       // already in the array
                break;
        }

        //writefln("isglobal = %d, isanonymous = %d\n", isglobal, isanonymous);
        if(!isglobal)
        {
            sc = sc.push(this);
            sc.nestDepth++;
        }
        nestDepth = sc.nestDepth;
        //writefln("nestDepth = %d", nestDepth);

        if(topstatements.length)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                ts = topstatements[i];
                assert (ts !is null);
                if(ts.done < Progress.Semantic)
                {
                    ts = ts.semantic(sc);
                    // if(sc.exception !is null)
                    //     break;

                    // if(iseval)
                    // {
                        // There's an implied "return" on the last statement
                        if((i + 1) == topstatements.length)
                        {
                            ts = ts.ImpliedReturn();
                        }
                    // }
                    topstatements[i] = ts;
                    ts.done = Progress.Semantic;
                }
            }

            // Make sure all the LabelSymbol's are defined
            if(labtab !is null)
            {
                foreach(s; labtab.members)
                {
                    auto ls = cast(LabelSymbol)s;
                    assert(ls !is null);
                    if (ls.statement is null)
                        error(sc, UndefinedLabelError(ls.toString, toString));
                }
            }
        }

        if(!isglobal)
            sc.pop();

        return this;
    }

    override void toIR(IRstate*)
    {
        IRstate irs;
        uint i;

        irs.ctor;
        if(topstatements.length)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                TopStatement ts;

                ts = topstatements[i];
                if (auto fd = cast(FunctionDefinition)ts)
                {
                    if(fd.code)
                        continue;
                }
                ts.toIR(&irs);
            }

            // Don't need parse trees anymore, release to garbage collector
            topstatements[] = null;
            topstatements = null;
            labtab = null;                      // maybe delete it?
        }
        irs.gen!(Opcode.Ret)(0);
        irs.gen!(Opcode.End)(0);

        //irs.validate();

        irs.doFixups();
        irs.optimize();

        code = cast(IR*)irs.codebuf.data;
        irs.codebuf.data = null;
        nlocals = irs.lvm.max;
    }

    final
    void instantiate(CallContext* cc, Property.Attribute attributes)
    {
        alias PA = Property.Attribute;
        // Instantiate all the Var's per 10.1.3
        auto actobj = cc.variable;
        auto val = vundefined;
        foreach(name; varnames)
        {
            // If name is already declared, don't override it
            actobj.DefineOwnProperty(
                PropertyKey(name.toString), val,
                PA.Instantiate | PA.DontOverride | attributes);
        }

        // Instantiate the Function's per 10.1.3
        foreach(FunctionDefinition fd; functiondefinitions)
        {

            // Set [[Scope]] property per 13.2 step 7
            auto fobject = new DdeclaredFunction(cc.realm, fd, cc.save);
            val.put(fobject);
            // skip anonymous functions
            if(fd.name !is null && !fd.isliteral && !fd.isglobal)
            {
                actobj.DefineOwnProperty(
                    *fd.name, val, PA.Instantiate | attributes);
            }
        }
    }


    override void toBuffer(scope void delegate(in char[]) sink) const
    {
        if(!isglobal)
        {
            sink("function ");
            if(isAnonymous)
                sink("anonymous");
            else if(name)
                sink(name.toString);
            sink("(");
            for(size_t i = 0; i < parameters.length; i++)
            {
                if(0 < i)
                    sink(",");
                sink(parameters[i].toString);
            }
            sink("){ ");
        }
        if(topstatements)
        {
            foreach (one; topstatements)
                one.toBuffer(sink);
        }
        if(!isglobal)
        {
            sink("}\n");
        }
    }

    debug static
    void dump (FunctionDefinition f, scope void delegate(in char[]) sink,
               size_t indent = 0)
    {
        import std.range: take, repeat;
        import std.conv: to;
        import dmdscript.opcodes: IR;

        assert (f !is null);
        if (f.name !is null)
        {
            sink(' '.repeat.take(indent).to!string);
            sink("function ");
            sink(f.name.toString);
        }
        sink("\n");
        IR.dump(f.code, sink, indent);

        for (size_t i = 0; i < f.functiondefinitions.length; ++i)
        {
            if (f.functiondefinitions[i] is f)
                continue;
            dump(f.functiondefinitions[i], sink, indent + 2);
        }
    }
}
