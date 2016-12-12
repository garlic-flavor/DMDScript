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

import dmdscript.primitive : tstring, Key;
import dmdscript.value : Value, DError;
import dmdscript.callcontext : CallContext;
import dmdscript.dfunction : Dconstructor;
import dmdscript.dnative : DnativeFunction, DnativeFunctionDescriptor;
import dmdscript.dglobal : undefined;
import dmdscript.errmsgs;

//debug = LOG;

//==============================================================================
class Dobject
{
    import dmdscript.primitive : tstring, Text, StringKey;
    import dmdscript.property : PropertyKey, Property, PropTable;

    PropTable proptable;
    Value value;

    //
    mixin Initializer!DobjectConstructor _Initializer;

    //
    @safe pure nothrow
    this(Dobject prototype = getPrototype, tstring cn = Key.Object)
    {
        proptable = new PropTable;
        SetPrototypeOf(prototype);
        _classname = cn;
        value.put(this);
    }

    //
    // See_Also: Ecma-262-v7/6.1.7.2 - 6.1.7.3
    //

    //--------------------------------------------------------------------
    // non-virtual
    final
    {
        //
        @property @safe @nogc pure nothrow
        tstring classname() const
        {
            return _classname;
        }

        //
        @property @safe @nogc pure nothrow
        Dobject GetPrototypeOf()
        {
            return _prototype;
        }

        //
        @property @safe @nogc pure nothrow
        bool SetPrototypeOf(Dobject prototype)
        {
            if (!_extensible)
                return false;
            _prototype = prototype;
            if (prototype !is null)
            {
                proptable.previous = prototype.proptable;
                debug _checkCircularPrototypeChain;
            }
            return true;
        }

        //
        @property @safe @nogc pure nothrow
        bool IsExtensible() const
        {
            return _extensible;
        }

        //
        @safe @nogc pure nothrow
        bool preventExtensions()
        {
            _extensible = false;
            return true;
        }

        Value* Get(K)(in auto ref K name, ref CallContext cc)
            if (PropertyKey.IsKey!K)
        {
            static if      (is(K : PropertyKey))
            {
                if      (name.type == Value.Type.String)
                {
                    auto sk = name.toStringKey;
                    return GetImpl(sk, cc);
                }
                else if (name.type == Value.Type.Number)
                {
                    auto index = cast(uint)name.number;
                    return GetImpl(index, cc);
                }
                else
                {
                    auto v = cast(Value)name.value;
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// use errmsgs.
                    throw new Exception("not a valid key ", v.toString);
                }
            }
            else static if (is(K == Key))
            {
                auto sk = cast(StringKey)name;
                return GetImpl(sk, cc);
            }
            else static if (is(K : uint) || is(K : StringKey))
                return GetImpl(name, cc);
            else static if (is(K : tstring))
            {
                auto sk = StringKey(name);
                return GetImpl(sk, cc);
            }
            else static assert(0);
        }

        DError* Set(K, V)(in auto ref K name, auto ref V value,
                          in Property.Attribute attributes, ref CallContext cc)
            if (PropTable.IsKeyValue!(K, V))
        {
            // ECMA 8.6.2.2
            static if      (is(K : PropertyKey))
            {
                if      (name.type == Value.Type.String)
                {
                    auto sk = name.toStringKey;
                    static if (is(V : Value))
                        alias v = value;
                    else
                        auto v = Value(value);
                    return SetImpl(sk, v, attributes, cc);
                }
                else if (name.type == Value.Type.Number)
                {
                    auto index = cast(uint)name.number;
                    static if (is(V : Value))
                        alias v = value;
                    else
                        auto v = Value(value);
                    return SetImpl(index, v, attributes, cc);
                }
                else
                {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// use errmsgs
                    auto v = cast(Value)name.value;
                    throw new Exception("not a valid key ", v.toString);
                }
            }
            else static if (is(K == Key))
            {
                auto sk = cast(StringKey)name;
                static if (is(V : Value))
                    alias v = value;
                else
                    auto v = Value(value);
                return SetImpl(sk, v, attributes, cc);
            }
            else static if (is(K : uint) || is(K : StringKey))
            {
                static if (is(V : Value))
                    alias v = value;
                else
                    auto v = Value(value);
                return SetImpl(name, v, attributes, cc);
            }
            else static if (is(K : tstring))
            {
                auto sk = StringKey(name);
                static if (is(V : Value))
                    alias v = value;
                else
                    auto v = Value(value);
                return SetImpl(sk, v, attributes, cc);
            }
            else static assert(0);
        }
    }


