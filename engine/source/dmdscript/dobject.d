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

module dmdscript.dobject;

import dmdscript.primitive: Key;
import dmdscript.value: Value;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, ArgList,
    DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: Drealm;
import dmdscript.errmsgs;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror, onError;

debug import std.stdio;
//debug = LOG;

//==============================================================================
class Dobject
{
    import dmdscript.primitive: Text, Identifier, PropertyKey;
    import dmdscript.property: Property, PropTable;
    alias PA = Property.Attribute;
    import dmdscript.dfunction: Dfunction;

    PropTable proptable;
    Value value;

    //--------------------------------------------------------------------
    //
    final @property @safe @nogc pure nothrow
    PropertyKey classname() const
    {
        return _classname;
    }

    /// Ecma-262-v7/9.1.1
    @property @safe @nogc pure nothrow
    Dobject GetPrototypeOf()
    {
        return _prototype;
    }

    /// Ecma-262-v7/9.1.2
    @safe pure nothrow
    bool SetPrototypeOf(Dobject p)
    {
        if (!_extensible)
            return false;

        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // How can I implement this?
        //i. If the [[GetPrototypeOf]] internal method of p is not the ordinary object internal method defined in 9.1.1, let done be true.

        for (auto pp = p; pp !is null; pp = pp.GetPrototypeOf)
        {
            if (pp is this)
                return false;
        }
        _prototype = p;
        if (p !is null)
            proptable.previous(p.proptable);
        return true;
    }

    /// Ecma-262-v7/9.1.3
    nothrow
    bool IsExtensible() const
    {
        return _extensible;
    }

    /// Ecma-262-v7/9.1.4
    nothrow
    bool preventExtensions()
    {
        _extensible = false;
        return true;
    }

    /// Ecma-262-v7/9.1.5
    @safe @nogc pure nothrow
    Property* GetOwnProperty(in PropertyKey key)
    {
        return proptable.getOwnProperty(key);
    }

    /// Ecma-262-v7/9.1.7
    nothrow
    bool HasProperty(in PropertyKey name)
    {
        return proptable.getProperty(name) !is null;
    }

    ///
    @safe @nogc pure nothrow
    Property* GetProperty(in ref PropertyKey key)
    {
        return proptable.getProperty(key);
    }

    //--------------------------------------------------------------------
    //
    nothrow
    Derror Get(in PropertyKey PropertyName, out Value ret, CallContext* cc)
    {
        return proptable.get(PropertyName, ret, this, cc);
    }

    //--------------------------------------------------------------------

    //
    nothrow
    Derror Set(in PropertyKey PropertyName, ref Value value,
                in Property.Attribute attributes, CallContext* cc)
    {
        // ECMA 8.6.2.2
        auto a = cast(PA)(attributes | (_extensible ? 0 : PA.DontExtend));
        return proptable.set(PropertyName, value, this, a, cc);
    }

    //--------------------------------------------------------------------
    //
    nothrow
    bool SetGetter(in PropertyKey PropertyName, Dfunction getter,
                   in Property.Attribute attributes)
    {
        assert (getter !is null);
        auto a = cast(PA)(attributes | (_extensible ? 0 : PA.DontExtend));
        return proptable.configGetter(PropertyName, getter, a);
    }
    //
    nothrow
    bool SetSetter(in PropertyKey PropertyName, Dfunction setter,
                   in Property.Attribute attributes)
    {
        assert (setter !is null);
        auto a = cast(PA)(attributes | (_extensible ? 0 : PA.DontExtend));
        return proptable.configSetter(PropertyName, setter, a);
    }

    //--------------------------------------------------------------------
    //
    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */
    /// Ecma-262-v7/9.1.10
    bool Delete(in PropertyKey PropertyName)
    {
        // ECMA 8.6.2.5
        return proptable.del(PropertyName);
    }

    //--------------------------------------------------------------------
    ///
    @safe nothrow
    bool DefineOwnProperty(in PropertyKey PropertyName, Property* p)
    {
        return proptable.config(PropertyName, p, _extensible);
    }

    /// ditto
    @safe pure nothrow
    bool DefineOwnProperty(in PropertyKey PropertyName,
                           ref Value v, in Property.Attribute attributes)
    {
        auto p = new Property(v, attributes);
        return proptable.config(PropertyName, p, _extensible);
    }

    //
    @safe pure nothrow
    PropertyKey[] OwnPropertyKeys()
    {
        return proptable.keys;
    }

