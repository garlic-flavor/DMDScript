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

d_number math_helper(Value[] arglist)
{
    Value *v;

    v = arglist.length ? &arglist[0] : &vundefined;
    return v.toNumber();
}

DError* Dmath_abs(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.1
    d_number result;

    result = fabs(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_acos(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.2
    d_number result;

    result = acos(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_asin(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.3
    d_number result;

    result = asin(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_atan(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.4
    d_number result;

    result = atan(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_atan2(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.5
    d_number n1;
    Value* v2;
    d_number result;

    n1 = math_helper(arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = atan2(n1, v2.toNumber());
    ret.putVnumber(result);
    return null;
}

DError* Dmath_ceil(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.6
    d_number result;

    result = ceil(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_cos(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.7
    d_number result;

    result = cos(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_exp(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.8
    d_number result;

    result = std.math.exp(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_floor(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.9
    d_number result;

    result = std.math.floor(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_log(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.10
    d_number result;

    result = log(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_max(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.8.2.11
    d_number n;
    d_number result;
    uint a;

    result = -d_number.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber();
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
    ret.putVnumber(result);
    return null;
}

DError* Dmath_min(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.8.2.12
    d_number n;
    d_number result;
    uint a;

    result = d_number.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber();
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
    ret.putVnumber(result);
    return null;
}

DError* Dmath_pow(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.13
    d_number n1;
    Value *v2;
    d_number result;

    n1 = math_helper(arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = pow(n1, v2.toNumber());
    ret.putVnumber(result);
    return null;
}

DError* Dmath_random(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
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
    ret.putVnumber(result);
    return null;
}

DError* Dmath_round(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.15
    d_number result;

    result = math_helper(arglist);
    if(!isNaN(result))
        result = copysign(std.math.floor(result + .5), result);
    ret.putVnumber(result);
    return null;
}

DError* Dmath_sin(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.16
    d_number result;

    result = sin(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_sqrt(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.17
    d_number result;

    result = sqrt(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

DError* Dmath_tan(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.18
    d_number result;

    result = tan(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

/* ===================== Dmath ==================== */

class Dmath : Dobject
{
    this()
    {
        super(Dobject.getPrototype);

        //writef("Dmath::Dmath(%x)\n", this);
        auto attributes =
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly;

        struct MathConst
        { d_string name;
          d_number  value; }

        static enum MathConst[] table =
        [
            { Text.E, std.math.E },
            { Text.LN10, std.math.LN10 },
            { Text.LN2, std.math.LN2 },
            { Text.LOG2E, std.math.LOG2E },
            { Text.LOG10E, std.math.LOG10E },
            { Text.PI, std.math.PI },
            { Text.SQRT1_2, std.math.SQRT1_2 },
            { Text.SQRT2, std.math.SQRT2 },
        ];

        for(size_t u = 0; u < table.length; u++)
        {
            DError* v;

            v = Put(table[u].name, table[u].value, attributes);
            //writef("Put(%s,%.5g) = %x\n", *table[u].name, table[u].value, v);
        }

        classname = Text.Math;

        static enum NativeFunctionData[] nfd =
        [
            { Text.abs, &Dmath_abs, 1 },
            { Text.acos, &Dmath_acos, 1 },
            { Text.asin, &Dmath_asin, 1 },
            { Text.atan, &Dmath_atan, 1 },
            { Text.atan2, &Dmath_atan2, 2 },
            { Text.ceil, &Dmath_ceil, 1 },
            { Text.cos, &Dmath_cos, 1 },
            { Text.exp, &Dmath_exp, 1 },
            { Text.floor, &Dmath_floor, 1 },
            { Text.log, &Dmath_log, 1 },
            { Text.max, &Dmath_max, 2 },
            { Text.min, &Dmath_min, 2 },
            { Text.pow, &Dmath_pow, 2 },
            { Text.random, &Dmath_random, 0 },
            { Text.round, &Dmath_round, 1 },
            { Text.sin, &Dmath_sin, 1 },
            { Text.sqrt, &Dmath_sqrt, 1 },
            { Text.tan, &Dmath_tan, 1 },
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

