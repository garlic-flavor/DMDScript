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


module dmdscript.dfunction;

import dmdscript.dobject: Dobject;
import dmdscript.value: DError, Value;
import dmdscript.errmsgs;
import dmdscript.primitive: Key;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: Drealm;
debug import std.stdio;

//==============================================================================
///
abstract class Dfunction : Dobject
{
    import dmdscript.primitive : Text, Key, PropertyKey;

    @disable
    enum Kind
    {
        normal,
        classConstructor,
        generator,
    }

    @disable
    enum ConstructorKind
    {
        base,
        derived,
    }

    @disable
    Dobject HomeObject;

    override abstract
    DError* Call(Drealm realm, Dobject othis, out Value ret,
                 Value[] arglist);

    //
    override string getTypeof() const
    {     // ECMA 11.4.3
        return Text._function;
    }

    //
    override string toString()
    {
        import std.string : format;
        // Native overrides of this function replace Identifier with the actual name.
        // Don't need to do parameter list, though.
        immutable(char)[] s;

        s = format("function %s() { [native code] }", name);
        return s;
    }

    //
    override DError* HasInstance(Drealm realm, out Value ret, ref Value v)
    {
        import std.conv : to;

        // ECMA v3 15.3.5.3
        Dobject V;
        Value* w;
        Dobject o;

        if(v.isPrimitive())
            goto Lfalse;
        V = v.toObject(realm);
        w = Get(Key.prototype, realm);
        if(w.isPrimitive())
        {
            return MustBeObjectError(realm, w.type.to!string);
        }
        o = w.toObject(realm);
        for(;; )
        {
            V = V.GetPrototypeOf;
            if(!V)
                goto Lfalse;
            if(o == V)
                goto Ltrue;
        }

    Ltrue:
        ret.put(true);
        return null;

    Lfalse:
        ret.put(false);
        return null;
    }

    @disable
    bool OrdinaryHasInstance(Dobject o, Drealm realm)
    {
        if (auto btf = cast(BoundFunctionExoticObject)this)
        {
            return o.InstanceofOperator(this, realm);
        }
        auto p = Get(Key.prototype, realm);
        assert(p && p.object);

        debug size_t loopCounter = 0;
        for(;;)
        {
            o = o.GetPrototypeOf;
            if (o is null)
                return false;
            if (p.object is o)
                return true;
            assert(++loopCounter < 100);
        }
        assert(0);
    }


    @property @safe @nogc pure nothrow
    inout(PropertyKey) name() inout
    {
        return _name;
    }

protected:
    PropertyKey _name;

    //
    this(Dobject prototype, PropertyKey name, uint length)
    {
        import dmdscript.property : Property;

        super(prototype, Key.Function);
        _name = name;

        Value val;
        val.put(length);
        DefineOwnProperty(Key.length, val,
                          Property.Attribute.DontDelete |
                          Property.Attribute.DontEnum |
                          Property.Attribute.ReadOnly);
        val.put(name);
        DefineOwnProperty(Key.name, val,
                          Property.Attribute.DontDelete |
                          Property.Attribute.DontEnum |
                          Property.Attribute.ReadOnly);

        // Set(Key.arity, length,
        //     Property.Attribute.DontDelete |
        //     Property.Attribute.DontEnum |
        //     Property.Attribute.ReadOnly, cc);
    }


public static:
    //
    Dfunction isFunction(Drealm realm, Value* v)
    {
        if (v.isPrimitive)
            return null;
        else
            return cast(Dfunction)v.toObject(realm);
    }
}

//------------------------------------------------------------------------------
abstract class Dconstructor : Dfunction
{
    //
    abstract override
    DError* Construct(Drealm realm, out Value ret, Value[] arglist);


    //
    override
    DError* Call(Drealm realm, Dobject, out Value ret, Value[] arglist)
    {
        // ECMA 15.3.1
        return Construct(realm, ret, arglist);
    }

    @property @safe @nogc pure nothrow
    inout(Dobject) classPrototype() inout
    {
        assert (_classPrototype !is null);
        return _classPrototype;
    }

protected:

    //
    this(Dobject classPrototype, Dobject functionPrototype,
         PropertyKey name, uint length)
    {
        import dmdscript.property: Property;

        super(functionPrototype, name, length);
        _classPrototype = classPrototype;

        Value val;
        val.put(this);
        _classPrototype.DefineOwnProperty (Key.constructor, val,
                                           Property.Attribute.DontEnum);
        val.put(_classPrototype);
        DefineOwnProperty (Key.prototype, val,
                           Property.Attribute.DontEnum |
                           Property.Attribute.DontDelete |
                           Property.Attribute.ReadOnly);
    }

    //
    template install()
    {
        void install(string M = __MODULE__)(Dobject functionPrototype)
        {
            import dmdscript.dnative: _i = install;
            assert (proptable !is null);
            assert (_classPrototype !is null);
            mixin("import " ~ M ~ ";");
            _i!(mixin(M))(this, functionPrototype);
            _i!(mixin(M))(_classPrototype, functionPrototype);
        }
    }
private:
    Dobject _classPrototype;
}