    nothrow
    Derror Call(CallContext* cc, Dobject othis, out Value ret, Value[] arglist)
    {
        return SNoCallError(cc, _classname);
    }

    nothrow
    Derror Construct(CallContext* cc, out Value ret, Value[] arglist)
    {
        return SNoConstructError(cc, _classname);
    }

    //--------------------------------------------------------------------
    nothrow
    Derror PutDefault(out Value value, CallContext* cc)
    {
        // Not ECMA, Microsoft extension
        return NoDefaultPutError(cc);
    }

    nothrow
    Derror put_Value(CallContext* cc, out Value ret, Value[] arglist)
    {
        // Not ECMA, Microsoft extension
        return FunctionNotLvalueError(cc);
    }

    nothrow
    int CanPut(in string PropertyName)
    {
        // ECMA 8.6.2.3
        auto key = PropertyKey(PropertyName);
        return proptable.canset(key);
    }

    bool implementsDelete()
    {
        // ECMA 8.6.2 says every object implements [[Delete]],
        // but ECMA 11.4.1 says that some objects may not.
        // Assume the former is correct.
        return true;
    }

    final @trusted nothrow
    Derror DefaultValue(out Value ret, CallContext* cc,
                         in Value.Type hint = Value.Type.RefError)
    {
        import dmdscript.ddate: Ddate;
        import dmdscript.property: SpecialSymbols;

        Derror err;
        Dobject o;
        Value v;
        Property* p;
        PropertyKey[] table =
            [SpecialSymbols.toPrimitive,
             cast(PropertyKey)Key.valueOf,
             cast(PropertyKey)Key.toString];
        int i = 0;                      // initializer necessary for /W4

        // ECMA 8.6.2.6
        if(hint == Value.Type.String ||
           (hint == Value.Type.RefError && (cast(Ddate)this) !is null))
        {
            i = 2;
        }
        else
        {
            i = 0;
        }

        for(int j = 0; j < 3; j++)
        {
            auto htab = table[i];

            if (Get(htab, v, cc).onError(err))
                return err;

            if      (v.isEmpty){}
            else if (v.isUndefined || v.isNull){}
            // if it's an Object
            else if (v.isCallable)
            {
                Derror a;
                Value[] args;

                o = v.object;
                args.length = 1;
                switch (hint)
                {
                case Value.Type.String:
                    args[0].put("string");
                    break;
                case Value.Type.Number:
                    args[0].put("number");
                    break;
                default:
                    args[0].put("default");
                    break;
                }

                if (o.Call(cc, this, ret, args).onError(a))
                    return a;                   // if exception was thrown

                if      (ret.isEmpty)
                {
                    ret.putVundefined;
                    return null;
                }
                else if (ret.isPrimitive)
                {
                    return null;
                }
                else if (i == 0)
                    break;
            }
            else if (i == 0)
                break;
            ++i;
            if (table.length <= i)
                i = 0;
        }
        return NoDefaultValueError(cc);
    }

    nothrow
    Derror HasInstance(ref Value v, out Value ret,  CallContext* cc)
    {   // ECMA v3 8.6.2
        return SNoInstanceError(cc, _classname);
    }

    @safe @nogc pure nothrow
    string getTypeof() const
    {   // ECMA 11.4.3
        return Text.object;
    }

    final @trusted nothrow
    Derror putIterator(out Value v, CallContext* cc)
    {
        import dmdscript.iterator : Iterator;

        auto i = new Iterator;

        i.ctor(this, cc);
        v.put(i);
        return null;
    }

    // //
    // @disable
    // DError CreateDataProperty(CallContext* cc, in PropertyKey name,
    //                            ref Value value)
    // {
    //     if (DefineOwnProperty(name, value, Property.Attribute.None))
    //         return null;
    //     else
    //         return CreateDataPropertyError(cc);
    // }

    // //
    // @disable
    // DError CreateMethodProperty(CallContext* cc,
    //                              in ref PropertyKey PropertyName,
    //                              ref Value value)
    // {
    //     if (DefineOwnProperty(PropertyName, value, Property.Attribute.DontEnum))
    //         return null;
    //     else
    //         return CreateMethodPropertyError(cc);
    // }

    // @disable
    // void CreateDataPropertyOrThrow(in ref PropertyKey PropertyName,
    //                                ref Value value)
    // {
    //     if (!DefineOwnProperty(PropertyName, value, Property.Attribute.None))
    //         throw CreateDataPropertyError.toThrow;
    // }