    //--------------------------------------------------------------------
    // may virtual

    //
    @safe
    Property* GetOwnProperty(in StringKey PropertyName)
    {
        return proptable.getOwnProperty(PropertyName);
    }

    //
    bool HasProperty(in tstring name)
    {
        // ECMA 8.6.2.4
        auto key = PropertyKey(name);
        return proptable.getProperty(key) !is null;
    }


    //--------------------------------------------------------------------

    //
    Value* GetImpl(in ref StringKey PropertyName, ref CallContext cc)
    {
        auto key = PropertyKey(PropertyName);
        return proptable.get(key, cc, this);
    }

    //
    Value* GetImpl(in uint index, ref CallContext cc)
    {
        Value* v;

        auto key = PropertyKey(index);
        v = proptable.get(key, cc, this);
        //    if (!v)
        //	v = &vundefined;
        return v;
    }

    //--------------------------------------------------------------------

    //
    DError* SetImpl(in ref StringKey PropertyName, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        auto key = PropertyKey(PropertyName);
        return proptable.set(key, value, attributes, cc, this);
    }

    //
    DError* SetImpl(in uint index, ref Value value,
                    in Property.Attribute attributes, ref CallContext cc)
    {
        // ECMA 8.6.2.2
        auto key = PropertyKey(index);
        return proptable.set(key, value, attributes, cc, this);
    }

    //--------------------------------------------------------------------
    //
    /***********************************
     * Return:
     *	TRUE	not found or successful delete
     *	FALSE	property is marked with DontDelete attribute
     */
    bool Delete(in StringKey PropertyName)
    {
        // ECMA 8.6.2.5
        auto key = PropertyKey(PropertyName);
        return proptable.del(key);
    }

    //
    bool Delete(in uint index)
    {
        // ECMA 8.6.2.5
        auto key = PropertyKey(index);
        return proptable.del(key);
    }


    //--------------------------------------------------------------------
    //
    final
    bool DefineOwnProperty(K)(in auto ref K PropertyName,
                              in Property.Attribute attributes)
        if (PropertyKey.IsKey!K)
    {
        return proptable.config(PropertyName, attributes);
    }

    //
    final
    bool DefineOwnProperty(K, V)(in auto ref K PropertyName, auto ref V v,
                              in Property.Attribute attributes)
        if (PropTable.IsKeyValue!(K, V))
    {
        if (!_extensible)
            return false;
        return proptable.config(PropertyName, v, attributes);
    }

    //
    final @safe pure nothrow
    PropertyKey[] OwnPropertyKeys()
    {
        return proptable.keys;
    }

    DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                 Value[] arglist)
    {
        return SNoCallError(_classname);
    }

    DError* Construct(ref CallContext cc, out Value ret, Value[] arglist)
    {
        return SNoConstructError(_classname);
    }

    //--------------------------------------------------------------------

    DError* PutDefault(out Value value)
    {
        // Not ECMA, Microsoft extension
        return NoDefaultPutError;
    }

    DError* put_Value(out Value ret, Value[] arglist)
    {
        // Not ECMA, Microsoft extension
        return FunctionNotLvalueError;
    }

    int CanPut(in tstring PropertyName)
    {
        // ECMA 8.6.2.3
        auto key = PropertyKey(PropertyName);
        return proptable.canset(key);
    }

    int implementsDelete()
    {
        // ECMA 8.6.2 says every object implements [[Delete]],
        // but ECMA 11.4.1 says that some objects may not.
        // Assume the former is correct.
        return true;
    }

    final @trusted
    DError* DefaultValue(ref CallContext cc, out Value ret,
                         in Value.Type Hint = Value.Type.RefError)
    {
        import dmdscript.ddate : Ddate;

        Dobject o;
        Value* v;
        static enum tstring[2] table = [Key.toString, Key.valueOf];
        int i = 0;                      // initializer necessary for /W4

        // ECMA 8.6.2.6

        if(Hint == Value.Type.String ||
           (Hint == Value.Type.RefError && (cast(Ddate)this) !is null))
        {
            i = 0;
        }
        else if(Hint == Value.Type.Number ||
                Hint == Value.Type.RefError)
        {
            i = 1;
        }
        else
            assert(0);

        for(int j = 0; j < 2; j++)
        {
            auto htab = PropertyKey(table[i]);

            v = Get(htab, cc);

            if(v && !v.isPrimitive())   // if it's an Object
            {
                DError* a;
                //CallContext* cc2;

                o = v.object;
                //cc2 = &Program.getProgram().callcontext;
                a = o.Call(cc, this, ret, null);
                if(a)                   // if exception was thrown
                    return a;
                if(ret.isPrimitive)
                    return null;
            }
            i ^= 1;
        }
        return NoDefaultValueError;
        //ErrInfo errinfo;
        //return RuntimeError(&errinfo, DTEXT("no Default Value for object"));
    }

    DError* HasInstance(ref CallContext cc, out Value ret, ref Value v)
    {   // ECMA v3 8.6.2
        return SNoInstanceError(_classname);
    }

    tstring getTypeof()
    {   // ECMA 11.4.3
        return Text.object;
    }

    final @trusted
    DError* putIterator(out Value v)
    {
        import dmdscript.iterator : Iterator;

        auto i = new Iterator;

        i.ctor(this);
        v.put(i);
        return null;
    }

    //
    @disable
    DError* CreateDataProperty(K, V)(in auto ref K name, auto ref V value)
        if (PropTable.IsKeyValue!(K, V))
    {
        if (DefineOwnProperty(name, value, Property.Attribute.None))
            return null;
        else
            return CreateDataPropertyError;
    }

    //
    @disable
    DError* CreateMethodProperty(in StringKey PropertyName, ref Value value)
    {
        if (DefineOwnProperty(PropertyName, value, Property.Attribute.DontEnum))
            return null;
        else
            return CreateMethodPropertyError;
    }

    @disable
    void CreateDataPropertyOrThrow(in StringKey PropertyName, ref Value value)
    {
        if (!DefineOwnProperty(PropertyName, value, Property.Attribute.None))
            throw CreateDataPropertyError.toThrow;
    }

    @disable
    final
    void DefinePropertyOrThrow(K, V)(in auto ref K name, auto ref V value,
                               in Property.Attribute attr)
        if (PropTable.IsKeyValue(K, V))
    {
        if (!DefineOwnProperty(name, value, attr))
            throw CreateMethodPropertyError.toThrow;
    }

    @disable
    void DefinePropertyOrThrow(K)(in auto ref K PropertyName,
                                  in Property.Attribute attr)
        if (PropertyKey.IsKey!K)
    {
        if (!DefineOwnProperty(PropertyName, attr))
            throw CreateMethodPropertyError.toThrow;
    }

    @disable
    void DeletePropertyOrThrow(in StringKey PropertyName)
    {
        if (!Delete(PropertyName))
            throw CantDeleteError.toThrow(PropertyName);
    }


    @disable
    bool HasOwnProperty(in StringKey PropertyName)
    {
        return GetOwnProperty(PropertyName) !is null;
    }


    enum IntegrityLevel
    {
        zero, sealed, frozen,
    }

    @disable
    bool SetIntegrityLevel(in IntegrityLevel il)
    {
        if (!preventExtensions)
            return false;
        auto keys = OwnPropertyKeys;
        if      (il == IntegrityLevel.sealed)
        {
            foreach(ref one; keys)
                DefinePropertyOrThrow(one, Property.Attribute.DontConfig);
        }
        else if (il == IntegrityLevel.frozen)
        {
            foreach(ref one; keys)
            {
                if (auto desc = proptable.getOwnProperty(one))
                {
                    if (desc.IsAccessorDescriptor)
                    {
                        DefinePropertyOrThrow(one,
                                              Property.Attribute.DontConfig);
                    }
                    else
                    {
                        DefinePropertyOrThrow(one,
                                              Property.Attribute.DontConfig |
                                              Property.Attribute.ReadOnly);
                    }
                }
            }
        }
        return true;
    }

    @disable
    bool TestIntegrityLevel(in IntegrityLevel il)
    {
        if (_extensible)
            return false;
        foreach(ref one; OwnPropertyKeys)
        {
            if (auto currentDesc = proptable.getOwnProperty(one))
            {
                if (currentDesc.configurable)
                    return false;
                if (il == IntegrityLevel.frozen &&
                    currentDesc.IsDataDescriptor)
                {
                    if (currentDesc.writable)
                        return false;
                }
            }
        }
        return true;
    }

    @disable
    bool InstanceofOperator(Dobject c, ref CallContext cc)
    {
        assert(c !is null);
        if (auto instOfHandler = c.value.GetMethod(Key.hasInstance, cc))
        {
            Value ret;
            auto err = instOfHandler.Call(cc, c, ret, [this.value]);
            if (err !is null)
                throw err.toScriptException;
            return ret.toBoolean;
        }
        if (auto df = cast(Dfunction)c)
        {
            return df.OrdinaryHasInstance(c, cc);
        }
        else
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// use errmsgs.
            throw new Exception("should be a function");
    }

    // Ecma-262-v7/7.3.21
    @disable
    Value[] EnumerableOwnNames()
    {
        import std.array : Appender;

        Appender!(Value[]) names;
        foreach(ref one; OwnPropertyKeys)
        {
            if (one.type == Value.Type.String)
            {
                if (auto desc = proptable.getOwnProperty(one))
                {
                    if (desc.enumerable)
                        names.put(one);
                }
            }
        }
        return names.data;
    }

    // Ecma-262-v7/7.3.22
    @disable
    void GetFunctionRealm(){}

