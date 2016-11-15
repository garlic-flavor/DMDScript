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


module dmdscript.symbol;

debug import std.stdio;

import dmdscript.script;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.statement;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.errmsgs;

/****************************** Symbol ******************************/

class Symbol
{
    Identifier* ident;

    @safe @nogc pure nothrow
    this() const
    {
    }

    @safe @nogc pure nothrow
    this(Identifier* ident)
    {
        this.ident = ident;
    }

    void semantic(Scope* sc)
    {
        assert(0);
    }

    Symbol search(Identifier* ident)
    {
        assert(0);
        //error(DTEXT("%s.%s is undefined"),toString(), ident.toString());
    }

    final override @safe @nogc pure nothrow
    bool opEquals(Object o) const
    {
        if(this is o)
            return true;
        auto s = cast(Symbol)o;
        if(s && ident == s.ident)
            return true;
        return false;
    }

    final override @safe @nogc pure nothrow
    string toString() const
    {
        return ident ? "__ident" : "__anonymous";
    }

    final
    void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(toString);
    }
}




/****************************** SymbolTable ******************************/

// Table of Symbol's
struct SymbolTable
{
    Symbol[Identifier*] members;

    // Look up Identifier. Return Symbol if found, NULL if not.
    @safe @nogc pure nothrow
    Symbol lookup(Identifier* ident)
    {
        if (auto ps = ident in members)
            return *ps;
        return null;
    }

    // Insert Symbol in table. Return NULL if already there.
    @safe pure nothrow
    Symbol insert(Symbol s)
    {
        if (s.ident in members)
            return null;        // already in table
        members[s.ident] = s;
        return s;
    }

    // Look for Symbol in table. If there, return it.
    // If not, insert s and return that.
    @safe pure nothrow
    Symbol update(Symbol s)
    {
        members[s.ident] = s;
        return s;
    }
}

/****************************** LabelSymbol ******************************/
class LabelSymbol : Symbol
{
    Loc loc;
    LabelStatement statement;

    @safe @nogc pure nothrow
    this(Loc loc, Identifier* ident, LabelStatement statement)
    {
        super(ident);
        this.loc = loc;
        this.statement = statement;
    }
}


//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// belows are not used.

/********************************* ScopeSymbol ****************************/
// Symbol that generates a scope

// deprecated
// class ScopeSymbol : Symbol
// {
//     Symbol[] members;           // all Symbol's in this scope
//     SymbolTable* symtab;        // member[] sorted into table

//     @safe @nogc pure nothrow
//     this() const
//     {
//         super();
//     }

//     @safe @nogc pure nothrow
//     this(Identifier* id)
//     {
//         super(id);
//     }

//     override final @safe @nogc pure nothrow
//     Symbol search(Identifier* ident)
//     {
//         // Look in symbols declared in this module
//         return symtab ? symtab.lookup(ident) : null;
//     }
// }
/****************************** FunctionSymbol ******************************/

// deprecated
// class FunctionSymbol : ScopeSymbol
// {
//     Loc loc;

//     Identifier*[] parameters;     // array of Identifier's
//     TopStatement[] topstatements; // array of TopStatement's

//     SymbolTable labtab;           // symbol table for LabelSymbol's

//     IR *code;
//     uint nlocals;

//     @safe @nogc pure nothrow
//     this(Loc loc, Identifier* ident, Identifier*[] parameters,
//          TopStatement[] topstatements)
//     {
//         super(ident);
//         this.loc = loc;
//         this.parameters = parameters;
//         this.topstatements = topstatements;
//     }

//     override final @safe @nogc pure nothrow
//     void semantic(Scope* sc)
//     {
//     }
// }