    // @disable
    // final
    // void DefinePropertyOrThrow(K, V)(in auto ref K name, auto ref V value,
    //                            in Property.Attribute attr)
    //     if (PropTable.IsKeyValue(K, V))
    // {
    //     if (!DefineOwnProperty(name, value, attr))
    //         throw CreateMethodPropertyError.toThrow;
    // }

    // @disable
    // void DefinePropertyOrThrow(in ref PropertyKey PropertyName,
    //                               in Property.Attribute attr)
    // {
    //     if (!DefineOwnProperty(PropertyName, attr))
    //         throw CreateMethodPropertyError.toThrow;
    // }

    // @disable
    // void DeletePropertyOrThrow(in PropertyKey PropertyName)
    // {
    //     if (!Delete(PropertyName))
    //         throw CantDeleteError.toThrow(PropertyName.toString);
    // }


    // @disable
    // bool HasOwnProperty(in ref PropertyKey PropertyName)
    // {
    //     return GetOwnProperty(PropertyName) !is null;
    // }


//     enum IntegrityLevel
//     {
//         zero, sealed, frozen,
//     }

//     @disable
//     bool SetIntegrityLevel(in IntegrityLevel il)
//     {
//         if (!preventExtensions)
//             return false;
//         auto keys = OwnPropertyKeys;
//         if      (il == IntegrityLevel.sealed)
//         {
//             foreach(ref one; keys)
//                 DefinePropertyOrThrow(one, Property.Attribute.DontConfig);
//         }
//         else if (il == IntegrityLevel.frozen)
//         {
//             foreach(ref one; keys)
//             {
//                 if (auto desc = proptable.getOwnProperty(one))
//                 {
//                     if (desc.IsAccessorDescriptor)
//                     {
//                         DefinePropertyOrThrow(one,
//                                               Property.Attribute.DontConfig);
//                     }
//                     else
//                     {
//                         DefinePropertyOrThrow(one,
//                                               Property.Attribute.DontConfig |
//                                               Property.Attribute.ReadOnly);
//                     }
//                 }
//             }
//         }
//         return true;
//     }

//     @disable
//     bool TestIntegrityLevel(in IntegrityLevel il)
//     {
//         if (_extensible)
//             return false;
//         foreach(ref one; OwnPropertyKeys)
//         {
//             if (auto currentDesc = proptable.getOwnProperty(one))
//             {
//                 if (currentDesc.configurable)
//                     return false;
//                 if (il == IntegrityLevel.frozen &&
//                     currentDesc.IsDataDescriptor)
//                 {
//                     if (currentDesc.writable)
//                         return false;
//                 }
//             }
//         }
//         return true;
//     }

//     @disable
//     bool InstanceofOperator(Dobject c, CallContext* cc)
//     {
//         assert(c !is null);
//         if (auto instOfHandler = c.value.GetMethod(Key.hasInstance, cc))
//         {
//             Value ret;
//             auto err = instOfHandler.Call(cc, c, ret, [this.value]);
//             if (err !is null)
//                 throw err.exception;
//             return ret.toBoolean;
//         }
//         if (auto df = cast(Dfunction)c)
//         {
//             return df.OrdinaryHasInstance(c, cc);
//         }
//         else
// //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// // use errmsgs.
//             throw new Exception("should be a function");
//     }

//     // Ecma-262-v7/7.3.21
//     @disable
//     Value[] EnumerableOwnNames()
//     {
//         import std.array : Appender;

//         Appender!(Value[]) names;
//         foreach(ref one; OwnPropertyKeys)
//         {
//             if (auto desc = proptable.getOwnProperty(one))
//             {
//                 if (desc.enumerable)
//                     names.put(Value(one));
//             }
//         }
//         return names.data;
//     }

    // Ecma-262-v7/7.3.22
    @disable
    void GetFunctionRealm(){}

    //
    @safe pure nothrow
    this(Dobject prototype, PropertyKey cn = Key.Object,
         PropTable pt = null)
    {
        if (pt is null)
            proptable = new PropTable;
        else
            proptable = pt;
        SetPrototypeOf(prototype);
        _classname = cn;
        value.put(this);
    }


private:
    PropertyKey _classname;
    Dobject _prototype;
    bool _extensible = true;