private:

    tstring _classname;
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

//==============================================================================
package:

//------------------------------------------------------------------------------
///
mixin template Initializer(Constructor, string M = __MODULE__)
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dobject : Dobject;

public static:

    ///
    @safe @nogc nothrow
    Dfunction getConstructor()
    {
        assert (_constructor !is null);
        return _constructor;
    }

    ///
    @safe @nogc nothrow
    Dobject getPrototype()
    {
        assert (_prototype !is null);
        return _prototype;
    }

    ///
    void initPrototype()
    {
        assert (_prototype is null);
        static if (is (typeof(this) == Dobject))
            _prototype = new Dobject(null);
        else
            _prototype = new Dobject;
    }

    ///
    void initFuncs()
    {
        import dmdscript.property : Property;
        import dmdscript.dnative : DnativeFunctionDescriptor;

        assert (_prototype !is null);
        assert (_constructor is null);

        _constructor = new Constructor;
        _prototype.DefineOwnProperty(Key.constructor, _constructor,
                                     Property.Attribute.DontEnum);
        _constructor.DefineOwnProperty(Key.prototype, _prototype,
                                       Property.Attribute.DontEnum |
                                       Property.Attribute.DontDelete |
                                       Property.Attribute.ReadOnly);

        DnativeFunctionDescriptor.install!(mixin(M))(_prototype);
    }

private static:
    Dfunction _constructor;
    Dobject _prototype;
}


/*********************************************
 * Initialize the built-in's.
 */
void dobject_init()
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.dboolean : Dboolean;
    import dmdscript.dstring : Dstring;
    import dmdscript.dnumber : Dnumber;
    import dmdscript.darray : Darray;
    import dmdscript.dmath : Dmath;
    import dmdscript.ddate : Ddate;
    import dmdscript.dregexp : Dregexp;
    import dmdscript.derror : Derror;
    import dmdscript.protoerror : syntaxerror, evalerror, referenceerror,
        rangeerror, typeerror, urierror;

    if(Dobject._Initializer._prototype !is null)
        return;                 // already initialized for this thread

    void init(Types...)()
    {
        Dobject.initPrototype;
        Dfunction.initPrototype;

        foreach(one; Types)
            one.initPrototype;

        Dobject.initFuncs;
        Dfunction.initFuncs;

        foreach(one; Types)
            one.initFuncs;
    }

    init!(
        Dboolean,
        Dstring,
        Dnumber,
        Darray,
        Ddate,
        Dregexp,
        Derror,
        );

    Dmath.initialize();

    syntaxerror.init;
    evalerror.init;
    referenceerror.init;
    rangeerror.init;
    typeerror.init;
    urierror.init;
}

