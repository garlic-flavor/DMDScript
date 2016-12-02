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

//Nonstandard treatment of Infinity as array length in slice/splice functions, supported by majority of browsers
//also treats negative starting index in splice wrapping it around just like in slice
version =  SliceSpliceExtension;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.identifier;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.protoerror;
import dmdscript.dnative;
import dmdscript.program;

/* ===================== Darray_constructor ==================== */

class DarrayConstructor : Dconstructor
{
    this()
    {
        super(Text.Array, 1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.4.2
        Darray a;

        a = new Darray();
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
                d_uint32 len;

                len = v.toUint32(cc);
                if(cast(double)len != v.number)
                {
                    ret.putVundefined;
                    return ArrayLenOutOfBoundsError(v.number);
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
                a.Set(cast(d_uint32)0, *v, Property.Attribute.None, cc);
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
                a.Set(k, arglist[k], Property.Attribute.None, cc);
            }
        }
        ret = a.value;
        //writef("Darray_constructor.Construct(): length = %g\n", a.length.number);
        return null;
    }
}


/* ===================== Darray_prototype_toString ================= */

DError* Darray_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    //writef("Darray_prototype_toString()\n");
    array_join(cc, othis, ret, null);
    return null;
}

/* ===================== Darray_prototype_toLocaleString ================= */

DError* Darray_prototype_toLocaleString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.3
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    if(!othis.isClass(Text.Array))
    {
        ret.putVundefined();
        return TlsNotTransferrableError;
    }

    v = othis.Get(Text.length, cc);
    len = v ? v.toUint32(cc) : 0;

    Program prog = cc.prog;
    if(!prog.slist)
    {
        // Determine what list separator is only once per thread
        //prog.slist = list_separator(prog.lcid);
        prog.slist = ",";
    }
    separator = prog.slist;

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k, cc);
        if(v && !v.isUndefinedOrNull())
        {
            Dobject ot;

            ot = v.toObject();
            v = ot.Get(Text.toLocaleString, cc);
            if(v && !v.isPrimitive())   // if it's an Object
            {
                DError* a;
                Dobject o;
                Value rt;

                o = v.object;
                rt.putVundefined();
                a = o.Call(cc, ot, rt, null);
                if(a)                   // if exception was thrown
                    return a;
                r ~= rt.toString();
            }
        }
    }

    ret.put(r);
    return null;
}

/* ===================== Darray_prototype_concat ================= */

DError* Darray_prototype_concat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.4
    Darray A;
    Darray E;
    Value* v;
    d_uint32 k;
    d_uint32 n;
    d_uint32 a;

    A = new Darray();
    n = 0;
    v = &othis.value;
    for(a = 0;; a++)
    {
        if(!v.isPrimitive() && v.object.isDarray())
        {
            d_uint32 len;

            E = cast(Darray)v.object;
            len = E.ulength;
            for(k = 0; k != len; k++)
            {
                v = E.Get(k, cc);
                if(v)
                    A.Set(n, *v, Property.Attribute.None, cc);
                n++;
            }
        }
        else
        {
            A.Set(n, *v, Property.Attribute.None, cc);
            n++;
        }
        if(a == arglist.length)
            break;
        v = &arglist[a];
    }

    A.Set(Text.length, n, Property.Attribute.DontEnum, cc);
    ret = A.value;
    return null;
}

/* ===================== Darray_prototype_join ================= */

DError* Darray_prototype_join(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    array_join(cc, othis, ret, arglist);
    return null;
}

void array_join(ref CallContext cc, Dobject othis, out Value ret,
                Value[] arglist)
{
    // ECMA 15.4.4.3
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    //writef("array_join(othis = %p)\n", othis);
    v = othis.Get(Text.length, cc);
    len = v ? v.toUint32(cc) : 0;
    if(arglist.length == 0 || arglist[0].isUndefined())
        separator = Text.comma;
    else
        separator = arglist[0].toString();

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k, cc);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toString();
    }

    ret.put(r);
}

/* ===================== Darray_prototype_toSource ================= */

DError* Darray_prototype_toSource(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    v = othis.Get(Text.length, cc);
    len = v ? v.toUint32(cc) : 0;
    separator = ",";

    r = "[".idup;
    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k, cc);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toSource(cc);
    }
    r ~= "]";

    ret.put(r);
    return null;
}


/* ===================== Darray_prototype_pop ================= */

