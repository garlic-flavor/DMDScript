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


module dmdscript.darray;

// Nonstandard treatment of Infinity as array length in slice/splice functions,
// supported by majority of browsers.
// also treats negative starting index in splice wrapping it around just like
// in slice.
version =  SliceSpliceExtension;

import dmdscript.dobject: Dobject;
import dmdscript.value: Value;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, ArgList,
    DFD = DnativeFunctionDescriptor;
import dmdscript.callcontext: CallContext;
import dmdscript.drealm: Drealm;
import dmdscript.derror: Derror, onError;

//==============================================================================
///
class Darray : Dobject
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    alias PA = Property.Attribute;

    Value length;               // length property
    size_t ulength;

    override
    Derror Set(in PropertyKey key, ref Value v,
                in Property.Attribute attributes, CallContext* cc)
    {
        import dmdscript.errmsgs: LengthIntError;

        size_t index;
        if (key.isArrayIndex(index))
        {
            if(index >= ulength)
            {
                ulength = index + 1;
                length.number = ulength;
            }

            auto pk = PropertyKey(index);
            auto a = cast(PA)(attributes | (IsExtensible ? 0 : PA.DontExtend));
            proptable.set(pk, v, this, a, cc);
            return null;
        }
        else
        {
            uint i;
            uint c;
            double num;
            Derror result;

            // ECMA 15.4.5.1
            auto a = cast(PA)(attributes | (IsExtensible ? 0 : PA.DontExtend));
            result = proptable.set(key, v, this, a, cc);
            if(!result)
            {
                if(key == Key.length)
                {
                    result = v.to(i, cc);
                    if (result !is null)
                        return result;

                    result = v.toInteger(num, cc);
                    if (result !is null)
                        return result;
                    if(i != num)
                    {
                        return LengthIntError(cc);
                    }
                    if(i < ulength)
                    {
                        // delete all properties with keys >= i
                        size_t[] todelete;

                        foreach(PropertyKey key, Property* p; proptable)
                        {
                            size_t j;

                            if(key.isArrayIndex(j) && j >= i)
                                todelete ~= j;
                        }
                        PropertyKey k;
                        foreach(size_t j; todelete)
                        {
                            k.put(j);
                            proptable.del(k);
                        }
                    }
                    ulength = i;
                    length.number = i;
                    a |= PA.DontEnum;
                    proptable.set(key, v, this, a, cc);
                }

                // if (name is an array index i)

                i = 0;
                for(size_t j = 0; j < key.length; j++)
                {
                    ulong k;

                    c = key[j];
                    if(c == '0' && i == 0 && key.length > 1)
                        goto Lret;
                    if(c >= '0' && c <= '9')
                    {
                        k = i * cast(ulong)10 + c - '0';
                        i = cast(uint)k;
                        if(i != k)
                            goto Lret;              // overflow
                    }
                    else
                        goto Lret;
                }
                if(i >= ulength)
                {
                    if(i == 0xFFFFFFFF)
                        goto Lret;
                    ulength = i + 1;
                    length.number = ulength;
                }
            }
        Lret:
            return null;
        }
    }

    override Derror Get(in PropertyKey PropertyName, out Value ret,
                         CallContext* cc)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(PropertyName == Key.length)
        {
            length.number = ulength;
            ret = length;
            return null;
        }
        else
        {
            return Dobject.Get(PropertyName, ret, cc);
        }
    }

    override bool Delete(in PropertyKey PropertyName)
    {
        // ECMA 8.6.2.5
        //writef("Darray.Delete('%ls')\n", d_string_ptr(PropertyName));
        if(PropertyName == Key.length)
            return 0;           // can't delete 'length' property
        else
        {
            return proptable.del(PropertyName);
        }
    }

private:
    nothrow
    this(Dobject prototype)
    {
        super(prototype, Key.Array);
        length.put(0);
        ulength = 0;
    }


