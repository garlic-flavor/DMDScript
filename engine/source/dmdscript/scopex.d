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


module dmdscript.scopex;

import dmdscript.primitive;
import dmdscript.callcontext;
import dmdscript.program;
import dmdscript.symbol;
import dmdscript.functiondefinition;
import dmdscript.statement;
import dmdscript.exception;
struct Scope
{
    Scope*             enclosing;    // enclosing Scope

    Program            program;      // Root module
    // deprecated ScopeSymbol*       scopesym;     // current symbol
    FunctionDefinition funcdef;      // what function we're in
    SymbolTable**      plabtab;      // pointer to label symbol table
    uint               nestDepth;    // static nesting level
    //
    ScopeStatement     scopeContext; // nesting of scope statements
    Statement          continueTarget;
    Statement          breakTarget;
    SwitchStatement    switchTarget;

    ScriptException exception; // semantic() puts error messages here

    @safe @nogc pure nothrow
    void zero()
    {
        enclosing = null;

        program = null;
        // scopesym = null;
        funcdef = null;
        plabtab = null;
        nestDepth = 0;

        scopeContext = null;
        continueTarget = null;
        breakTarget = null;
        switchTarget = null;
    }

    @safe @nogc pure nothrow
    void ctor(Scope* enclosing)
    {
        zero();
        this.program = enclosing.program;
        this.funcdef = enclosing.funcdef;
        this.plabtab = enclosing.plabtab;
        this.nestDepth = enclosing.nestDepth;
        this.enclosing = enclosing;
    }

    @safe @nogc pure nothrow
    void ctor(Program program, FunctionDefinition fd)
    {   // Create root scope
        zero();
        this.program = program;
        this.funcdef = fd;
        this.plabtab = &fd.labtab;
    }

    @safe @nogc pure nothrow
    void ctor(FunctionDefinition fd)
    {   // Create scope for anonymous function fd
        zero();
        this.funcdef = fd;
        this.plabtab = &fd.labtab;
    }

    @safe @nogc pure nothrow
    void dtor()
    {
        // Help garbage collector
        zero();
    }

    @safe pure nothrow
    Scope* push()
    {
        Scope* s;

        s = new Scope;
        s.ctor(&this);
        return s;
    }
    @safe pure nothrow
    Scope* push(FunctionDefinition fd)
    {
        Scope* s;

        s = push();
        s.funcdef = fd;
        s.plabtab = &fd.labtab;
        return s;
    }

    @safe @nogc pure nothrow
    void pop()
    {
        if(enclosing !is null && enclosing.exception is null)
            enclosing.exception = exception;
        zero();                 // aid GC
    }

    // deprecated
    // @safe @nogc pure nothrow
    // Symbol search(Identifier* ident)
    // {
    //     for(auto sc = &this; sc; sc = sc.enclosing)
    //     {
    //         if (auto s = sc.scopesym.search(ident))
    //             return s;
    //     }
    //     assert(0);
    // }

    // deprecated
    // Symbol insert(Symbol s)
    // {
    //     if(!scopesym.symtab)
    //         scopesym.symtab = new SymbolTable();
    //     return scopesym.symtab.insert(s);
    // }

    @safe pure nothrow
    LabelSymbol searchLabel(Identifier ident)
    {
        SymbolTable* st;
        LabelSymbol ls;

        //writef("Scope::searchLabel('%ls')\n", ident.toDchars());
        assert(plabtab);
        st = *plabtab;
        if(!st)
        {
            st = new SymbolTable();
            *plabtab = st;
        }
        ls = cast(LabelSymbol)st.lookup(ident);
        return ls;
    }

    @safe pure nothrow
    LabelSymbol insertLabel(LabelSymbol ls)
    {
        SymbolTable *st;

        //writef("Scope::insertLabel('%s')\n", ls.toString());
        assert(plabtab);
        st = *plabtab;
        if(!st)
        {
            st = new SymbolTable();
            *plabtab = st;
        }
        ls = cast(LabelSymbol)st.insert(ls);
        return ls;
    }
}