DError* Darray_prototype_pop(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.6
    Value* v;
    d_uint32 u;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    u = v.toUint32(cc);
    if(u == 0)
    {
        othis.Set(Text.length, 0.0, Property.Attribute.DontEnum, cc);
        ret.putVundefined();
    }
    else
    {
        v = othis.Get(u - 1, cc);
        if(!v)
            v = &vundefined;
        ret = *v;
        othis.Delete(u - 1);
        othis.Set(Text.length, u - 1, Property.Attribute.DontEnum, cc);
    }
    return null;
}

/* ===================== Darray_prototype_push ================= */

DError* Darray_prototype_push(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.7
    Value* v;
    d_uint32 u;
    d_uint32 a;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    u = v.toUint32(cc);
    for(a = 0; a < arglist.length; a++)
    {
        othis.Set(u + a, arglist[a], Property.Attribute.None, cc);
    }
    othis.Set(Text.length, u + a,  Property.Attribute.DontEnum, cc);
    ret.put(u + a);
    return null;
}

/* ===================== Darray_prototype_reverse ================= */

DError* Darray_prototype_reverse(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.4.4.4
    d_uint32 a;
    d_uint32 b;
    Value* va;
    Value* vb;
    Value* v;
    d_uint32 pivot;
    d_uint32 len;
    Value tmp;

    v = othis.Get(Text.length, cc);
    len = v ? v.toUint32(cc) : 0;
    pivot = len / 2;
    for(a = 0; a != pivot; a++)
    {
        b = len - a - 1;
        //writef("a = %d, b = %d\n", a, b);
        va = othis.Get(a, cc);
        if(va)
            tmp = *va;
        vb = othis.Get(b, cc);
        if(vb)
            othis.Set(a, *vb, Property.Attribute.None, cc);
        else
            othis.Delete(a);

        if(va)
            othis.Set(b, tmp, Property.Attribute.None, cc);
        else
            othis.Delete(b);
    }
    ret = othis.value;
    return null;
}

/* ===================== Darray_prototype_shift ================= */

DError* Darray_prototype_shift(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.9
    Value* v;
    Value* result;
    d_uint32 len;
    d_uint32 k;

    // If othis is a Darray, then we can optimize this significantly
    //writef("shift(othis = %p)\n", othis);
    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

    if(len)
    {
        result = othis.Get(0u, cc);
        ret = result ? *result : vundefined;
        for(k = 1; k != len; k++)
        {
            v = othis.Get(k, cc);
            if(v)
            {
                othis.Set(k - 1, *v, Property.Attribute.None, cc);
            }
            else
            {
                othis.Delete(k - 1);
            }
        }
        othis.Delete(len - 1);
        len--;
    }
    else
        ret = vundefined;

    othis.Set(Text.length, len, Property.Attribute.DontEnum, cc);
    return null;
}


/* ===================== Darray_prototype_slice ================= */

DError* Darray_prototype_slice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.10
    d_uint32 len;
    d_uint32 n;
    d_uint32 k;
    d_uint32 r8;

    Value* v;
    Darray A;

    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

version(SliceSpliceExtension){
    d_number start;
    d_number end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(cc);
        end = len;
        break;

    case 1:
        start = arglist[0].toNumber(cc);
        end = len;
        break;

    default:
        start = arglist[0].toNumber(cc);
        if(arglist[1].isUndefined())
        {
            end = len;
        }
        else
        {
            end = arglist[1].toNumber(cc);
        }
        break;
    }
    if(start < 0)
    {
        k = cast(uint)(len + start);
        if(cast(d_int32)k < 0)
            k = 0;
    }
    else if(start == d_number.infinity)
        k = len;
    else if(start == -d_number.infinity)
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
        if(cast(d_int32)r8 < 0)
            r8 = 0;
    }
    else if(end == d_number.infinity)
            r8 = len;
    else if(end == -d_number.infinity)
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
        if(cast(d_int32)k < 0)
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
        if(cast(d_int32)r8 < 0)
            r8 = 0;
    }
    else
    {
        r8 = cast(uint)end;
        if(len < end)
            r8 = len;
    }
}
    A = new Darray();
    for(n = 0; k < r8; k++)
    {
        v = othis.Get(k, cc);
        if(v)
        {
            A.Set(n, *v, Property.Attribute.None, cc);
        }
        n++;
    }

    A.Set(Text.length, n, Property.Attribute.DontEnum, cc);
    ret = A.value;
    return null;
}

/* ===================== Darray_prototype_sort ================= */

static Dobject comparefn;
static CallContext* comparecc;