public static:

    // @disable
    // Darray CreateArrayFromList(Value[] list)
    // {
    //     auto array = new Darray;
    //     foreach(uint i, ref one; list)
    //     {
    //         array.CreateDataProperty(PropertyKey(i), one);
    //     }
    //     return array;
    // }

//     @disable
//     Value[] CreateListFromArrayLike(
//         Dobject obj, CallContext cc,
//         Value.Type elementTypes = cast(Value.Type)(
//             Value.Type.Undefined | Value.Type.Null | Value.Type.Boolean |
//             Value.Type.String | Value.Type.Number | Value.Type.Object))
//     {
//         assert(obj);
//         auto len = cast(size_t)obj.Get(Key.length, cc).ToLength(cc);
//         auto list = new Value[len];
//         for (uint i = 0; i < len; ++i)
//         {
//             if (auto v = obj.Get(PropertyKey(i), cc))
//             {
//                 if (0 == (v.type & elementTypes))
// //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//                     // use errmsgs.
//                     throw new Exception("element type mismatch.");
//                 list[i] = *v;
//             }
//         }
//         return list;
//     }

    // mixin Initializer!DarrayConstructor;
}

//------------------------------------------------------------------------------
class DarrayConstructor : Dconstructor
{
    this(Dobject superPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive: Key;
        super(new Dobject(superPrototype), functionPrototype,
              Key.Array, 1);

        install(functionPrototype);
    }

    override
    Derror Construct(CallContext* cc, out Value ret, Value[] arglist)
    {
        import dmdscript.primitive : PropertyKey;
        import dmdscript.errmsgs: ArrayLenOutOfBoundsError;
        import dmdscript.property: Property;

        // ECMA 15.4.2
        Darray a;

        a = opCall;
        if(arglist.length == 0)
        {
            a.ulength = 0;
            a.length.number = 0;
        }
        else if(arglist.length == 1)
        {
            Value* v = &arglist[0];

            if(v.isNumber())
            {
                uint len;

                if (auto err = v.to(len, cc))
                    return err;
                if(cast(double)len != v.number)
                {
                    ret.putVundefined;
                    return ArrayLenOutOfBoundsError(cc, v.number);
                }
                else
                {
                    a.ulength = len;
                    a.length.number = len;
                    /+
                       if (len > 16)
                       {
                        //writef("setting %p dimension to %d\n", &a.proptable, len);
                        if (len > 10000)
                            len = 10000;		// cap so we don't run out of memory
                        a.proptable.roots.setDim(len);
                        a.proptable.roots.zero();
                       }
                     +/
                }
            }
            else
            {
                a.ulength = 1;
                a.length.number = 1;
                a.Set(PropertyKey(0), *v, Property.Attribute.None, cc);
            }
        }
        else
        {
            //if (arglist.length > 10) writef("Array constructor: arglist.length = %d\n", arglist.length);
            /+
               if (arglist.length > 16)
               {
                a.proptable.roots.setDim(arglist.length);
                a.proptable.roots.zero();
               }
             +/
            a.ulength = cast(uint)arglist.length;
            a.length.number = arglist.length;
            for(uint k = 0; k < arglist.length; k++)
            {
                a.Set(PropertyKey(k), arglist[k], Property.Attribute.None, cc);
            }
        }
        ret = a.value;
        //writef("Darray_constructor.Construct(): length = %g\n", a.length.number);
        return null;
    }


    nothrow
    Darray opCall()
    {
        return new Darray(classPrototype);
    }

}


//==============================================================================
private:

