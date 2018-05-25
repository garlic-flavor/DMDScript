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

module dmdscript.callcontext;

debug import std.stdio;

import dmdscript.dobject : Dobject;
import dmdscript.drealm: Drealm;

//------------------------------------------------------------------------------
///
class DefinedFunctionScope
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.functiondefinition : FunctionDefinition;

    Stack _stack;      ///
    alias _stack this; ///

    ///
    @safe pure nothrow
    this(Dobject[] superScopes, Dobject actobj, Dfunction caller,
         FunctionDefinition callerf, Dobject callerothis)
    {
        assert (callerothis !is null);
        assert (callerf !is null);

        _stack = Stack(superScopes, actobj);
        _caller = caller;
        _callerf = callerf;
        _callerothis = callerothis;
    }


    @property @safe @nogc pure nothrow
    {
        ///
        inout(Dfunction) caller() inout
        {
            return _caller;
        }

        ///
        inout(FunctionDefinition) callerf() inout
        {
            return _callerf;
        }

        ///
        inout(Dobject) callerothis() inout
        {
            return _callerothis;
        }

        ///
        bool strictMode() const
        {
            assert (_callerf !is null);
            return _callerf.strictMode;
        }
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    Dfunction _caller;
    FunctionDefinition _callerf;
    Dobject _callerothis;
}

package:

//..............................................................................
//
struct Stack
{
    import std.array: Appender;
    import dmdscript.primitive: PropertyKey;
    import dmdscript.property: Property;
    import dmdscript.value: Value, DError;

    //--------------------------------------------------------------------
    //
    @safe pure nothrow
    this(Dobject[] superScopes, Dobject root)
    {
        assert (root !is null);

        _stack.reserve(superScopes.length + 1);
        _stack.put(superScopes);
        _stack.put(root);

        _initialSize = _stack.data.length;
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject)[] stack() inout
    {
        return _stack.data;
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject) global() inout
    {
        assert (0 < _stack.data.length);
        return _stack.data[0];
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    inout(Dobject) rootScope() inout
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1];
    }

    //--------------------------------------------------------------------
    //
    @safe @nogc pure nothrow
    inout(Dobject) getNonFakeObject() inout
    {
        auto data = _stack.data;
        for (auto i = data.length; _initialSize <= i; --i)
        {
            auto o = stack[i-1];
            if (o.getTypeof !is null)
                return o;
        }
        assert (0);
    }

    //--------------------------------------------------------------------
    //
    @property @safe @nogc pure nothrow
    bool isRoot() const
    {
        return _stack.data.length <= _initialSize;
    }

    //--------------------------------------------------------------------
    //
    @safe pure nothrow
    void push(Dobject o)
    {
        _stack.put(o);
    }

    //--------------------------------------------------------------------
    //
    @safe pure
    Dobject pop()
    {
        auto data = _stack.data;
        if (data.length <= _initialSize)
            return null;

        auto ret = data[$-1];
        _stack.shrinkTo(data.length - 1);
        return ret;
    }

    //--------------------------------------------------------------------
    //
    Value* get(Drealm realm, in ref PropertyKey key, out Dobject pthis)
    {
        Value* v;
        Dobject o;

        auto stack = _stack.data;
        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                o = stack[d - 1];
                v = o.Get(key, realm);
                if (v !is null)
                    break;
            }
            else
            {
                o = null;
                break;
            }
        }
        pthis = o;
        return v;
    }

    //--------------------------------------------------------------------
    //
    Value* get(Drealm realm, in ref PropertyKey key)
    {
        auto stack = _stack.data;
        for (size_t d = stack.length; 0 < d; --d)
        {
            if (auto v = stack[d-1].Get(key, realm))
                return v;
        }
        return null;
    }

    //--------------------------------------------------------------------
    //
    DError* set(Drealm realm, in ref PropertyKey key, ref Value value,
                   Property.Attribute attr = Property.Attribute.None)
    {
        import dmdscript.property: Property;
        import dmdscript.errmsgs: CannotAssignToBeforeDeclarationError;

        auto stack = _stack.data;
        assert (0 < stack.length);

        for (size_t d = stack.length; ; --d)
        {
            if (0 < d)
            {
                auto o = stack[d - 1];
                if (auto v = o.Get(key, realm))
                {
                    if (auto err = v.checkReference(realm))
                        return err;
                    else
                        return o.Set(key, value, attr, realm);
                }
            }
            else if (realm.strictMode)
            {
                return CannotAssignToBeforeDeclarationError(
                    realm, key.toString);
            }
            else
            {
                return stack[0].Set(key, value, attr, realm);
            }
        }
    }

    //--------------------------------------------------------------------
    //
    DError* setThis(Drealm realm, in ref PropertyKey key, ref Value value,
                    Property.Attribute attr)
    {
        assert (0 < _initialSize);
        assert (_initialSize <= _stack.data.length);
        return _stack.data[_initialSize - 1].Set(key, value, attr, realm);
    }

    //--------------------------------------------------------------------
    //
    DError* setThisLocal(Drealm realm, in ref PropertyKey key,
                         ref Value value, Property.Attribute attr)
    {
        assert (0 < _stack.data.length);
        return _stack.data[$-1].Set(key, value, attr, realm);
    }

    //--------------------------------------------------------------------
    //
    string[] searchSimilarWord(Drealm realm, string name)
    {
        import std.string : soundexer;
        import std.array : join;

        Appender!(string[][]) result;

        auto key = name.soundexer;
        foreach_reverse (one; _stack.data)
        {
            if (auto r = .searchSimilarWord(realm, one, key))
                result.put(r);
        }
        return result.data.join;
    }

    //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
private:
    immutable size_t _initialSize;
    Appender!(Dobject[]) _stack;
}

//..............................................................................
//
string[] searchSimilarWord(Drealm realm, Dobject target, in ref char[4] key)
{
    import std.array : Appender;
    import std.string : soundexer;

    Appender!(string[]) result;
    foreach (one; target.OwnPropertyKeys)
    {
        auto name = one.toString;
        if (name.soundexer == key) result.put(name);
    }
    if (auto p = target.GetPrototypeOf)
        return result.data ~ searchSimilarWord(realm, p, key);
    else
        return result.data;
}