extern (C) int compare_value(const void* x, const void* y)
{
    import std.string : stdcmp = cmp;

    Value* vx = cast(Value*)x;
    Value* vy = cast(Value*)y;
    d_string sx;
    d_string sy;
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
            d_number n;

            arglist[0] = *vx;
            arglist[1] = *vy;
            ret.putVundefined();
            comparefn.Call(*comparecc, comparefn, ret, arglist);
            n = ret.toNumber(*comparecc);
            if(n < 0)
                cmp = -1;
            else if(n > 0)
                cmp = 1;
            else
                cmp = 0;
        }
        else
        {
            sx = vx.toString();
            sy = vy.toString();
            cmp = stdcmp(sx, sy);
            if(cmp < 0)
                cmp = -1;
            else if(cmp > 0)
                cmp = 1;
        }
    }
    return cmp;
}

DError* Darray_prototype_sort(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : qsort;

    // ECMA v3 15.4.4.11
    Value* v;
    d_uint32 len;
    uint u;

    //writef("Array.prototype.sort()\n");
    v = othis.Get(Text.length, cc);
    len = v ? v.toUint32(cc) : 0;

    // This is not optimal, as isArrayIndex is done at least twice
    // for every array member. Additionally, the qsort() by index
    // can be avoided if we can deduce it is not a sparse array.

    Property* p;
    Value[] pvalues;
    d_uint32[] pindices;
    d_uint32 parraydim;
    d_uint32 nprops;

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

    d_uint32[] p2 = null;
    d_uint32* p3;
    version(Win32)
    {
        if(parraydim < 128)
            p3 = cast(d_uint32*)alloca(parraydim * d_uint32.sizeof);
    }
    if(p3)
        pindices = p3[0 .. parraydim];
    else
    {
        p2 = new d_uint32[parraydim];
        pindices = p2;
    }

    // Now fill it with all the Property's that are array indices
    nprops = 0;
    foreach(ref PropertyKey key, ref Property p; othis.proptable)
    {
        d_uint32 index;

        if(p.isNoneAttribute && key.isArrayIndex(cc, index))
        {
            pindices[nprops] = index;
            pvalues[nprops] = *p.get(cc, othis);
            nprops++;
        }
    }

    synchronized
    {
        comparefn = null;
        comparecc = &cc;
        if(arglist.length)
        {
            if(!arglist[0].isPrimitive())
                comparefn = arglist[0].object;
        }

        // Sort pvalues[]
        qsort(pvalues.ptr, nprops, Value.sizeof, &compare_value);

        comparefn = null;
        comparecc = null;
    }

    // Stuff the sorted value's back into the array
    for(u = 0; u < nprops; u++)
    {
        d_uint32 index;

        othis.Set(u, pvalues[u], Property.Attribute.None, cc);
        index = pindices[u];
        if(index >= nprops)
        {
            othis.Delete(index);
        }
    }

    delete p1;
    delete p2;

    ret.put(othis);
    return null;
}

/* ===================== Darray_prototype_splice ================= */

DError* Darray_prototype_splice(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.12
    d_uint32 len;
    d_uint32 k;

    Value* v;
    Darray A;
    d_uint32 a;
    d_uint32 delcnt;
    d_uint32 inscnt;
    d_uint32 startidx;

    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

version(SliceSpliceExtension){
    d_number start;
    d_number deleteCount;

    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(cc);
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toNumber(cc);
        deleteCount = vundefined.toNumber(cc);
        break;

    default:
        start = arglist[0].toNumber(cc);
        deleteCount = arglist[1].toNumber(cc);
        //checked later
        break;
    }
    if(start == d_number.infinity)
        startidx = len;
    else if(start == -d_number.infinity)
        startidx = 0;
    else{
        if(start < 0)
        {
            startidx = cast(uint)(len + start);
            if(cast(d_int32)startidx < 0)
                startidx = 0;
        }
        else
            startidx = cast(uint)start;
    }
    startidx = startidx > len ? len : startidx;
    if(deleteCount == d_number.infinity)
        delcnt = len;
    else if(deleteCount == -d_number.infinity)
        delcnt = 0;
    else
        delcnt = (cast(uint)deleteCount > 0) ? cast(uint) deleteCount : 0;
    if(delcnt > len - startidx)
        delcnt = len - startidx;
}
else
{
    long start;
    d_int32 deleteCount;
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

    A = new Darray();

    // If deleteCount is not specified, ECMA implies it should
    // be 0, while "JavaScript The Definitive Guide" says it should
    // be delete to end of array. Jscript doesn't implement splice().
    // We'll do it the Guide way.
    if(arglist.length < 2)
        delcnt = len - startidx;

    //writef("Darray.splice(startidx = %d, delcnt = %d)\n", startidx, delcnt);
    for(k = 0; k != delcnt; k++)
    {
        v = othis.Get(startidx + k, cc);
        if(v)
            A.Set(k, *v, Property.Attribute.None, cc);
    }

    A.Set(Text.length, delcnt, Property.Attribute.DontEnum, cc);
    inscnt = (arglist.length > 2) ? cast(uint)arglist.length - 2 : 0;
    if(inscnt != delcnt)
    {
        if(inscnt <= delcnt)
        {
            for(k = startidx; k != (len - delcnt); k++)
            {
                v = othis.Get(k + delcnt, cc);
                if(v)
                    othis.Set(k + inscnt, *v, Property.Attribute.None, cc);
                else
                    othis.Delete(k + inscnt);
            }

            for(k = len; k != (len - delcnt + inscnt); k--)
                othis.Delete(k - 1);
        }
        else
        {
            for(k = len - delcnt; k != startidx; k--)
            {
                v = othis.Get(k + delcnt - 1, cc);
                if(v)
                    othis.Set(k + inscnt - 1, *v, Property.Attribute.None, cc);
                else
                    othis.Delete(k + inscnt - 1);
            }
        }
    }
    k = startidx;
    for(a = 2; a < arglist.length; a++)
    {
        v = &arglist[a];
        othis.Set(k, *v, Property.Attribute.None, cc);
        k++;
    }

    othis.Set(Text.length, len - delcnt + inscnt,
              Property.Attribute.DontEnum, cc);
    ret = A.value;
    return null;
}