//
@DFD(1, DFD.Type.Static)
Derror from(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror isArray(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror of(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}




//------------------------------------------------------------------------------
@DFD(0)
Derror toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    //writef("Darray_prototype_toString()\n");
    array_join(cc, othis, ret, ArgList(null));
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror toLocaleString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    // import dmdscript.program: Program;
    import dmdscript.locale: Locale;
    import dmdscript.errmsgs: TlsNotTransferrableError;

    // ECMA v3 15.4.4.3
    string separator;
    string r;
    uint len;
    uint k;
    Value v;
    Derror err;

    if ((cast(Darray)othis) is null)
    {
        ret.putVundefined();
        return TlsNotTransferrableError(cc);
    }

    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    len = 0;
    if (!v.isEmpty)
    {
        if (v.to(len, cc).onError(err))
            return err;
    }

    // Program prog = cc.program;
    // if(0 == prog.slist.length)
    // {
    //     // Determine what list separator is only once per thread
    //     //prog.slist = list_separator(prog.lcid);
    //     prog.slist = ",";
    // }
    // separator = prog.slist;
    separator = Locale.list_separator;

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        if (othis.Get(PropertyKey(k), v, cc).onError(err))
            return err;
        if(!v.isEmpty && !v.isUndefinedOrNull)
        {
            Dobject ot;

            if (v.to(ot, cc).onError(err))
                return err;
            if (ot.Get(Key.toLocaleString, v, cc).onError(err))
                return err;
            if(!v.isPrimitive())   // if it's an Object
            {
                Derror a;
                Dobject o;
                Value rt;
                string s;

                o = v.object;
                rt.putVundefined();
                a = o.Call(cc, ot, rt, null);
                if(a)                   // if exception was thrown
                    return a;
                a = rt.to(s, cc);
                if (a)
                    return a;
                r ~= s;
            }
        }
    }

    ret.put(r);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror concat(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    alias PA = Property.Attribute;
    // ECMA v3 15.4.4.4
    Darray A;
    Darray E;
    Value v;
    uint k;
    uint n;
    uint a;

    A = cc.realm.dArray();
    n = 0;
    v = othis.value;
    for(a = 0;; a++)
    {
        if(!v.isPrimitive && (E = (cast(Darray)v.object)) !is null)
        {
            size_t len;

            len = E.ulength;
            for(k = 0; k != len; k++)
            {
                if (auto err = E.Get(PropertyKey(k), v, cc))
                    return err;
                if(!v.isEmpty)
                    A.Set(PropertyKey(n), v, PA.None, cc);
                n++;
            }
        }
        else
        {
            A.Set(PropertyKey(n), v, PA.None, cc);
            n++;
        }
        if(a == arglist.length)
            break;
        v = arglist[a];
    }

    v.put(n);
    A.Set(Key.length, v, PA.DontEnum, cc);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror join(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    array_join(cc, othis, ret, arglist);
    return null;
}

//
Derror array_join(CallContext* cc, Dobject othis, out Value ret,
                  ArgList arglist)
{
    import dmdscript.primitive : Text, PropertyKey, Key;

    // ECMA 15.4.4.3
    string separator;
    string r;
    uint len;
    uint k;
    Value v;
    Derror err;

    //writef("array_join(othis = %p)\n", othis);
    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    len = 0;
    if (!v.isEmpty)
    {
        if (v.to(len, cc).onError(err))
            return err;
    }
    if(arglist.length == 0 || arglist[0].isUndefined())
        separator = Text.comma;
    else
        arglist[0].to(separator, cc);

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        if (othis.Get(PropertyKey(k), v, cc).onError(err))
            return err;
        if(!v.isEmpty && !v.isUndefinedOrNull)
        {
            string s;
            if (v.to(s, cc).onError(err))
                return err;
            r ~= s;
        }
    }

    ret.put(r);
    return err;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror toSource(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey, Key;

    string separator;
    string r;
    uint len;
    uint k;
    Value v;
    Derror err;

    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    len = 0;
    if (!v.isEmpty)
    {
        if (v.to(len, cc).onError(err))
            return err;
    }
    separator = ",";

    r = "[".idup;
    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        if (othis.Get(PropertyKey(k), v, cc).onError(err))
            return err;
        if(!v.isEmpty && !v.isUndefinedOrNull)
        {
            string s;
            if (v.toSource(s, cc).onError(err))
                return err;
            r ~= s;
        }
    }
    r ~= "]";

    ret.put(r);
    return null;
}


//------------------------------------------------------------------------------
@DFD(0)
Derror pop(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    // ECMA v3 15.4.4.6
    Value v;
    Value val;
    uint u;
    Derror err;

    // If othis is a Darray, then we can optimize this significantly
    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(u, cc).onError(err))
        return err;
    if(u == 0)
    {
        val.put(0.0);
        othis.Set(Key.length, val, Property.Attribute.DontEnum, cc);
        ret.putVundefined();
    }
    else
    {
        if (othis.Get(PropertyKey(u - 1), v, cc).onError(err))
            return err;
        if(v.isEmpty)
            v.putVundefined;
        ret = v;
        val.put(u - 1);
        othis.Delete(PropertyKey(u - 1));
        othis.Set(Key.length, val, Property.Attribute.DontEnum, cc);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror push(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.7
    Value v;
    Value val;
    uint u;
    uint a;
    Derror err;

    // If othis is a Darray, then we can optimize this significantly
    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(u, cc).onError(err))
        return err;
    for(a = 0; a < arglist.length; a++)
    {
        val.put(arglist[a]);
        othis.Set(PropertyKey(u + a), val, Property.Attribute.None, cc);
    }
    val.put(u + a);
    othis.Set(Key.length, val,  Property.Attribute.DontEnum, cc);
    ret.put(u + a);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror reverse(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;

    // ECMA 15.4.4.4
    uint a;
    uint b;
    Value va;
    Value vb;
    Value v;
    uint pivot;
    uint len;
    Value tmp;
    Derror err;

    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    len = 0;
    if (!v.isEmpty)
    {
        if (v.to(len, cc).onError(err))
            return err;
    }
    pivot = len / 2;
    for(a = 0; a != pivot; a++)
    {
        b = len - a - 1;
        //writef("a = %d, b = %d\n", a, b);
        if (othis.Get(PropertyKey(a), va, cc).onError(err))
            return err;
        if(!va.isEmpty)
            tmp = va;
        if (othis.Get(PropertyKey(b), vb, cc).onError(err))
            return err;
        if(!vb.isEmpty)
            othis.Set(PropertyKey(a), vb, Property.Attribute.None, cc);
        else
            othis.Delete(PropertyKey(a));

        if(!va.isEmpty)
            othis.Set(PropertyKey(b), tmp, Property.Attribute.None, cc);
        else
            othis.Delete(PropertyKey(b));
    }
    ret = othis.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror shift(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    import dmdscript.value: vundefined;

    // ECMA v3 15.4.4.9
    Value v;
    Value result;
    uint len;
    uint k;
    Derror err;

    // If othis is a Darray, then we can optimize this significantly
    //writef("shift(othis = %p)\n", othis);
    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(len, cc).onError(err))
        return err;

    if(len)
    {
        if (othis.Get(PropertyKey(0u), result, cc).onError(err))
            return err;
        if (result.isEmpty)
            ret.putVundefined;
        else
            ret = result;
        for(k = 1; k != len; k++)
        {
            if (othis.Get(PropertyKey(k), v, cc).onError(err))
                return err;
            if(!v.isEmpty)
            {
                othis.Set(PropertyKey(k - 1), v, Property.Attribute.None, cc);
            }
            else
            {
                othis.Delete(PropertyKey(k - 1));
            }
        }
        othis.Delete(PropertyKey(len - 1));
        len--;
    }
    else
        ret.putVundefined;

    v.put(len);
    othis.Set(Key.length, v, Property.Attribute.DontEnum, cc);
    return null;
}


//------------------------------------------------------------------------------
@DFD(2)
Derror slice(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.value: vundefined;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.10
    uint len;
    uint n;
    uint k;
    uint r8;

    Value v;
    Darray A;
    Derror err;

    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(len, cc).onError(err))
        return err;

version(SliceSpliceExtension){
    double start;
    double end;
    switch(arglist.length)
    {
    case 0:
        vundefined.to(start, cc);
        end = len;
        break;

    case 1:
        arglist[0].to(start, cc);
        end = len;
        break;

    default:
        arglist[0].to(start, cc);
        if(arglist[1].isUndefined())
        {
            end = len;
        }
        else
        {
            arglist[1].to(end, cc);
        }
        break;
    }
    if(start < 0)
    {
        k = cast(uint)(len + start);
        if(cast(int)k < 0)
            k = 0;
    }
    else if(start == double.infinity)
        k = len;
    else if(start == -double.infinity)
        k = 0;
    else
    {
        k = cast(uint)start;
        if(len < k)
            k = len;
    }

    if(end < 0)
    {
        r8 = cast(uint)(len + end);
        if(cast(int)r8 < 0)
            r8 = 0;
    }
    else if(end == double.infinity)
            r8 = len;
    else if(end == -double.infinity)
            r8 = 0;
    else
    {
        r8 = cast(uint)end;
        if(len < end)
            r8 = len;
    }
}
else
{//Canonical ECMA all kinds of infinity maped to 0
    int start;
    int end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toInt32();
        end = len;
        break;

    case 1:
        start = arglist[0].toInt32();
        end = len;
        break;

    default:
        start = arglist[0].toInt32();
        if(arglist[1].isUndefined())
        {
            end = len;
        }
        else
        {
            end = arglist[1].toInt32();
        }
        break;
    }
    if(start < 0)
    {
        k = cast(uint)(len + start);
        if(cast(int)k < 0)
            k = 0;
    }
    else
    {
        k = cast(uint)start;
        if(len < k)
            k = len;
    }

    if(end < 0)
    {
        r8 = cast(uint)(len + end);
        if(cast(int)r8 < 0)
            r8 = 0;
    }
    else
    {
        r8 = cast(uint)end;
        if(len < end)
            r8 = len;
    }
}
    A = cc.realm.dArray();
    for(n = 0; k < r8; k++)
    {
        if (othis.Get(PropertyKey(k), v, cc).onError(err))
            return err;
        if(!v.isEmpty)
        {
            A.Set(PropertyKey(n), v, Property.Attribute.None, cc);
        }
        n++;
    }

    v.put(n);
    A.Set(Key.length, v, Property.Attribute.DontEnum, cc);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
static Dobject comparefn;
static CallContext* compareCC;

extern (C) int compare_value(scope const void* x, scope const void* y)
{
    import std.string : stdcmp = cmp;

    Value* vx = cast(Value*)x;
    Value* vy = cast(Value*)y;
    string sx;
    string sy;
    int cmp;

    //writef("compare_value()\n");
    if(vx.isUndefined)
    {
        cmp = (vy.isUndefined) ? 0 : 1;
    }
    else if(vy.isUndefined)
        cmp = -1;
    else
    {
        if(comparefn)
        {
            Value[2] arglist;
            Value ret;
            Value* v;
            double n;

            arglist[0] = *vx;
            arglist[1] = *vy;
            ret.putVundefined();
            comparefn.Call(compareCC, comparefn, ret, arglist);
            ret.to(n, compareCC);
            if(n < 0)
                cmp = -1;
            else if(n > 0)
                cmp = 1;
            else
                cmp = 0;
        }
        else
        {
            vx.to(sx, compareCC);
            vy.to(sy, compareCC);
            cmp = stdcmp(sx, sy);
            if(cmp < 0)
                cmp = -1;
            else if(cmp > 0)
                cmp = 1;
        }
    }
    return cmp;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror sort(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import core.sys.posix.stdlib : qsort;
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.11
    Value v;
    size_t len;
    size_t u;
    Derror err;

    //writef("Array.prototype.sort()\n");
    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    len = 0;
    if (!v.isEmpty)
    {
        if (v.to(len, cc).onError(err))
            return err;
    }

    // This is not optimal, as isArrayIndex is done at least twice
    // for every array member. Additionally, the qsort() by index
    // can be avoided if we can deduce it is not a sparse array.

    Property* p;
    Value[] pvalues;
    size_t[] pindices;
    size_t parraydim;
    size_t nprops;

    // First, size & alloc our temp array
    if(len < 100)
    {   // Probably not too sparse an array
        parraydim = len;
    }
    else
    {
        parraydim = 0;
        foreach(Property* p; othis.proptable)
        {
            if(p.isNoneAttribute)       // don't count special properties
                parraydim++;
        }
        if(parraydim > len)             // could theoretically happen
            parraydim = len;
    }

    Value[] p1 = null;
    Value* v1;
    version(Win32)      // eh and alloca() not working under linux
    {
        import core.sys.posix.stdlib : alloca;
        if(parraydim < 128)
            v1 = cast(Value*)alloca(parraydim * Value.sizeof);
    }
    if(v1)
        pvalues = v1[0 .. parraydim];
    else
    {
        p1 = new Value[parraydim];
        pvalues = p1;
    }

    size_t[] p2 = null;
    size_t* p3;
    version(Win32)
    {
        if(parraydim < 128)
            p3 = cast(uint*)alloca(parraydim * uint.sizeof);
    }
    if(p3)
        pindices = p3[0 .. parraydim];
    else
    {
        p2 = new size_t[parraydim];
        pindices = p2;
    }

    // Now fill it with all the Property's that are array indices
    nprops = 0;
    foreach(ref PropertyKey key, Property* p; othis.proptable)
    {
        size_t index;

        if(p.isNoneAttribute && key.isArrayIndex(index))
        {
            pindices[nprops] = index;
            Value v;
            if (p.get(v, othis, cc).onError(err))
            {
                ret.putVundefined;
                return err;
            }
            if (!v.isEmpty)
                pvalues[nprops] = v;
            nprops++;
        }
    }

    synchronized
    {
        comparefn = null;
        compareCC = cc;
        if(arglist.length)
        {
            if(!arglist[0].isPrimitive())
                comparefn = arglist[0].object;
        }

        // Sort pvalues[]
        qsort(pvalues.ptr, nprops, Value.sizeof, &compare_value);

        comparefn = null;
        compareCC = null;
    }

    // Stuff the sorted value's back into the array
    for(u = 0; u < nprops; u++)
    {
        size_t index;

        othis.Set(PropertyKey(u), pvalues[u], Property.Attribute.None, cc);
        index = pindices[u];
        if(index >= nprops)
        {
            othis.Delete(PropertyKey(index));
        }
    }

    p1.destroy(); p1 = null;
    p2.destroy(); p2 = null;

    ret.put(othis);
    return null;
}

//------------------------------------------------------------------------------
@DFD(2)
Derror splice(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.value: vundefined;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.12
    uint len;
    uint k;

    Value v;
    Darray A;
    uint a;
    uint delcnt;
    uint inscnt;
    uint startidx;
    Derror err;

    if (othis.Get(Key.length, v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(len, cc).onError(err))
        return err;

version(SliceSpliceExtension){
    double start;
    double deleteCount;

    switch(arglist.length)
    {
    case 0:
        vundefined.to(start, cc);
        deleteCount = 0;
        break;

    case 1:
        arglist[0].to(start, cc);
        vundefined.to(deleteCount, cc);
        break;

    default:
        arglist[0].to(start, cc);
        arglist[1].to(deleteCount, cc);
        //checked later
        break;
    }
    if(start == double.infinity)
        startidx = len;
    else if(start == -double.infinity)
        startidx = 0;
    else{
        if(start < 0)
        {
            startidx = cast(uint)(len + start);
            if(cast(int)startidx < 0)
                startidx = 0;
        }
        else
            startidx = cast(uint)start;
    }
    startidx = startidx > len ? len : startidx;
    if(deleteCount == double.infinity)
        delcnt = len;
    else if(deleteCount == -double.infinity)
        delcnt = 0;
    else
        delcnt = (cast(uint)deleteCount > 0) ? cast(uint) deleteCount : 0;
    if(delcnt > len - startidx)
        delcnt = len - startidx;
}
else
{
    long start;
    int deleteCount;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toInt32();
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toInt32();
        deleteCount = vundefined.toInt32();
        break;

    default:
        start = arglist[0].toInt32();
        deleteCount = arglist[1].toInt32();
        //checked later
        break;
    }
    startidx = cast(uint)start;
    startidx = startidx > len ? len : startidx;
    delcnt = (deleteCount > 0) ? deleteCount : 0;
    if(delcnt > len - startidx)
        delcnt = len - startidx;
}

    A = cc.realm.dArray();

    // If deleteCount is not specified, ECMA implies it should
    // be 0, while "JavaScript The Definitive Guide" says it should
    // be delete to end of array. Jscript doesn't implement splice().
    // We'll do it the Guide way.
    if(arglist.length < 2)
        delcnt = len - startidx;

    //writef("Darray.splice(startidx = %d, delcnt = %d)\n", startidx, delcnt);
    for(k = 0; k != delcnt; k++)
    {
        if (othis.Get(PropertyKey(startidx + k), v, cc).onError(err))
            return err;
        if(!v.isEmpty)
            A.Set(PropertyKey(k), v, Property.Attribute.None, cc);
    }

    auto delv = Value(delcnt);
    A.Set(Key.length, delv, Property.Attribute.DontEnum, cc);
    inscnt = (arglist.length > 2) ? cast(uint)arglist.length - 2 : 0;
    if(inscnt != delcnt)
    {
        if(inscnt <= delcnt)
        {
            for(k = startidx; k != (len - delcnt); k++)
            {
                if (othis.Get(PropertyKey(k + delcnt), v, cc).onError(err))
                    return err;
                if(!v.isEmpty)
                    othis.Set(PropertyKey(k + inscnt), v,
                              Property.Attribute.None, cc);
                else
                    othis.Delete(PropertyKey(k + inscnt));
            }

            for(k = len; k != (len - delcnt + inscnt); k--)
                othis.Delete(PropertyKey(k - 1));
        }
        else
        {
            for(k = len - delcnt; k != startidx; k--)
            {
                if (othis.Get(PropertyKey(k + delcnt - 1), v, cc).onError(err))
                    return err;
                if(!v.isEmpty)
                    othis.Set(PropertyKey(k + inscnt - 1), v,
                              Property.Attribute.None, cc);
                else
                    othis.Delete(PropertyKey(k + inscnt - 1));
            }
        }
    }
    k = startidx;
    for(a = 2; a < arglist.length; a++)
    {
        othis.Set(PropertyKey(k), arglist[a], Property.Attribute.None, cc);
        k++;
    }

    v.put(len - delcnt + inscnt);
    othis.Set(Key.length, v, Property.Attribute.DontEnum, cc);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror unshift(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.property: Property;
    // ECMA v3 15.4.4.13
    Value v;
    uint len;
    uint k;
    Value val;
    Derror err;

    if (othis.Get(PropertyKey(Key.length), v, cc).onError(err))
        return err;
    if(v.isEmpty)
        v.putVundefined;
    if (v.to(len, cc).onError(err))
        return err;

    for(k = len; k>0; k--)
    {
        if (othis.Get(PropertyKey(k - 1), v, cc).onError(err))
            return err;
        if(!v.isEmpty)
            othis.Set(PropertyKey(cast(uint)(k + arglist.length - 1)), v,
                      Property.Attribute.None, cc);
        else
            othis.Delete(PropertyKey(cast(uint)(k + arglist.length - 1)));
    }

    for(k = 0; k < arglist.length; k++)
    {
        othis.Set(PropertyKey(k), arglist[k], Property.Attribute.None, cc);
    }
    val.put(len + arglist.length);
    othis.Set(Key.length, val, Property.Attribute.DontEnum, cc);
    ret.put(len + arglist.length);
    return null;
}

//
@DFD(1)
Derror copyWithin(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(0)
Derror entries(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror every(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror fill(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror filter(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror find(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror findIndex(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror forEach(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror includes(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror indexOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror keys(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror lastIndexOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror map(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror reduce(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror reduceRight(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror some(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}

//
@DFD(1)
Derror values(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    ArgList arglist)
{
    assert (0);
}
