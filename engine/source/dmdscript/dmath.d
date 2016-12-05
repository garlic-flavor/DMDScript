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

module dmdscript.dmath;

import std.math;
import std.random;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.dnative;
import dmdscript.text;
import dmdscript.property;

d_number math_helper(ref CallContext cc, Value[] arglist)
{
    Value *v;

    v = arglist.length ? &arglist[0] : &vundefined;
    return v.toNumber(cc);
}

DError* Dmath_abs(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.1
    d_number result;

    result = fabs(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_acos(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.2
    d_number result;

    result = acos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_asin(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.3
    d_number result;

    result = asin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_atan(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.4
    d_number result;

    result = atan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_atan2(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.5
    d_number n1;
    Value* v2;
    d_number result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = atan2(n1, v2.toNumber(cc));
    ret.put(result);
    return null;
}

DError* Dmath_ceil(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.6
    d_number result;

    result = ceil(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_cos(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.7
    d_number result;

    result = cos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_exp(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.8
    d_number result;

    result = std.math.exp(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_floor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.9
    d_number result;

    result = std.math.floor(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_log(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.10
    d_number result;

    result = log(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_max(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.11
    d_number n;
    d_number result;
    uint a;

    result = -d_number.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber(cc);
        if(isNaN(n))
        {
            result = d_number.nan;
            break;
        }
        if(result == n)
        {
            // if n is +0 and result is -0, pick n
            if(n == 0 && !signbit(n))
                result = n;
        }
        else if(n > result)
            result = n;
    }
    ret.put(result);
    return null;
}

DError* Dmath_min(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.12
    d_number n;
    d_number result;
    uint a;

    result = d_number.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber(cc);
        if(isNaN(n))
        {
            result = d_number.nan;
            break;
        }
        if(result == n)
        {
            // if n is -0 and result is +0, pick n
            if(n == 0 && signbit(n))
                result = n;
        }
        else if(n < result)
            result = n;
    }
    ret.put(result);
    return null;
}

DError* Dmath_pow(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.13
    d_number n1;
    Value *v2;
    d_number result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = pow(n1, v2.toNumber(cc));
    ret.put(result);
    return null;
}

DError* Dmath_random(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.14
    // 0.0 <= result < 1.0
    d_number result;
    //+++ old random +++
    version(none)
    {
        ulong x;

        // Only want 53 bits of precision
        x = (cast(ulong)std.random.rand() << 32) + std.random.rand();
        //PRINTF("x = x%016llx\n",x);
        x &= 0xFFFFFFFFFFFFF800L;
        result = x * (1 / (0x100000000L * cast(double)0x100000000L))
                 + (1 / (0x200000000L * cast(double)0x100000000L));

        // Experiments on linux show that this will never be exactly
        // 1.0, so is the assert() worth it?
        assert(result >= 0 && result < 1.0);
    }
    //+++ patched random +++
    result = std.random.uniform(0.0, 1.0);
    assert(result >= 0 && result < 1.0);
    ret.put(result);
    return null;
}

DError* Dmath_round(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.15
    d_number result;

    result = math_helper(cc, arglist);
    if(!isNaN(result))
        result = copysign(std.math.floor(result + .5), result);
    ret.put(result);
    return null;
}

DError* Dmath_sin(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.16
    d_number result;

    result = sin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_sqrt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.17
    d_number result;

    result = sqrt(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

DError* Dmath_tan(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.18
    d_number result;

    result = tan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

/* ===================== Dmath ==================== */

class Dmath : Dobject
{
    this()
    {
        super(Dobject.getPrototype, Key.Math);

        //writef("Dmath::Dmath(%x)\n", this);
        auto attributes =
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly;

        struct MathConst
        {
            StringKey name;
            d_number  value;
        }

        static enum MathConst[] table =
        [
            { Key.E, std.math.E },
            { Key.LN10, std.math.LN10 },
            { Key.LN2, std.math.LN2 },
            { Key.LOG2E, std.math.LOG2E },
            { Key.LOG10E, std.math.LOG10E },
            { Key.PI, std.math.PI },
            { Key.SQRT1_2, std.math.SQRT1_2 },
            { Key.SQRT2, std.math.SQRT2 },
        ];

        for(size_t u = 0; u < table.length; u++)
        {
            // DError* v;

            /*v =*/ DefineOwnProperty(table[u].name, table[u].value, attributes);
            //writef("Put(%s,%.5g) = %x\n", *table[u].name, table[u].value, v);
        }

        static enum NativeFunctionData[] nfd =
        [
            { Key.abs, &Dmath_abs, 1 },
            { Key.acos, &Dmath_acos, 1 },
            { Key.asin, &Dmath_asin, 1 },
            { Key.atan, &Dmath_atan, 1 },
            { Key.atan2, &Dmath_atan2, 2 },
            { Key.ceil, &Dmath_ceil, 1 },
            { Key.cos, &Dmath_cos, 1 },
            { Key.exp, &Dmath_exp, 1 },
            { Key.floor, &Dmath_floor, 1 },
            { Key.log, &Dmath_log, 1 },
            { Key.max, &Dmath_max, 2 },
            { Key.min, &Dmath_min, 2 },
            { Key.pow, &Dmath_pow, 2 },
            { Key.random, &Dmath_random, 0 },
            { Key.round, &Dmath_round, 1 },
            { Key.sin, &Dmath_sin, 1 },
            { Key.sqrt, &Dmath_sqrt, 1 },
            { Key.tan, &Dmath_tan, 1 },
        ];

        DnativeFunction.initialize(this, nfd, attributes);
    }

static:
    void initialize()
    {
        object = new Dmath();
    }

package:
    Dmath object;
}

