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

class DarrayConstructor : Dfunction
{
    this()
    {
        super(1, Dfunction.getPrototype);
        name = "Array";
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

                len = v.toUint32();
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
                a.Put(cast(d_uint32)0, *v, Property.Attribute.None);
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
                a.Put(k, arglist[k], Property.Attribute.None);
            }
        }
        ret = a.value;
        //writef("Darray_constructor.Construct(): length = %g\n", a.length.number);
        return null;
    }

    override DError* Call(
        ref CallContext cc, Dobject othis, out Value ret, Value[] arglist)
    {
        // ECMA 15.4.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Darray_prototype_toString ================= */

DError* Darray_prototype_toString(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    //writef("Darray_prototype_toString()\n");
    array_join(othis, ret, null);
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

    v = othis.Get(Text.length);
    len = v ? v.toUint32() : 0;

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
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
        {
            Dobject ot;

            ot = v.toObject();
            v = ot.Get(Text.toLocaleString);
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

    ret.putVstring(r);
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
                v = E.Get(k);
                if(v)
                    A.Put(n, *v, Property.Attribute.None);
                n++;
            }
        }
        else
        {
            A.Put(n, *v, Property.Attribute.None);
            n++;
        }
        if(a == arglist.length)
            break;
        v = &arglist[a];
    }

    A.Put(Text.length, n, Property.Attribute.DontEnum);
    ret = A.value;
    return null;
}

/* ===================== Darray_prototype_join ================= */

DError* Darray_prototype_join(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    array_join(othis, ret, arglist);
    return null;
}

