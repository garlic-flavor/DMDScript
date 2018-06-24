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

import dmdscript.value : Value, vundefined;
import dmdscript.dobject : Dobject;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor,
    installConstants;
import dmdscript.primitive : Key;
import dmdscript.drealm : undefined, Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;

double math_helper(CallContext* cc, Value[] arglist)
{
    Value *v;

    v = arglist.length ? &arglist[0] : &undefined;
    double n;
    v.to(n, cc);
    return n;
}
@DFD(1)
Derror* abs(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.1
    double result;

    result = fabs(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* acos(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.2
    double result;

    result = std.math.acos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* asin(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.3
    double result;

    result = std.math.asin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* atan(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.4
    double result;

    result = std.math.atan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(2)
Derror* atan2(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.5
    double n1, n2;
    Value* v2;
    double result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &undefined;
    v2.to(n2, cc);
    result = std.math.atan2(n1, n2);
    ret.put(result);
    return null;
}
@DFD(1)
Derror* ceil(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.6
    double result;

    result = std.math.ceil(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

@DFD(1)
Derror* cos(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.7
    double result;

    result = std.math.cos(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* exp(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.8
    double result;

    result = std.math.exp(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* floor(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.9
    double result;

    result = std.math.floor(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* log(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.10
    double result;

    result = std.math.log(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(2)
Derror* max(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.11
    double n;
    double result;
    uint a;

    result = -double.infinity;
    foreach(Value v; arglist)
    {
        v.to(n, cc);
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
@DFD(2)
Derror* min(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.8.2.12
    double n;
    double result;
    uint a;

    result = double.infinity;
    foreach(Value v; arglist)
    {
        v.to(n, cc);
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
@DFD(2)
Derror* pow(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.13
    double n1, n2;
    Value *v2;
    double result;

    n1 = math_helper(cc, arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &undefined;
    v2.to(n2, cc);
    result = std.math.pow(n1, n2);
    ret.put(result);
    return null;
}
@DFD(0)
Derror* random(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
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
@DFD(1)
Derror* round(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
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
@DFD(1)
Derror* sin(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.16
    double result;

    result = std.math.sin(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* sqrt(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.17
    double result;

    result = std.math.sqrt(math_helper(cc, arglist));
    ret.put(result);
    return null;
}
@DFD(1)
Derror* tan(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.8.2.18
    double result;

    result = std.math.tan(math_helper(cc, arglist));
    ret.put(result);
    return null;
}

//
@DFD(1)
Derror* cbrt(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* clz32(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* cosh(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* expm1(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* fround(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* hypot(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(2)
Derror* imul(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* log1p(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* log10(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* log2(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* sign(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* sinh(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* tanh(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1)
Derror* trunc(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

/* ===================== Dmath ==================== */

class Dmath : Dobject
{
    this(Dobject rootPrototype, Dobject functionPrototype)
    {
        import dmdscript.property: Property;
        import dmdscript.dnative: install;

        super(rootPrototype, Key.Math);

        enum attributes =
            Property.Attribute.DontEnum |
            Property.Attribute.DontDelete |
            Property.Attribute.ReadOnly;

        installConstants!(
            "E", std.math.E,
            "LN10", std.math.LN10,
            "LN2", std.math.LN2,
            "LOG2E", std.math.LOG2E,
            "LOG10E", std.math.LOG10E,
            "PI", std.math.PI,
            "SQRT1_2", std.math.SQRT1_2,
            "SQRT2", std.math.SQRT2)
            (this, Property.Attribute.DontEnum |
                   Property.Attribute.DontDelete |
                   Property.Attribute.SilentReadOnly);

        install!(dmdscript.dmath)(this, functionPrototype, attributes);
    }
}