    // See_Also:
    // Ecma-272-v7:6.1.7.3 Invariants of the Essential Internal Methods
    debug @trusted @nogc pure nothrow
    void _checkCircularPrototypeChain() const
    {
        for (auto ite = cast(Dobject)_prototype; ite !is null;
             ite = ite._prototype)
            assert(this !is ite);
        if (_prototype !is null)
            _prototype._checkCircularPrototypeChain;
    }
}

//------------------------------------------------------------------------------
class DobjectConstructor : Dconstructor
{
    import dmdscript.primitive: PropertyKey;

    this(Dobject classPrototype, Dobject functionPrototype)
    {
        super(classPrototype, functionPrototype, Key.Object, 1);
        install(functionPrototype);

    }

    //
    override
    Derror Construct(CallContext* cc, out Value ret, Value[] arglist)
    {
        Dobject o;
        Value* v;

        // ECMA 15.2.2
        if(arglist.length == 0)
        {
            o = opCall;
        }
        else
        {
            v = &arglist[0];
            if(v.isPrimitive())
            {
                if(v.isUndefinedOrNull())
                {
                    o = opCall;
                }
                else
                    v.to(o, cc);
            }
            else
                v.to(o, cc);
        }

        ret.put(o);
        return null;
    }

    //
    override Derror Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        Dobject o;
        Derror result;

        // ECMA 15.2.1
        if(arglist.length == 0)
        {
            result = Construct(cc, ret, arglist);
        }
        else
        {
            auto v = arglist.ptr;
            if(v.isUndefinedOrNull)
                result = Construct(cc, ret, arglist);
            else
            {
                v.to(o, cc);
                ret.put(o);
                result = null;
            }
        }
        return result;
    }

    nothrow
    Dobject opCall(PropertyKey cn = Key.Object)
    {
        return new Dobject(classPrototype, cn);
    }

}

//==============================================================================
private:

