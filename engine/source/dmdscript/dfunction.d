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

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.scopex;
import dmdscript.dnative;
import dmdscript.functiondefinition;
import dmdscript.parse;
import dmdscript.ddeclaredfunction;

/* ===================== Dfunction_constructor ==================== */

class DfunctionConstructor : Dconstructor
{
    this()
    {
        super(1, Dfunction.getPrototype);

        // Actually put in later by Dfunction::initialize()
        //unsigned attributes = DontEnum | DontDelete | ReadOnly;
        //Put(TEXT_prototype, Dfunction::getPrototype(), attributes);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.3.2.1
        d_string bdy;
        d_string P;
        FunctionDefinition fd;
        ScriptException exception;

        //writef("Dfunction_constructor::Construct()\n");

        // Get parameter list (P) and body from arglist[]
        if(arglist.length)
        {
            bdy = arglist[arglist.length - 1].toString();
            if(arglist.length >= 2)
            {
                for(uint a = 0; a < arglist.length - 1; a++)
                {
                    if(a)
                        P ~= ',';
                    P ~= arglist[a].toString();
                }
            }
        }

        if((exception = Parser.parseFunctionDefinition(fd, P, bdy)) !is null)
            goto Lsyntaxerror;

        if(fd)
        {
            Scope sc;

            sc.ctor(fd);
            fd.semantic(&sc);
            exception = sc.exception;
            if(exception !is null)
                goto Lsyntaxerror;
            fd.toIR(null);
            Dfunction fobj = new DdeclaredFunction(fd);
            assert(cc.scoperoot <= cc.scopex.length);
            fobj.scopex = cc.scopex[0..cc.scoperoot].dup;
            ret.put(fobj);
        }
        else
            ret.putVundefined();

        return null;

        Lsyntaxerror:
        Dobject o;

        ret.putVundefined();
        o = new syntaxerror.D0(exception);
        auto v = new DError;
        v.put(o);
        return v;
    }
}


/* ===================== Dfunction_prototype_toString =============== */

DError* Dfunction_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
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
        return TsNotTransferrableError;
    }
    return null;
}

/* ===================== Dfunction_prototype_apply =============== */

DError* Dfunction_prototype_apply(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.3

    import core.sys.posix.stdlib : alloca;
    import dmdscript.darray : Darray;
    import dmdscript.darguments : Darguments;

    Value* thisArg;
    Value* argArray;
    Dobject o;
    DError* v;

    thisArg = &vundefined;
    argArray = &vundefined;
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
        o = cc.global;
    else
        o = thisArg.toObject();

    if(argArray.isUndefinedOrNull())
    {
        v = othis.Call(cc, o, ret, null);
    }
    else
    {
        if(argArray.isPrimitive())
        {
            Ltypeerror:
            ret.putVundefined();
            return ArrayArgsError;
        }
        Dobject a;

        a = argArray.toObject();

        // Must be array or arguments object
        if(((cast(Darray)a) is null) && ((cast(Darguments)a) is null))
            goto Ltypeerror;

        uint len;
        uint i;
        Value[] alist;
        Value* x;

        x = a.Get(Key.length, cc);
        len = x ? x.toUint32(cc) : 0;

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
            x = a.Get(i, cc);
            alist[i] = *x;
        }

        v = othis.Call(cc, o, ret, alist);

        delete p1;
    }
    return v;
}

/* ===================== Dfunction_prototype_call =============== */

DError* Dfunction_prototype_call(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.3.4.4
    Value* thisArg;
    Dobject o;
    DError* v;

    if(arglist.length == 0)
    {
        o = cc.global;
        v = othis.Call(cc, o, ret, arglist);
    }
    else
    {
        thisArg = &arglist[0];
        if(thisArg.isUndefinedOrNull())
            o = cc.global;
        else
            o = thisArg.toObject();
        v = othis.Call(cc, o, ret, arglist[1 .. $]);
    }
    return v;
}

/* ===================== Dfunction_prototype ==================== */

class DfunctionPrototype : Dfunction
{
    this()
    {
        super(0, Dobject.getPrototype);

        auto attributes = Property.Attribute.DontEnum;

        name = "prototype";
        DefineOwnProperty(Key.constructor, Dfunction.getConstructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { Key.toString, &Dfunction_prototype_toString, 0 },
            { Key.apply, &Dfunction_prototype_apply, 2 },
            { Key.call, &Dfunction_prototype_call, 1 },
        ];

        DnativeFunction.initialize(this, nfd, attributes);
    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA v3 15.3.4
        // Accept any arguments and return "undefined"
        ret.putVundefined();
        return null;
    }
}


/* ===================== Dfunction ==================== */

abstract class Dfunction : Dobject
{
    Dobject[] scopex;     // Function object's scope chain per 13.2 step 7

    override abstract
    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist);

    //
    override immutable(char)[] getTypeof()
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
    override DError* HasInstance(ref CallContext cc, out Value ret, ref Value v)
    {
        import std.conv : to;

        // ECMA v3 15.3.5.3
        Dobject V;
        Value* w;
        Dobject o;

        if(v.isPrimitive())
            goto Lfalse;
        V = v.toObject();
        w = Get(Key.prototype, cc);
        if(w.isPrimitive())
        {
            return MustBeObjectError(w.type.to!d_string);
        }
        o = w.toObject();
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

protected:
    const(tchar)[] name;

    //
    this(d_uint32 length)
    {
        this(length, Dfunction.getPrototype());
    }

    //
    this(d_uint32 length, Dobject prototype)
    {
        this(Key.Function, length, prototype);
    }

    //
    this(d_string name, d_uint32 length, Dobject prototype)
    {
        super(prototype, Key.Function);
        this.name = name;
        CallContext cc;
        Set(Key.length, length,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum |
            Property.Attribute.ReadOnly, cc);
        Set(Key.arity, length,
            Property.Attribute.DontDelete |
            Property.Attribute.DontEnum |
            Property.Attribute.ReadOnly, cc);
    }


public static:
    //
    Dfunction isFunction(Value* v)
    {
        if (v.isPrimitive)
            return null;
        else
            return cast(Dfunction)v.toObject;
    }

    //
    @safe @nogc nothrow
    Dfunction getConstructor()
    {
        return _constructor;
    }

    //
    @safe @nogc nothrow
    Dobject getPrototype()
    {
        return _prototype;
    }

    //
    void initialize()
    {
        _constructor = new DfunctionConstructor();
        _prototype = new DfunctionPrototype();

        _constructor.DefineOwnProperty(Key.prototype, _prototype,
                            Property.Attribute.DontEnum |
                            Property.Attribute.DontDelete |
                            Property.Attribute.ReadOnly);

        _constructor.SetPrototypeOf = _prototype;
        _constructor.proptable.previous = _prototype.proptable;
    }
private static:
    Dfunction _constructor;
    Dobject _prototype;
}

//
abstract class Dconstructor : Dfunction
{
    //
    abstract override
    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist);


    //
    override
    DError* Call(ref CallContext cc, Dobject, out Value ret, Value[] arglist)
    {
        // ECMA 15.3.1
        return Construct(cc, ret, arglist);
    }

protected:
    //
    this(d_uint32 length, Dobject prototype)
    {
        super(length, prototype);
    }

    //
    this(d_string name, d_uint32 length, Dobject prototype)
    {
        super(name, length, prototype);
    }
}
