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

import dmdscript.script : CallContext;
import dmdscript.value : DError, Value, vundefined;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DnativeFunctionDescriptor,
    DnativeVariableDescriptor;
import dmdscript.key : Key;

double math_helper(ref CallContext cc, Value[] arglist)
{
    Value *v;

    v = arglist.length ? &arglist[0] : &vundefined;
    return v.toNumber(cc);
}
@DnativeFunctionDescriptor(Key.abs, 1)
DError* Dmath_abs(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.1
    double result;

    result = fabs(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.acos, 1)
DError* Dmath_acos(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.2
    double result;

    result = acos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.asin, 1)
DError* Dmath_asin(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.3
    double result;

    result = asin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.atan, 1)
DError* Dmath_atan(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.4
    double result;

    result = atan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.atan2, 2)
DError* Dmath_atan2(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.5
    double n1;
    Value* v2;
    double result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = atan2(n1, v2.toNumber(cc));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.ceil, 1)
DError* Dmath_ceil(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.6
    double result;

    result = ceil(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

@DnativeFunctionDescriptor(Key.cos, 1)
DError* Dmath_cos(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.7
    double result;

    result = cos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.exp, 1)
DError* Dmath_exp(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.8
    double result;

    result = std.math.exp(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.floor, 1)
DError* Dmath_floor(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.9
    double result;

    result = std.math.floor(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.log, 1)
DError* Dmath_log(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.10
    double result;

    result = log(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.max, 2)
DError* Dmath_max(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.11
    double n;
    double result;
    uint a;

    result = -double.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber(cc);
        if(isNaN(n))
        {
            result = double.nan;
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
@DnativeFunctionDescriptor(Key.min, 2)
DError* Dmath_min(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.12
    double n;
    double result;
    uint a;

    result = double.infinity;
    foreach(Value v; arglist)
    {
        n = v.toNumber(cc);
        if(isNaN(n))
        {
            result = double.nan;
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
@DnativeFunctionDescriptor(Key.pow, 2)
DError* Dmath_pow(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.13
    double n1;
    Value *v2;
    double result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = pow(n1, v2.toNumber(cc));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.random, 0)
DError* Dmath_random(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.14
    // 0.0 <= result < 1.0
    double result;
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
@DnativeFunctionDescriptor(Key.round, 1)
DError* Dmath_round(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.15
    double result;

    result = math_helper(cc, arglist);
    if(!isNaN(result))
        result = copysign(std.math.floor(result + .5), result);
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.sin, 1)
DError* Dmath_sin(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.16
    double result;

    result = sin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.sqrt, 1)
DError* Dmath_sqrt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.17
    double result;

    result = sqrt(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DnativeFunctionDescriptor(Key.tan, 1)
DError* Dmath_tan(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.18
    double result;

    result = tan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

@DnativeVariableDescriptor(Key.E) immutable E = std.math.E;
@DnativeVariableDescriptor(Key.LN10) immutable LN10 = std.math.LN10;
@DnativeVariableDescriptor(Key.LN2) immutable LN2 = std.math.LN2;
@DnativeVariableDescriptor(Key.LOG2E) immutable LOG2E = std.math.LOG2E;
@DnativeVariableDescriptor(Key.LOG10E) immutable LOG10E = std.math.LOG10E;
@DnativeVariableDescriptor(Key.PI) immutable PI = std.math.PI;
@DnativeVariableDescriptor(Key.SQRT1_2) immutable SQRT1_2 = std.math.SQRT1_2;
@DnativeVariableDescriptor(Key.SQRT2) immutable SQRT2 = std.math.SQRT2;

/* ===================== Dmath ==================== */

class Dmath : Dobject
{
    this()
    {
        import dmdscript.property : Property;

        super(Dobject.getPrototype, Key.Math);

        //writef("Dmath::Dmath(%x)\n", this);
        enum attributes =
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly;

        // struct MathConst
        // {
        //     Key name;
        //     double  value;
        // }

        // enum MathConst[] Table =
        // [
        //     { Key.E, std.math.E },
        //     { Key.LN10, std.math.LN10 },
        //     { Key.LN2, std.math.LN2 },
        //     { Key.LOG2E, std.math.LOG2E },
        //     { Key.LOG10E, std.math.LOG10E },
        //     { Key.PI, std.math.PI },
        //     { Key.SQRT1_2, std.math.SQRT1_2 },
        //     { Key.SQRT2, std.math.SQRT2 },
        // ];

        // foreach(one; Table)
        // {
        //     DefineOwnProperty(one.name, one.value, attributes);
        // }

        DnativeVariableDescriptor.install!(mixin(__MODULE__))(this, attributes);

/*
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
//*/
        DnativeFunctionDescriptor.install!(mixin(__MODULE__))(this, attributes);
    }

static:
    void initialize()
    {
        object = new Dmath();
    }

package static:
    Dmath object;
}