//------------------------------------------------------------------------------
//
@DFD(2, DFD.Type.Static)
Derror assign(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(2, DFD.Type.Static)
Derror create(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(2, DFD.Type.Static)
Derror defineProperties(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(3, DFD.Type.Static)
Derror defineProperty(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey;
    import dmdscript.property : Property;

    Derror sta;
    Dobject target;
    PropertyKey key;

    if      (arglist.length < 2)
        goto failure;
    else if (!arglist[0].isObject)
    {
        string s;
        arglist[0].to(s, cc);
        sta = CannotConvertToObject2Error(cc,
            arglist[0].getTypeof, s);
        goto failure;
    }

    target = arglist[0].object;
    arglist[1].to(key, cc);

    if (arglist.length < 3)
    {
        auto p = new Property(Property.Attribute.None);
        if (!target.DefineOwnProperty(key, p))
        {
            sta = CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            goto failure;
        }
    }
    else
    {
        Dobject o;
        arglist[2].to(o, cc);
        auto prop = new Property(cc, o);
        if (!target.DefineOwnProperty(key, prop))
        {
            sta = CannotPutError(cc); // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            goto failure;
        }
    }

succeeded:
    assert (sta is null);
    assert (target !is null);
    ret.put(target);

    return null;

failure:
    ret.putVundefined;
    return sta;
}

//
@DFD(1, DFD.Type.Static)
Derror freeze(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(2, DFD.Type.Static)
Derror getOwnPropertyDescriptor(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey;
    Derror sta;
    Dobject target;

    if (arglist.length < 2)
        goto failure;

    arglist[0].to(target, cc);
    if (target !is null)
    {
        PropertyKey pk;
        arglist[1].to(pk, cc);
        if (auto prop = target.GetOwnProperty(pk))
        {
            Dobject o;
            o = prop.toObject(cc.realm);
            ret.put(o);
            return null;
        }
    }

failure:
    ret.putVundefined;
    return sta;
}

//
@DFD(1, DFD.Type.Static)
Derror getOwnPropertySymbol(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror getPrototypeOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    if (0 == arglist.length)
    {
        ret.putVundefined;
        return null;
    }

    Dobject o;
    arglist[0].to(o, cc);
    if (o is null)
    {
        ret.putVundefined;
        return null;
    }

    ret.put(o.GetPrototypeOf);
    return null;
}

//
@DFD(2, DFD.Type.Static, "is")
Derror _is(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror isExtensible(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror isFrozen(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror isSealed(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror keys(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(1, DFD.Type.Static)
Derror preventExtensions(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    if (0 == arglist.length)
    {
        ret.putVundefined;
        return null;
    }

    auto v = &arglist[0];
    if (!v.isObject)
    {
        ret.put(*v);
        return null;
    }

    auto o = v.object;
    if (!o.preventExtensions)
    {
        string s;
        v.to(s, cc);
        return PreventExtensionsFailureError(cc, s);
    }

    ret.put(o);
    return null;
}

//
@DFD(1, DFD.Type.Static)
Derror seal(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert(0);
}

//
@DFD(2, DFD.Type.Static)
Derror setPrototypeOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    Dobject target, proto;
    Derror sta;

    if (arglist.length < 1)
        goto failure;

    arglist[0].to(target, cc);
    if (1 < arglist.length)
        arglist[1].to(proto, cc);

    if (!target.SetPrototypeOf(proto))
    {
        sta = CannotPutError(cc);
        goto failure;
    }

    ret.put(target);
    return null;

failure:
    ret.putVundefined;
    return sta;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import std.format : format;

    string s;
    string str;

    s = othis.classname;
/+
    // Should we do [object] or [object Object]?
    if (s == Text.Object)
        string = Text.bobjectb;
    else
 +/
    str = format("[object %s]", s);
    ret.put(str);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror toLocaleString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value v;
    Derror err;

    if (othis.Get(Key.toString, v, cc).onError(err))
        return err;
    if(!v.isEmpty && !v.isPrimitive)   // if it's an Object
    {
        Dobject o;

        o = v.object;
        if (o.Call(cc, othis, ret, arglist).onError(err))
            return err;         // if exception was thrown
    }
    return err;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    ret.put(othis);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror toSource(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.property : Property;
    import dmdscript.primitive : PropertyKey;

    Derror err;
    string buf;
    int any;

    buf = "{";
    any = 0;
    foreach(PropertyKey key, Property* p; othis.proptable)
    {
        if (p.enumerable /*&& p.deleted /* not used?*/)
        {
            if(any)
                buf ~= ',';
            any = 1;
            buf ~= key.toString;
            buf ~= ':';
            Value v;
            if (p.get(v, othis, cc).onError(err))
                continue;
            if (!v.isEmpty)
            {
                string s;
                v.toSource(s, cc);
                buf ~= s;
            }
        }
    }
    buf ~= '}';
    ret.put(buf);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror hasOwnProperty(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey;
    import dmdscript.value: vundefined;

    // ECMA v3 15.2.4.5
    PropertyKey key;
    (arglist.length ? arglist[0] : vundefined).to(key, cc);
    ret.put(othis.proptable.getOwnProperty(key) !is null);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror isPrototypeOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    // ECMA v3 15.2.4.6
    bool result = false;
    Value v;
    Dobject o;

    if (0 < arglist.length)
        v = arglist[0];
    else
        v.putVundefined;

    if(!v.isPrimitive())
    {
        v.to(o, cc);
        for(;; )
        {
            o = o._prototype;
            if(o is null)
                break;
            if(o is othis)
            {
                result = true;
                break;
            }
        }
    }

    ret.put(result);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror propertyIsEnumerable(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey;
    import dmdscript.value: vundefined;
    // ECMA v3 15.2.4.7
    PropertyKey key;
    (arglist.length ? arglist[0] : vundefined).to(key, cc);
    if (auto p = othis.proptable.getOwnProperty(key))
        ret.put(p.enumerable);
    else
        ret.put(false);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0, DFD.Type.Getter, "__proto__")
Derror proto_Get(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

@DFD(0, DFD.Type.Setter, "__proto__")
Derror proto_Set(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

@DFD()
struct symbol_unscopables
{
    import dmdscript.primitive: PropertyKey;
    import dmdscript.property: SpecialSymbols;

static:
    alias name = SpecialSymbols.unscopables;

    Derror setter(
        DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
        ArgList arglist)
    {
        import dmdscript.property: Property;
        alias PA = Property.Attribute;

        if (0 == arglist.length)
            return null;

        Dobject arg;
        Derror err;
        if (arglist[0].to(arg, cc).onError(err))
            return err;

        foreach(PropertyKey key, Property* prop; arg.proptable)
        {
            prop.attribute = prop.attribute | PA.DontOverwrite;
            othis.DefineOwnProperty(key, prop);
        }
        return null;
    }
}