/* ===================== Darray_prototype_unshift ================= */

DError* Darray_prototype_unshift(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.4.4.13
    Value* v;
    d_uint32 len;
    d_uint32 k;

    v = othis.Get(Text.length, cc);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

    for(k = len; k>0; k--)
    {
        v = othis.Get(k - 1, cc);
        if(v)
            othis.Set(cast(uint)(k + arglist.length - 1), *v,
                      Property.Attribute.None, cc);
        else
            othis.Delete(cast(uint)(k + arglist.length - 1));
    }

    for(k = 0; k < arglist.length; k++)
    {
        othis.Set(k, arglist[k], Property.Attribute.None, cc);
    }
    othis.Set(Text.length, len + arglist.length,
              Property.Attribute.DontEnum, cc);
    ret.put(len + arglist.length);
    return null;
}

/* =========================== Darray_prototype =================== */

class DarrayPrototype : Darray
{
    this()
    {
        super(Dobject.getPrototype);
        Dobject f = Dfunction.getPrototype;

        DefineOwnProperty(Text.constructor, Darray.getConstructor,
               Property.Attribute.DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { Text.toString, &Darray_prototype_toString, 0 },
            { Text.toLocaleString, &Darray_prototype_toLocaleString, 0 },
            { Text.toSource, &Darray_prototype_toSource, 0 },
            { Text.concat, &Darray_prototype_concat, 1 },
            { Text.join, &Darray_prototype_join, 1 },
            { Text.pop, &Darray_prototype_pop, 0 },
            { Text.push, &Darray_prototype_push, 1 },
            { Text.reverse, &Darray_prototype_reverse, 0 },
            { Text.shift, &Darray_prototype_shift, 0, },
            { Text.slice, &Darray_prototype_slice, 2 },
            { Text.sort, &Darray_prototype_sort, 1 },
            { Text.splice, &Darray_prototype_splice, 2 },
            { Text.unshift, &Darray_prototype_unshift, 1 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);
    }
}


/* =========================== Darray =================== */

class Darray : Dobject
{
    Value length;               // length property
    d_uint32 ulength;

    this()
    {
        this(getPrototype());
    }

    this(Dobject prototype)
    {
        super(prototype);
        length.put(0);
        ulength = 0;
        classname = Text.Array;
    }

    override
    DError* Set(ref Identifier key, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        auto pk = PropertyKey(key);
        auto result = proptable.set(pk, value, attributes, cc, this);
        if(!result)
            Set(key.value.text, value, attributes, cc);
        return null;
    }