//------------------------------------------------------------------------------
class DfunctionConstructor : Dconstructor
{
    this(Dobject, Dobject functionPrototype)
    {
        super(functionPrototype, functionPrototype, Key.Function, 1);

        install(functionPrototype);
    }

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.functiondefinition : FunctionDefinition;
        import dmdscript.exception : ScriptException;
        import dmdscript.lexer : Mode;
        import dmdscript.parse : Parser;
        import dmdscript.scopex : Scope;
        import dmdscript.ddeclaredfunction : DdeclaredFunction;
        import dmdscript.protoerror;

        // ECMA 15.3.2.1
        string bdy;
        string P;
        FunctionDefinition fd;
        ScriptException exception;

        // Get parameter list (P) and body from arglist[]
        if(arglist.length)
        {
            bdy = arglist[arglist.length - 1].toString(realm);
            if(arglist.length >= 2)
            {
                for(uint a = 0; a < arglist.length - 1; a++)
                {
                    if(a)
                        P ~= ',';
                    P ~= arglist[a].toString(realm);
                }
            }
        }

        if((exception = Parser!(Mode.None).parseFunctionDefinition(
                realm.id, fd, P, bdy)) !is null)
            goto Lsyntaxerror;

        if(fd !is null)
        {
            Scope sc;

            sc.ctor(fd);
            fd.semantic(&sc);
            exception = sc.exception;
            if(exception !is null)
                goto Lsyntaxerror;
            fd.toIR(null);
            auto fobj = new DdeclaredFunction(
                realm, fd, realm.scopes.dup);
            // fobj.scopex = cc.scopex[0..cc.scoperoot].dup;
            // fobj.scopex = cc.scopes.dup;
            ret.put(fobj);
        }
        else
            ret.putVundefined();

        return null;

        Lsyntaxerror:
        Dobject o;

        ret.putVundefined();
        o = realm.dSyntaxError(exception);
        auto v = new DError;
        v.put(o);
        return v;
    }
}


//==============================================================================
private:

//------------------------------------------------------------------------------
//
@DFD(0)
DError* toString(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a Function
    if (auto f = cast(Dfunction)othis)
    {
        // Generate string that looks like a FunctionDeclaration
        // FunctionDeclaration:
        //	function Identifier (Identifier, ...) Block

        // If anonymous function, the name should be "anonymous"
        // per ECMA 15.3.2.1.19

        auto s = f.toString;
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        return TsNotTransferrableError(realm);
    }
    return null;
}

//------------------------------------------------------------------------------
//
@DFD(2)
DError* apply(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.3

    import core.sys.posix.stdlib: alloca;
    import dmdscript.primitive: Key, PropertyKey;
    import dmdscript.darray: Darray;
    import dmdscript.darguments: Darguments;
    import dmdscript.value: vundefined;
    import dmdscript.drealm: undefined;

    Value* thisArg;
    Value* argArray;
    Dobject o;
    DError* v;

    thisArg = &undefined;
    argArray = &undefined;
    switch(arglist.length)
    {
    case 0:
        break;
    default:
        argArray = &arglist[1];
        goto case;
    case 1:
        thisArg = &arglist[0];
        break;
    }

    if(thisArg.isUndefinedOrNull())
        o = realm;
    else
        o = thisArg.toObject(realm);

    if(argArray.isUndefinedOrNull())
    {
        v = othis.Call(realm, o, ret, null);
    }
    else
    {
        if(argArray.isPrimitive())
        {
            Ltypeerror:
            ret.putVundefined();
            return ArrayArgsError(realm);
        }
        Dobject a;

        a = argArray.toObject(realm);

        // Must be array or arguments object
        if(((cast(Darray)a) is null) && ((cast(Darguments)a) is null))
            goto Ltypeerror;

        uint len;
        uint i;
        Value[] alist;
        Value* x;

        x = a.Get(Key.length, realm);
        len = x ? x.toUint32(realm) : 0;

        Value[] p1;
        Value* v1;
        if(len < 128)
            v1 = cast(Value*)alloca(len * Value.sizeof);
        if(v1)
            alist = v1[0 .. len];
        else
        {
            p1 = new Value[len];
            alist = p1;
        }

        for(i = 0; i < len; i++)
        {
            x = a.Get(PropertyKey(i), realm);
            alist[i] = *x;
        }

        v = othis.Call(realm, o, ret, alist);

        p1.destroy; p1 = null;
    }
    return v;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* bind(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert(0);
}


//------------------------------------------------------------------------------
//
@DFD(1)
DError* call(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.4
    Value* thisArg;
    Dobject o;
    DError* v;

    if(arglist.length == 0)
    {
        o = realm;
        v = othis.Call(realm, o, ret, arglist);
    }
    else
    {
        thisArg = &arglist[0];
        if(thisArg.isUndefinedOrNull())
            o = realm;
        else
            o = thisArg.toObject(realm);
        v = othis.Call(realm, o, ret, arglist[1 .. $]);
    }
    return v;
}


//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// for temp use

//
interface BoundFunctionExoticObject
{
    Dobject BoundTargetFunction();
    Value BoundThis();
    Value[] BoundArguments();
}
