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

import dmdscript.script;
import dmdscript.identifier;
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

    Identifier* name;             // null for anonymous function
    Identifier*[] parameters;     // array of Identifier's
    TopStatement[] topstatements; // array of TopStatement's

    Identifier*[] varnames;       // array of Identifier's
    private FunctionDefinition[] functiondefinitions;
    private FunctionDefinition enclosingFunction;
    private int nestDepth;
    int withdepth;              // max nesting of ScopeStatement's

    SymbolTable* labtab;        // symbol table for LabelSymbol's

    IR* code;
    uint nlocals;

    d_string srctext;

    @safe @nogc pure nothrow
    this(TopStatement[] topstatements)
    {
        super(0);
        st = StatementType.FunctionDefinition;
        this.isglobal = 1;
        this.topstatements = topstatements;
    }

    @safe @nogc pure nothrow
    this(d_string srctext, Loc loc, bool isglobal, Identifier*  name,
         Identifier*[] parameters, TopStatement[] topstatements)
    {
        super(loc);

        //writef("FunctionDefinition('%ls')\n", name ? name.string : L"");
        st = StatementType.FunctionDefinition;
        this.srctext = srctext;
        this.isglobal = isglobal;
        this.name = name;
        this.parameters = parameters;
        this.topstatements = topstatements;
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

        //writef("FunctionDefinition::semantic(%s)\n", this);

        // Log all the FunctionDefinition's so we can rapidly
        // instantiate them at runtime
        fd = enclosingFunction = sc.funcdef;

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
                //writefln("calling semantic routine %d which is %x\n",i, cast(uint)cast(void*)ts);
                if(ts.done < Progress.Semantic)
                {
                    ts = ts.semantic(sc);
                    if(sc.exception !is null)
                        break;

                    if(iseval)
                    {
                        // There's an implied "return" on the last statement
                        if((i + 1) == topstatements.length)
                        {
                            ts = ts.ImpliedReturn();
                        }
                    }
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

        //writefln("FunctionDefinition.toIR() done = %d", done);
        irs.ctor;
        if(topstatements.length)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                TopStatement ts;
                FunctionDefinition fd;

                ts = topstatements[i];
                if(ts.st == StatementType.FunctionDefinition)
                {
                    fd = cast(FunctionDefinition)ts;
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

/+
    deprecated
    final
    void instantiate(Dobject[] scopex, Dobject actobj,
                     Property.Attribute attributes)
    {
        // Instantiate all the Var's per 10.1.3
        CallContext cc;
        foreach(Identifier* name; varnames)
        {
            // If name is already declared, don't override it
            actobj.Put(name.toString, vundefined,
                       Property.Attribute.Instantiate |
                       Property.Attribute.DontOverride | attributes, cc);
        }

        // Instantiate the Function's per 10.1.3
        foreach(FunctionDefinition fd; functiondefinitions)
        {
            // Set [[Scope]] property per 13.2 step 7
            Dfunction fobject = new DdeclaredFunction(fd);
            fobject.scopex = scopex;

            if(fd.name !is null && !fd.isliteral) // skip anonymous functions
            {
                actobj.Put(fd.name.toString, fobject,
                           Property.Attribute.Instantiate | attributes, cc);
            }
        }
    }
+/

    final
    void instantiate(ref CallContext cc, Property.Attribute attributes)
    {
        // Instantiate all the Var's per 10.1.3
        auto actobj = cc.variable;
        foreach(Identifier* name; varnames)
        {
            // If name is already declared, don't override it
            actobj.Set(name.toString, vundefined,
                       Property.Attribute.Instantiate |
                       Property.Attribute.DontOverride | attributes, cc);
        }

        // Instantiate the Function's per 10.1.3
        foreach(FunctionDefinition fd; functiondefinitions)
        {
            // Set [[Scope]] property per 13.2 step 7
            Dfunction fobject = new DdeclaredFunction(fd);
            fobject.scopex = cc.scopex;

            if(fd.name !is null && !fd.isliteral) // skip anonymous functions
            {
                actobj.Set(fd.name.toString, fobject,
                           Property.Attribute.Instantiate | attributes, cc);
            }
        }
    }


    override void toBuffer(scope void delegate(in tchar[]) sink) const
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
            sink(")\n{ \n");
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
}