//==============================================================================
private:

//------------------------------------------------------------------------------
class DobjectConstructor : Dconstructor
{
    this()
    {
        super(1, Dfunction.getPrototype);
    }

    //
    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        Dobject o;
        Value* v;

        // ECMA 15.2.2
        if(arglist.length == 0)
         {
            o = new Dobject(Dobject.getPrototype());
        }
        else
        {
            v = &arglist[0];
            if(v.isPrimitive())
            {
                if(v.isUndefinedOrNull())
                {
                    o = new Dobject(Dobject.getPrototype());
                }
                else
                    o = v.toObject();
            }
            else
                o = v.toObject();
        }

        ret.put(o);
        return null;
    }

    //
    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        Dobject o;
        DError* result;

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
                o = v.toObject;
                ret.put(o);
                result = null;
            }
        }
        return result;
    }
}

//------------------------------------------------------------------------------
@DnativeFunctionDescriptor(Key.toString, 0)
DError* Dobject_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.format : format;

    tstring s;
    tstring str;

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
@DnativeFunctionDescriptor(Key.toLocaleString, 0)
DError* Dobject_prototype_toLocaleString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.3
    //	"This function returns the result of calling toString()."

    Value* v;

    v = othis.Get(Key.toString, cc);
    if(v && !v.isPrimitive())   // if it's an Object
    {
        DError* a;
        Dobject o;

        o = v.object;
        a = o.Call(cc, othis, ret, arglist);
        if(a)                   // if exception was thrown
            return a;
    }
    return null;
}

//------------------------------------------------------------------------------
@DnativeFunctionDescriptor(Key.valueOf, 0)
DError* Dobject_prototype_valueOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(othis);
    return null;
}

//------------------------------------------------------------------------------
@DnativeFunctionDescriptor(Key.toSource, 0)
DError* Dobject_prototype_toSource(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : Property, PropertyKey;

    tstring buf;
    int any;

    buf = "{";
    any = 0;
    foreach(PropertyKey key, Property p; othis.proptable)
    {
        if (p.enumerable /*&& p.deleted /* not used?*/)
        {
            if(any)
                buf ~= ',';
            any = 1;
            buf ~= key.toString();
            buf ~= ':';
            buf ~= p.get(cc, othis).toSource(cc);
        }
    }
    buf ~= '}';
    ret.put(buf);
    return null;
}

//------------------------------------------------------------------------------
@DnativeFunctionDescriptor(Key.hasOwnProperty, 1)
DError* Dobject_prototype_hasOwnProperty(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : PropertyKey;

    // ECMA v3 15.2.4.5
    auto key = PropertyKey(arglist.length ? arglist[0] : undefined);
    ret.put(othis.proptable.getOwnProperty(key) !is null);
    return null;
}

//------------------------------------------------------------------------------
@DnativeFunctionDescriptor(Key.isPrototypeOf, 0)
DError* Dobject_prototype_isPrototypeOf(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.2.4.6
    bool result = false;
    Value* v;
    Dobject o;

    v = arglist.length ? &arglist[0] : &undefined;
    if(!v.isPrimitive())
    {
        o = v.toObject();
        for(;; )
        {
            o = o._prototype;
            if(!o)
                break;
            if(o == othis)
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
@DnativeFunctionDescriptor(Key.propertyIsEnumerable, 0)
DError* Dobject_prototype_propertyIsEnumerable(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.property : PropertyKey;
    // ECMA v3 15.2.4.7
    auto key = PropertyKey(arglist.length ? arglist[0] : undefined);
    if (auto p = othis.proptable.getOwnProperty(key))
        ret.put(p.enumerable);
    else
        ret.put(false);
    return null;
}