    override
    DError* Set(in d_string name, ref Value v,
                in Property.Attribute attributes, ref CallContext cc)
    {
        d_uint32 i;
        uint c;
        DError* result;

        // ECMA 15.4.5.1
        auto key = PropertyKey(name);
        result = proptable.set(key, v, attributes, cc, this);
        if(!result)
        {
            if(name == Text.length)
            {
                i = v.toUint32(cc);
                if(i != v.toInteger(cc))
                {
                    return LengthIntError;
                }
                if(i < ulength)
                {
                    // delete all properties with keys >= i
                    d_uint32[] todelete;

                    foreach(PropertyKey key, ref Property p; proptable)
                    {
                        d_uint32 j;

                        j = key.toUint32(cc);
                        if(j >= i)
                            todelete ~= j;
                    }
                    PropertyKey k;
                    foreach(d_uint32 j; todelete)
                    {
                        k.put(j);
                        proptable.del(k);
                    }
                }
                ulength = i;
                length.number = i;
                proptable.set(key, v, attributes | Property.Attribute.DontEnum,
                              cc, this);
            }

            // if (name is an array index i)

            i = 0;
            for(size_t j = 0; j < name.length; j++)
            {
                ulong k;

                c = name[j];
                if(c == '0' && i == 0 && name.length > 1)
                    goto Lret;
                if(c >= '0' && c <= '9')
                {
                    k = i * cast(ulong)10 + c - '0';
                    i = cast(d_uint32)k;
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

    override DError* Set(in d_string name, Dobject o,
                         in Property.Attribute attributes, ref CallContext cc)
    {
        return Set(name, o.value, attributes, cc);
    }

    override DError* Set(in d_string PropertyName, in d_number n,
                        in Property.Attribute attributes, ref CallContext cc)
    {
        Value v;

        v.put(n);
        return Set(PropertyName, v, attributes, cc);
    }

    override DError* Set(in d_string PropertyName, in d_string str,
                       in Property.Attribute attributes, ref CallContext cc)
    {
        Value v;

        v.put(str);
        return Set(PropertyName, v, attributes, cc);
    }

    override DError* Set(in d_uint32 index, ref Value vindex, ref Value value,
                         in Property.Attribute attributes, ref CallContext cc)
    {
        if(index >= ulength)
            ulength = index + 1;

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // Why is a magic number used?
        auto key = PropertyKey(vindex, index ^ 0x55555555);
        proptable.set(key, value, attributes, cc, this);
        // proptable.set(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/, value, attributes, cc, this);
        return null;
    }

    override DError* Set(in d_uint32 index, ref Value value,
                         in Property.Attribute attributes, ref CallContext cc)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        auto key = PropertyKey(index);
        proptable.set(key, value, attributes, cc, this);
        return null;
    }

    final DError* Set(d_uint32 index, d_string str,
                      Property.Attribute attributes, ref CallContext cc)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        Value value;
        auto key = PropertyKey(index);
        value.put(str);
        proptable.set(key, value, attributes, cc, this);
        return null;
    }

    override Value* Get(ref Identifier id, ref CallContext cc)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(id.value.text == Text.length)
        {
            length.number = ulength;
            return &length;
        }
        else
            return Dobject.Get(id, cc);
    }

    override Value* Get(in d_string PropertyName, in size_t hash,
                        ref CallContext cc)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(PropertyName == Text.length)
        {
            length.number = ulength;
            return &length;
        }
        else
        {
            return Dobject.Get(PropertyName, hash, cc);
        }
    }

    override Value* Get(in d_uint32 index, ref CallContext cc)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        auto key = PropertyKey(index);
        v = proptable.get(key, cc, this);
        return v;
    }

    override Value* Get(in d_uint32 index, ref Value vindex, ref CallContext cc)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        auto key = PropertyKey(vindex, index ^ 0x55555555);
        v = proptable.get(key, cc, this);

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // Why is a magic number used?
        // v = proptable.get(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/,
        //                   cc, this);
        return v;
    }

    override bool Delete(in d_string PropertyName)
    {
        // ECMA 8.6.2.5
        //writef("Darray.Delete('%ls')\n", d_string_ptr(PropertyName));
        if(PropertyName == Text.length)
            return 0;           // can't delete 'length' property
        else
        {
            auto key = PropertyKey(PropertyName);
            return proptable.del(key);
        }
    }

    override bool Delete(in d_uint32 index)
    {
        // ECMA 8.6.2.5
        auto key = PropertyKey(index);
        return proptable.del(key);
    }


static:
    Dfunction getConstructor()
    {
        return _constructor;
    }

    Dobject getPrototype()
    {
        return _prototype;
    }

    void initialize()
    {
        _constructor = new DarrayConstructor();
        _prototype = new DarrayPrototype();

        _constructor.DefineOwnProperty(Text.prototype, _prototype,
                            Property.Attribute.DontEnum |
                            Property.Attribute.ReadOnly);
    }
private:
    Dfunction _constructor;
    Dobject _prototype;
}