void array_join(Dobject othis, out Value ret, Value[] arglist)
{
    // ECMA 15.4.4.3
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    //writef("array_join(othis = %p)\n", othis);
    v = othis.Get(Text.length);
    len = v ? v.toUint32() : 0;
    if(arglist.length == 0 || arglist[0].isUndefined())
        separator = Text.comma;
    else
        separator = arglist[0].toString();

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toString();
    }

    ret.putVstring(r);
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

    v = othis.Get(Text.length);
    len = v ? v.toUint32() : 0;
    separator = ",";

    r = "[".idup;
    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toSource();
    }
    r ~= "]";

    ret.putVstring(r);
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
    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    u = v.toUint32();
    if(u == 0)
    {
        othis.Put(Text.length, 0.0, Property.Attribute.DontEnum);
        ret.putVundefined();
    }
    else
    {
        v = othis.Get(u - 1);
        if(!v)
            v = &vundefined;
        ret = *v;
        othis.Delete(u - 1);
        othis.Put(Text.length, u - 1, Property.Attribute.DontEnum);
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
    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    u = v.toUint32();
    for(a = 0; a < arglist.length; a++)
    {
        othis.Put(u + a, arglist[a], Property.Attribute.None);
    }
    othis.Put(Text.length, u + a,  Property.Attribute.DontEnum);
    ret.putVnumber(u + a);
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

    v = othis.Get(Text.length);
    len = v ? v.toUint32() : 0;
    pivot = len / 2;
    for(a = 0; a != pivot; a++)
    {
        b = len - a - 1;
        //writef("a = %d, b = %d\n", a, b);
        va = othis.Get(a);
        if(va)
            tmp = *va;
        vb = othis.Get(b);
        if(vb)
            othis.Put(a, *vb, Property.Attribute.None);
        else
            othis.Delete(a);

        if(va)
            othis.Put(b, tmp, Property.Attribute.None);
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
    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    len = v.toUint32();

    if(len)
    {
        result = othis.Get(0u);
        ret = result ? *result : vundefined;
        for(k = 1; k != len; k++)
        {
            v = othis.Get(k);
            if(v)
            {
                othis.Put(k - 1, *v, Property.Attribute.None);
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

    othis.Put(Text.length, len, Property.Attribute.DontEnum);
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

    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    len = v.toUint32();

version(SliceSpliceExtension){
    d_number start;
    d_number end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber();
        end = len;
        break;

    case 1:
        start = arglist[0].toNumber();
        end = len;
        break;

    default:
        start = arglist[0].toNumber();
        if(arglist[1].isUndefined())
        {
            end = len;
        }
        else
        {
            end = arglist[1].toNumber();
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
        v = othis.Get(k);
        if(v)
        {
            A.Put(n, *v, Property.Attribute.None);
        }
        n++;
    }

    A.Put(Text.length, n, Property.Attribute.DontEnum);
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
            n = ret.toNumber();
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
    v = othis.Get(Text.length);
    len = v ? v.toUint32() : 0;

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
            if(p.attributes == 0)       // don't count special properties
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
    foreach(Value key, ref Property p; othis.proptable)
    {
        d_uint32 index;

        if(p.attributes == 0 && key.isArrayIndex(index))
        {
            pindices[nprops] = index;
            pvalues[nprops] = p.value;
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

        othis.Put(u, pvalues[u], Property.Attribute.None);
        index = pindices[u];
        if(index >= nprops)
        {
            othis.Delete(index);
        }
    }

    delete p1;
    delete p2;

    ret.putVobject(othis);
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

    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    len = v.toUint32();

version(SliceSpliceExtension){
    d_number start;
    d_number deleteCount;

    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber();
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toNumber();
        deleteCount = vundefined.toNumber();
        break;

    default:
        start = arglist[0].toNumber();
        deleteCount = arglist[1].toNumber();
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
        v = othis.Get(startidx + k);
        if(v)
            A.Put(k, *v, Property.Attribute.None);
    }

    A.Put(Text.length, delcnt, Property.Attribute.DontEnum);
    inscnt = (arglist.length > 2) ? cast(uint)arglist.length - 2 : 0;
    if(inscnt != delcnt)
    {
        if(inscnt <= delcnt)
        {
            for(k = startidx; k != (len - delcnt); k++)
            {
                v = othis.Get(k + delcnt);
                if(v)
                    othis.Put(k + inscnt, *v, Property.Attribute.None);
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
                v = othis.Get(k + delcnt - 1);
                if(v)
                    othis.Put(k + inscnt - 1, *v, Property.Attribute.None);
                else
                    othis.Delete(k + inscnt - 1);
            }
        }
    }
    k = startidx;
    for(a = 2; a < arglist.length; a++)
    {
        v = &arglist[a];
        othis.Put(k, *v, Property.Attribute.None);
        k++;
    }

    othis.Put(Text.length, len - delcnt + inscnt,  Property.Attribute.DontEnum);
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

    v = othis.Get(Text.length);
    if(!v)
        v = &vundefined;
    len = v.toUint32();

    for(k = len; k>0; k--)
    {
        v = othis.Get(k - 1);
        if(v)
            othis.Put(cast(uint)(k + arglist.length - 1), *v,
                      Property.Attribute.None);
        else
            othis.Delete(cast(uint)(k + arglist.length - 1));
    }

    for(k = 0; k < arglist.length; k++)
    {
        othis.Put(k, arglist[k], Property.Attribute.None);
    }
    othis.Put(Text.length, len + arglist.length, Property.Attribute.DontEnum);
    ret.putVnumber(len + arglist.length);
    return null;
}

/* =========================== Darray_prototype =================== */

class DarrayPrototype : Darray
{
    this()
    {
        super(Dobject.getPrototype);
        Dobject f = Dfunction.getPrototype;

        Put(Text.constructor, Darray.getConstructor,
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
        length.putVnumber(0);
        ulength = 0;
        classname = Text.Array;
    }

    override DError* Put(ref Identifier key, ref Value value,
                         in Property.Attribute attributes)
    {
        auto result = proptable.put(key.value, key.value.hash, value, attributes);
        if(!result)
            Put(key.value.text, value, attributes);
        return null;
    }

    override DError* Put(in d_string name, ref Value v,
                         in Property.Attribute attributes)
    {
        d_uint32 i;
        uint c;
        Value* result;

        // ECMA 15.4.5.1
        result = proptable.put(name, v, attributes);
        if(!result)
        {
            if(name == Text.length)
            {
                i = v.toUint32();
                if(i != v.toInteger())
                {
                    return LengthIntError;
                }
                if(i < ulength)
                {
                    // delete all properties with keys >= i
                    d_uint32[] todelete;

                    foreach(Value key, ref Property p; proptable)
                    {
                        d_uint32 j;

                        j = key.toUint32();
                        if(j >= i)
                            todelete ~= j;
                    }
                    foreach(d_uint32 j; todelete)
                    {
                        proptable.del(j);
                    }
                }
                ulength = i;
                length.number = i;
                proptable.put(name, v,
                              attributes | Property.Attribute.DontEnum);
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

    override DError* Put(in d_string name, Dobject o,
                         in Property.Attribute attributes)
    {
        return Put(name, o.value, attributes);
    }

    override DError* Put(in d_string PropertyName, in d_number n,
                         in Property.Attribute attributes)
    {
        Value v;

        v.putVnumber(n);
        return Put(PropertyName, v, attributes);
    }

    override DError* Put(in d_string PropertyName, in d_string str,
                         in Property.Attribute attributes)
    {
        Value v;

        v.putVstring(str);
        return Put(PropertyName, v, attributes);
    }

    override DError* Put(in d_uint32 index, ref Value vindex, ref Value value,
                         in Property.Attribute attributes)
    {
        if(index >= ulength)
            ulength = index + 1;

        proptable.put(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/, value, attributes);
        return null;
    }

    override DError* Put(in d_uint32 index, ref Value value,
                         in Property.Attribute attributes)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        proptable.put(index, value, attributes);
        return null;
    }

    final DError* Put(d_uint32 index, d_string str,
                      Property.Attribute attributes)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        proptable.put(index, str, attributes);
        return null;
    }

    override Value* Get(ref Identifier id)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(id.value.text == Text.length)
        {
            length.number = ulength;
            return &length;
        }
        else
            return Dobject.Get(id);
    }

    override Value* Get(in d_string PropertyName, in size_t hash)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(PropertyName == Text.length)
        {
            length.number = ulength;
            return &length;
        }
        else
            return Dobject.Get(PropertyName, hash);
    }

    override Value* Get(in d_uint32 index)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        v = proptable.get(index);
        return v;
    }

    override Value* Get(in d_uint32 index, ref Value vindex)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        v = proptable.get(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/);
        return v;
    }

    override int Delete(in d_string PropertyName)
    {
        // ECMA 8.6.2.5
        //writef("Darray.Delete('%ls')\n", d_string_ptr(PropertyName));
        if(PropertyName == Text.length)
            return 0;           // can't delete 'length' property
        else
            return proptable.del(PropertyName);
    }

    override int Delete(in d_uint32 index)
    {
        // ECMA 8.6.2.5
        return proptable.del(index);
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

        _constructor.Put(Text.prototype, _prototype,
                         Property.Attribute.DontEnum |
                         Property.Attribute.ReadOnly);
    }
private:
    Dfunction _constructor;
    Dobject _prototype;
}


