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
import dmdscript.value: Value, DError;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.drealm: Drealm;

//==============================================================================
///
class Darray : Dobject
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;

    Value length;               // length property
    uint ulength;

    override
    DError* Set(in PropertyKey key, ref Value v,
                in Property.Attribute attributes, Drealm realm)
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
            proptable.set(pk, v, attributes, realm, this, IsExtensible);
            return null;
        }
        else
        {
            uint i;
            uint c;
            DError* result;

            // ECMA 15.4.5.1
            result = proptable.set(key, v, attributes, realm, this, IsExtensible);
            if(!result)
            {
                if(key == Key.length)
                {
                    i = v.toUint32(realm);
                    if(i != v.toInteger(realm))
                    {
                        return LengthIntError(realm);
                    }
                    if(i < ulength)
                    {
                        // delete all properties with keys >= i
                        uint[] todelete;

                        foreach(PropertyKey key, ref Property p; proptable)
                        {
                            uint j;

                            if(key.isArrayIndex(j) && j >= i)
                                todelete ~= j;
                        }
                        PropertyKey k;
                        foreach(uint j; todelete)
                        {
                            k.put(j);
                            proptable.del(k);
                        }
                    }
                    ulength = i;
                    length.number = i;
                    proptable.set(key, v, attributes |
                                  Property.Attribute.DontEnum, realm, this,
                                  IsExtensible);
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

    override Value* Get(in PropertyKey PropertyName, Drealm realm)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(PropertyName == Key.length)
        {
            length.number = ulength;
            return &length;
        }
        else
        {
            return Dobject.Get(PropertyName, realm);
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

    override DError* Construct(Drealm realm, out Value ret,
                               Value[] arglist)
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

                len = v.toUint32(realm);
                if(cast(double)len != v.number)
                {
                    ret.putVundefined;
                    return ArrayLenOutOfBoundsError(realm, v.number);
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
                a.Set(PropertyKey(0), *v, Property.Attribute.None, realm);
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
                a.Set(PropertyKey(k), arglist[k], Property.Attribute.None, realm);
            }
        }
        ret = a.value;
        //writef("Darray_constructor.Construct(): length = %g\n", a.length.number);
        return null;
    }


    Darray opCall()
    {
        return new Darray(classPrototype);
    }

}


//==============================================================================
private:

//
@DFD(1, DFD.Type.Static)
DError* from(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
DError* isArray(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
DError* of(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}




//------------------------------------------------------------------------------
@DFD(0)
DError* toString(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    //writef("Darray_prototype_toString()\n");
    array_join(realm, othis, ret, null);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toLocaleString(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.program: Program;
    import dmdscript.locale: Locale;
    import dmdscript.errmsgs: TlsNotTransferrableError;

    // ECMA v3 15.4.4.3
    string separator;
    string r;
    uint len;
    uint k;
    Value* v;

    if ((cast(Darray)othis) is null)
    {
        ret.putVundefined();
        return TlsNotTransferrableError(realm);
    }

    v = othis.Get(Key.length, realm);
    len = v ? v.toUint32(realm) : 0;

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
        v = othis.Get(PropertyKey(k), realm);
        if(v && !v.isUndefinedOrNull())
        {
            Dobject ot;

            ot = v.toObject(realm);
            v = ot.Get(Key.toLocaleString, realm);
            if(v && !v.isPrimitive())   // if it's an Object
            {
                DError* a;
                Dobject o;
                Value rt;

                o = v.object;
                rt.putVundefined();
                a = o.Call(realm, ot, rt, null);
                if(a)                   // if exception was thrown
                    return a;
                r ~= rt.toString(realm);
            }
        }
    }

    ret.put(r);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* concat(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    // ECMA v3 15.4.4.4
    Darray A;
    Darray E;
    Value* v;
    uint k;
    uint n;
    uint a;

    A = realm.dArray();
    n = 0;
    v = &othis.value;
    for(a = 0;; a++)
    {
        if(!v.isPrimitive() && (E = (cast(Darray)v.object)) !is null)
        {
            uint len;

            len = E.ulength;
            for(k = 0; k != len; k++)
            {
                v = E.Get(PropertyKey(k), realm);
                if(v)
                    A.Set(PropertyKey(n), *v, Property.Attribute.None, realm);
                n++;
            }
        }
        else
        {
            A.Set(PropertyKey(n), *v, Property.Attribute.None, realm);
            n++;
        }
        if(a == arglist.length)
            break;
        v = &arglist[a];
    }

    auto vl = Value(n);
    A.Set(Key.length, vl, Property.Attribute.DontEnum, realm);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* join(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    array_join(realm, othis, ret, arglist);
    return null;
}

//
void array_join(Drealm realm, Dobject othis, out Value ret,
                Value[] arglist)
{
    import dmdscript.primitive : Text, PropertyKey, Key;

    // ECMA 15.4.4.3
    string separator;
    string r;
    uint len;
    uint k;
    Value* v;

    //writef("array_join(othis = %p)\n", othis);
    v = othis.Get(Key.length, realm);
    len = v ? v.toUint32(realm) : 0;
    if(arglist.length == 0 || arglist[0].isUndefined())
        separator = Text.comma;
    else
        separator = arglist[0].toString(realm);

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(PropertyKey(k), realm);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toString(realm);
    }

    ret.put(r);
}

//------------------------------------------------------------------------------
@DFD(0)
DError* toSource(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : PropertyKey, Key;

    string separator;
    string r;
    uint len;
    uint k;
    Value* v;

    v = othis.Get(Key.length, realm);
    len = v ? v.toUint32(realm) : 0;
    separator = ",";

    r = "[".idup;
    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(PropertyKey(k), realm);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toSource(realm);
    }
    r ~= "]";

    ret.put(r);
    return null;
}


//------------------------------------------------------------------------------
@DFD(0)
DError* pop(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    import dmdscript.drealm: undefined;
    // ECMA v3 15.4.4.6
    Value* v;
    Value val;
    uint u;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(Key.length, realm);
    if(!v)
        v = &undefined;
    u = v.toUint32(realm);
    if(u == 0)
    {
        val.put(0.0);
        othis.Set(Key.length, val, Property.Attribute.DontEnum, realm);
        ret.putVundefined();
    }
    else
    {
        v = othis.Get(PropertyKey(u - 1), realm);
        if(!v)
            v = &undefined;
        ret = *v;
        val.put(u - 1);
        othis.Delete(PropertyKey(u - 1));
        othis.Set(Key.length, val, Property.Attribute.DontEnum, realm);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* push(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    import dmdscript.drealm: undefined;

    // ECMA v3 15.4.4.7
    Value* v;
    Value val;
    uint u;
    uint a;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(Key.length, realm);
    if(!v)
        v = &undefined;
    u = v.toUint32(realm);
    for(a = 0; a < arglist.length; a++)
    {
        val.put(arglist[a]);
        othis.Set(PropertyKey(u + a), val, Property.Attribute.None, realm);
    }
    val.put(u + a);
    othis.Set(Key.length, val,  Property.Attribute.DontEnum, realm);
    ret.put(u + a);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* reverse(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;

    // ECMA 15.4.4.4
    uint a;
    uint b;
    Value* va;
    Value* vb;
    Value* v;
    uint pivot;
    uint len;
    Value tmp;

    v = othis.Get(Key.length, realm);
    len = v ? v.toUint32(realm) : 0;
    pivot = len / 2;
    for(a = 0; a != pivot; a++)
    {
        b = len - a - 1;
        //writef("a = %d, b = %d\n", a, b);
        va = othis.Get(PropertyKey(a), realm);
        if(va)
            tmp = *va;
        vb = othis.Get(PropertyKey(b), realm);
        if(vb)
            othis.Set(PropertyKey(a), *vb, Property.Attribute.None, realm);
        else
            othis.Delete(PropertyKey(a));

        if(va)
            othis.Set(PropertyKey(b), tmp, Property.Attribute.None, realm);
        else
            othis.Delete(PropertyKey(b));
    }
    ret = othis.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* shift(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.property: Property;
    import dmdscript.drealm: undefined;
    import dmdscript.value: vundefined;

    // ECMA v3 15.4.4.9
    Value* v;
    Value* result;
    uint len;
    uint k;

    // If othis is a Darray, then we can optimize this significantly
    //writef("shift(othis = %p)\n", othis);
    v = othis.Get(Key.length, realm);
    if(!v)
        v = &undefined;
    len = v.toUint32(realm);

    if(len)
    {
        result = othis.Get(PropertyKey(0u), realm);
        ret = result ? *result : vundefined;
        for(k = 1; k != len; k++)
        {
            v = othis.Get(PropertyKey(k), realm);
            if(v)
            {
                othis.Set(PropertyKey(k - 1), *v, Property.Attribute.None, realm);
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
        ret = vundefined;

    auto vlen = Value(len);
    othis.Set(Key.length, vlen, Property.Attribute.DontEnum, realm);
    return null;
}


//------------------------------------------------------------------------------
@DFD(2)
DError* slice(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: PropertyKey, Key;
    import dmdscript.drealm: undefined;
    import dmdscript.value: vundefined;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.10
    uint len;
    uint n;
    uint k;
    uint r8;

    Value* v;
    Darray A;

    v = othis.Get(Key.length, realm);
    if(!v)
        v = &undefined;
    len = v.toUint32(realm);

version(SliceSpliceExtension){
    double start;
    double end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(realm);
        end = len;
        break;

    case 1:
        start = arglist[0].toNumber(realm);
        end = len;
        break;

    default:
        start = arglist[0].toNumber(realm);
        if(arglist[1].isUndefined())
        {
            end = len;
        }
        else
        {
            end = arglist[1].toNumber(realm);
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
    A = realm.dArray();
    for(n = 0; k < r8; k++)
    {
        v = othis.Get(PropertyKey(k), realm);
        if(v)
        {
            A.Set(PropertyKey(n), *v, Property.Attribute.None, realm);
        }
        n++;
    }

    auto vn = Value(n);
    A.Set(Key.length, vn, Property.Attribute.DontEnum, realm);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
static Dobject comparefn;
static Drealm compareRealm;

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
            comparefn.Call(compareRealm, comparefn, ret, arglist);
            n = ret.toNumber(compareRealm);
            if(n < 0)
                cmp = -1;
            else if(n > 0)
                cmp = 1;
            else
                cmp = 0;
        }
        else
        {
            sx = vx.toString(compareRealm);
            sy = vy.toString(compareRealm);
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
DError* sort(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : qsort;
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.11
    Value* v;
    uint len;
    uint u;

    //writef("Array.prototype.sort()\n");
    v = othis.Get(Key.length, realm);
    len = v ? v.toUint32(realm) : 0;

    // This is not optimal, as isArrayIndex is done at least twice
    // for every array member. Additionally, the qsort() by index
    // can be avoided if we can deduce it is not a sparse array.

    Property* p;
    Value[] pvalues;
    uint[] pindices;
    uint parraydim;
    uint nprops;

    // First, size & alloc our temp array
    if(len < 100)
    {   // Probably not too sparse an array
        parraydim = len;
    }
    else
    {
        parraydim = 0;
        foreach(ref Property p; othis.proptable)
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

    uint[] p2 = null;
    uint* p3;
    version(Win32)
    {
        if(parraydim < 128)
            p3 = cast(uint*)alloca(parraydim * uint.sizeof);
    }
    if(p3)
        pindices = p3[0 .. parraydim];
    else
    {
        p2 = new uint[parraydim];
        pindices = p2;
    }

    // Now fill it with all the Property's that are array indices
    nprops = 0;
    foreach(ref PropertyKey key, ref Property p; othis.proptable)
    {
        uint index;

        if(p.isNoneAttribute && key.isArrayIndex(index))
        {
            pindices[nprops] = index;
            pvalues[nprops] = *p.get(realm, othis);
            nprops++;
        }
    }

    synchronized
    {
        comparefn = null;
        compareRealm = realm;
        if(arglist.length)
        {
            if(!arglist[0].isPrimitive())
                comparefn = arglist[0].object;
        }

        // Sort pvalues[]
        qsort(pvalues.ptr, nprops, Value.sizeof, &compare_value);

        comparefn = null;
        compareRealm = null;
    }

    // Stuff the sorted value's back into the array
    for(u = 0; u < nprops; u++)
    {
        uint index;

        othis.Set(PropertyKey(u), pvalues[u], Property.Attribute.None, realm);
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
DError* splice(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.drealm: undefined;
    import dmdscript.value: vundefined;
    import dmdscript.property: Property;

    // ECMA v3 15.4.4.12
    uint len;
    uint k;

    Value* v;
    Darray A;
    uint a;
    uint delcnt;
    uint inscnt;
    uint startidx;

    v = othis.Get(Key.length, realm);
    if(!v)
        v = &undefined;
    len = v.toUint32(realm);

version(SliceSpliceExtension){
    double start;
    double deleteCount;

    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(realm);
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toNumber(realm);
        deleteCount = vundefined.toNumber(realm);
        break;

    default:
        start = arglist[0].toNumber(realm);
        deleteCount = arglist[1].toNumber(realm);
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

    A = realm.dArray();

    // If deleteCount is not specified, ECMA implies it should
    // be 0, while "JavaScript The Definitive Guide" says it should
    // be delete to end of array. Jscript doesn't implement splice().
    // We'll do it the Guide way.
    if(arglist.length < 2)
        delcnt = len - startidx;

    //writef("Darray.splice(startidx = %d, delcnt = %d)\n", startidx, delcnt);
    for(k = 0; k != delcnt; k++)
    {
        v = othis.Get(PropertyKey(startidx + k), realm);
        if(v)
            A.Set(PropertyKey(k), *v, Property.Attribute.None, realm);
    }

    auto delv = Value(delcnt);
    A.Set(Key.length, delv, Property.Attribute.DontEnum, realm);
    inscnt = (arglist.length > 2) ? cast(uint)arglist.length - 2 : 0;
    if(inscnt != delcnt)
    {
        if(inscnt <= delcnt)
        {
            for(k = startidx; k != (len - delcnt); k++)
            {
                v = othis.Get(PropertyKey(k + delcnt), realm);
                if(v)
                    othis.Set(PropertyKey(k + inscnt), *v,
                              Property.Attribute.None, realm);
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
                v = othis.Get(PropertyKey(k + delcnt - 1), realm);
                if(v)
                    othis.Set(PropertyKey(k + inscnt - 1), *v,
                              Property.Attribute.None, realm);
                else
                    othis.Delete(PropertyKey(k + inscnt - 1));
            }
        }
    }
    k = startidx;
    for(a = 2; a < arglist.length; a++)
    {
        v = &arglist[a];
        othis.Set(PropertyKey(k), *v, Property.Attribute.None, realm);
        k++;
    }

    auto lv = Value(len - delcnt + inscnt);
    othis.Set(Key.length, lv, Property.Attribute.DontEnum, realm);
    ret = A.value;
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* unshift(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : PropertyKey, Key;
    import dmdscript.drealm: undefined;
    import dmdscript.property: Property;
    // ECMA v3 15.4.4.13
    Value* v;
    uint len;
    uint k;
    Value val;

    v = othis.Get(PropertyKey(Key.length), realm);
    if(!v)
        v = &undefined;
    len = v.toUint32(realm);

    for(k = len; k>0; k--)
    {
        v = othis.Get(PropertyKey(k - 1), realm);
        if(v)
            othis.Set(PropertyKey(cast(uint)(k + arglist.length - 1)), *v,
                      Property.Attribute.None, realm);
        else
            othis.Delete(PropertyKey(cast(uint)(k + arglist.length - 1)));
    }

    for(k = 0; k < arglist.length; k++)
    {
        othis.Set(PropertyKey(k), arglist[k], Property.Attribute.None, realm);
    }
    val.put(len + arglist.length);
    othis.Set(Key.length, val, Property.Attribute.DontEnum, realm);
    ret.put(len + arglist.length);
    return null;
}

//
@DFD(1)
DError* copyWithin(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(0)
DError* entries(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* every(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* fill(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* filter(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* find(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* findIndex(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* forEach(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* includes(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* indexOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* keys(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* lastIndexOf(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* map(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* reduce(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* reduceRight(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* some(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
DError* values(
    DnativeFunction pthis, Drealm realm, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}
