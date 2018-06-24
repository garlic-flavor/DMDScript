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

module dmdscript.dnumber;

import std.math;

import dmdscript.primitive: number_t, PropertyKey, Text, PKey = Key;
import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dconstructor;
import dmdscript.value: Value;
import dmdscript.errmsgs;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor,
    installConstants;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;
import dmdscript.derror: Derror;

//==============================================================================
///
class Dnumber : Dobject
{
private:
    nothrow
    this(Dobject prototype, double n = 0)
    {
        super(prototype, Key.Number);
        value.put(n);
    }
}

//------------------------------------------------------------------------------
class DnumberConstructor : Dconstructor
{
    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.property : Property;

        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Number, 1);

        install(functionPrototype);
        // auto attributes =
        //     Property.Attribute.DontEnum |
        //     Property.Attribute.DontDelete |
        //     Property.Attribute.ReadOnly;

        // DefineOwnProperty(Key.MAX_VALUE, double.max, attributes);
        // DefineOwnProperty(Key.MIN_VALUE, double.min_normal*double.epsilon,
        //     attributes);
        // DefineOwnProperty(Key.NaN, double.nan, attributes);
        // DefineOwnProperty(Key.NEGATIVE_INFINITY, -double.infinity, attributes);
        // DefineOwnProperty(Key.POSITIVE_INFINITY, double.infinity, attributes);

        version (TEST262)
        {
            installConstants!(
                "EPSILON", double.epsilon,
                "MAX_SAFE_INTEGER", double.min_exp - 1,
                "MIN_SAFE_INTEGER", -double.min_exp + 1,
                "MIN_VALUE", double.min_normal * double.epsilon,
                "NEGATIVE_INFINITY", -double.infinity,
                "POSITIVE_INFINITY", double.infinity)(this);

            installConstants!(
                "NaN", double.nan)(this,
                                   Property.Attribute.DontEnum |
                                   Property.Attribute.DontDelete |
                                   Property.Attribute.SilentReadOnly);
        }
        else
        {
            installConstants!(
                "EPSILON", double.epsilon,
                "MAX_SAFE_INTEGER", double.min_exp - 1,
                "MIN_SAFE_INTEGER", -double.min_exp + 1,
                "MIN_VALUE", double.min_normal * double.epsilon,
                "NaN", double.nan,
                "NEGATIVE_INFINITY", -double.infinity,
                "POSITIVE_INFINITY", double.infinity)(this);
        }
    }

    nothrow
    Dnumber opCall(double n = 0)
    {
        return new Dnumber(classPrototype, n);
    }

    override Derror* Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        // ECMA 15.7.2
        double n;
        Dobject o;

        n = 0;
        if (0 < arglist.length)
            arglist[0].to(n, cc);
        o = opCall(n);
        ret.put(o);
        return null;
    }

    override Derror* Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // ECMA 15.7.1
        double n;

        if (0 < arglist.length)
            arglist[0].to(n, cc);
        else
            n = 0;
        ret.put(n);
        return null;
    }
}


//==============================================================================
private:

enum Key : PropertyKey
{
    Number = PKey.Number,
    valueOf = PKey.valueOf,
    toString = PKey.toString,
    prototype = PKey.prototype,
    constructor = PKey.constructor,
    toLocaleString = PKey.toLocaleString,
    NaN = PKey.NaN,

    MAX_VALUE = PropertyKey("MAX_VALUE"),
    MIN_VALUE = PropertyKey("MIN_VALUE"),
    NEGATIVE_INFINITY = PropertyKey("NEGATIVE_INFINITY"),
    POSITIVE_INFINITY = PropertyKey("POSITIVE_INFINITY"),

    toFixed = PropertyKey("toFixed"),
    toExponential = PropertyKey("toExponential"),
    toPrecision = PropertyKey("toPrecision"),

    Infinity = PropertyKey(Text.Infinity),
}

//
@DFD(1, DFD.Type.Static)
Derror* isFinite(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* isInteger(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* isNaN(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* isSafeInteger(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* parseFloat(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}

//
@DFD(1, DFD.Type.Static)
Derror* parseInt(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert (0);
}



//------------------------------------------------------------------------------
@DFD(1)
Derror* toString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.7.4.2
    string s;

    // othis must be a Number
    if (auto dn = cast(Dnumber)othis)
    {
        Value* v;

        v = &dn.value;

        if(arglist.length)
        {
            double radix;

            arglist[0].to(radix, cc);
            if(radix == 10.0 || arglist[0].isUndefined())
                v.to(s, cc);
            else
            {
                int r;

                r = cast(int)radix;
                // radix must be an integer 2..36
                if(r == radix && r >= 2 && r <= 36)
                    v.to(s, r, cc);
                else
                    v.to(s, cc);
            }
        }
        else
            v.to(s, cc);
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        return FunctionWantsNumberError(cc, Key.toString, othis.classname);
    }
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror* toLocaleString(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA v3 15.7.4.3

    // othis must be a Number
    Derror* err;
    string s;
    if (auto dn = cast(Dnumber)othis)
    {
        err = dn.value.toLocaleString(s, cc);
        ret.put(s);
    }
    else
    {
        ret.putVundefined();
        err = FunctionWantsNumberError(
            cc, Key.toLocaleString, othis.classname);
    }
    return err;
}

//------------------------------------------------------------------------------
@DFD(0)
Derror* valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // othis must be a Number
    if (auto dn = cast(Dnumber)othis)
    {
        ret = dn.value;
    }
    else
    {
        ret.putVundefined();
        return FunctionWantsNumberError(cc, Key.valueOf, othis.classname);
    }
    return null;
}

/* ===================== Formatting Support =============== */

const int FIXED_DIGITS = 20;    // ECMA says >= 20


// power of tens array, indexed by power

static double[FIXED_DIGITS + 1] tens =
[
    1, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
    1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
    1e20,
];

/*
Let e and n be integers such that
10**f <= n < 10**(f+1) and for which the exact
mathematical value of n * 10**(e-f) - x is as close
to zero as possible. If there are two such sets of
e and n, pick the e and n for which n * 10**(e-f)
 is larger.
*/

number_t deconstruct_real(double x, int f, out int pe)
{
    number_t n;
    int e;
    int i;

    e = cast(int)log10(x);
    i = e - f;
    if(i >= 0 && i < tens.length)
        // table lookup for speed & accuracy
        n = cast(number_t)(x / tens[i] + 0.5);
    else
        n = cast(number_t)(x / std.math.pow(cast(real)10.0, i) + 0.5);

    pe = e;
    return n;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror* toFixed(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.exception : assumeUnique;
    import std.string : sformat;
    import dmdscript.primitive : Text;

    // ECMA v3 15.7.4.5
    Value* v;
    double x;
    double fractionDigits;
    string result;
    int dup;

    if(arglist.length)
    {
        v = &arglist[0];
        v.toInteger(fractionDigits, cc);
    }
    else
        fractionDigits = 0;
    if(fractionDigits < 0 || fractionDigits > FIXED_DIGITS)
    {
        ret.putVundefined();
        return ValueOutOfRangeError(cc, Key.toFixed, "fractonDigits");
    }
    v = &othis.value;
    v.to(x, cc);
    if(std.math.isNaN(x))
    {
        result = Key.NaN;              // return "NaN"
    }
    else
    {
        int sign;
        char[] m;

        sign = 0;
        if(x < 0)
        {
            sign = 1;
            x = -x;
        }
        if(x >= 1.0e+21)               // exponent must be FIXED_DIGITS+1
        {
            Value vn;
            vn.put(x);
            string s;
            vn.to(s, cc);
            ret.put(s);
            return null;
        }
        else
        {
            number_t n;
            char[32 + 1] buffer;
            double tenf;
            int f;

            f = cast(int)fractionDigits;
            tenf = tens[f];             // tenf = 10**f

            // Compute n which gives |(n / tenf) - x| is the smallest
            // value. If there are two such n's, pick the larger.
            n = cast(number_t)(x * tenf + 0.5);         // round up & chop

            if(n == 0)
            {
                m = cast(char[])"0"; //TODO: try hacking this func to be clean ;)
                dup = 0;
            }
            else
            {
                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);
                dup = 1;
            }
            if(f != 0)
            {
                ptrdiff_t i;
                ptrdiff_t k;
                k = m.length;
                if(k <= f)
                {
                    char* s;
                    ptrdiff_t nzeros;

                    s = cast(char*)alloca((f + 1) * char.sizeof);
                    assert(s);
                    nzeros = f + 1 - k;
                    s[0 .. nzeros] = '0';
                    s[nzeros .. f + 1] = m[0 .. k];

                    m = s[0 .. f + 1];
                    k = f + 1;
                }

                // res = "-" + m[0 .. k-f] + "." + m[k-f .. k];
                char[] res = new char[sign + k + 1];
                if(sign)
                    res[0] = '-';
                i = k - f;
                res[sign .. sign + i] = m[0 .. i];
                res[sign + i] = '.';
                res[sign + i + 1 .. sign + k + 1] = m[i .. k];
                result = assumeUnique(res);
                goto Ldone;
                //+++ end of patch ++++
            }
        }
        if(sign)
            result = Text.dash ~ m.idup;  // TODO: remove idup somehow
        else if(dup)
            result = m.idup;
        else
            result = assumeUnique(m);
    }

    Ldone:
    ret.put(result);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror* toExponential(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.string : format, sformat;
    import dmdscript.primitive : Text;

    // ECMA v3 15.7.4.6
    Value* varg;
    Value* v;
    double x;
    double fractionDigits;
    string result;

    if(arglist.length)
    {
        varg = &arglist[0];
        varg.toInteger(fractionDigits, cc);
    }else
        fractionDigits = FIXED_DIGITS;
    v = &othis.value;
    v.to(x, cc);
    if(std.math.isNaN(x))
    {
        result = Key.NaN;              // return "NaN"
    }
    else
    {
        int sign;

        sign = 0;
        if(x < 0)
        {
            sign = 1;
            x = -x;
        }
        if(std.math.isInfinity(x))
        {
            result = sign ? Text.negInfinity : Key.Infinity;
        }
        else
        {
            int f;
            number_t n;
            int e;
            char[] m;
            int i;
            char[32 + 1] buffer;

            if(fractionDigits < 0 || fractionDigits > FIXED_DIGITS)
            {
                ret.putVundefined();
                return ValueOutOfRangeError(cc, Key.toExponential,
                                            "fractionDigits");
            }

            f = cast(int)fractionDigits;
            if(x == 0)
            {
                char* s;

                s = cast(char*)alloca((f + 1) * char.sizeof);
                assert(s);
                m = s[0 .. f + 1];
                m[0 .. f + 1] = '0';
                e = 0;
            }
            else
            {
                if(arglist.length && !varg.isUndefined())
                {
                    /* Step 12
                     * Let e and n be integers such that
                     * 10**f <= n < 10**(f+1) and for which the exact
                     * mathematical value of n * 10**(e-f) - x is as close
                     * to zero as possible. If there are two such sets of
                     * e and n, pick the e and n for which n * 10**(e-f)
                     * is larger.
                     * [Note: this is the same as Step 15 in toPrecision()
                     *  with f = p - 1]
                     */
                    n = deconstruct_real(x, f, e);
                }
                else
                {
                    /* Step 19
                     * Let e, n, and f be integers such that f >= 0,
                     * 10**f <= n < 10**(f+1), the number value for
                     * n * 10**(e-f) is x, and f is as small as possible.
                     * Note that the decimal representation of n has f+1
                     * digits, n is not divisible by 10, and the least
                     * significant digit of n is not necessarilly uniquely
                     * determined by these criteria.
                     */
                    /* Implement by trying maximum digits, and then
                     * lopping off trailing 0's.
                     */
                    f = 19;             // should use FIXED_DIGITS
                    n = deconstruct_real(x, f, e);

                    // Lop off trailing 0's
                    assert(n);
                    while((n % 10) == 0)
                    {
                        n /= 10;
                        f--;
                        assert(f >= 0);
                    }
                }
                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);
            }
            if(f)
            {
                char* s;

                // m = m[0] + "." + m[1 .. f+1];
                s = cast(char*)alloca((f + 2) * char.sizeof);
                assert(s);
                s[0] = m[0];
                s[1] = '.';
                s[2 .. f + 2] = m[1 .. f + 1];
                m = s[0 .. f + 2];
            }

            // result = sign + m + "e" + c + e;
            string c = (e >= 0) ? "+" : "";

            result = format("%s%se%s%d", sign ? "-" : "", m, c, e);
        }
    }

    ret.put(result);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
Derror* toPrecision(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import std.string : format, sformat;
    import dmdscript.drealm: undefined;
    import dmdscript.primitive : Text;

    // ECMA v3 15.7.4.7
    Value* varg;
    Value* v;
    double x;
    double precision;
    string result;

    v = &othis.value;
    v.to(x, cc);

    varg = (arglist.length == 0) ? &undefined : &arglist[0];

    if(arglist.length == 0 || varg.isUndefined())
    {
        Value vn;

        vn.put(x);
        vn.to(result, cc);
    }
    else
    {
        if(std.math.isNaN(x))
            result = Key.NaN;
        else
        {
            int sign;
            int e;
            int p;
            int i;
            char[] m;
            number_t n;
            char[32 + 1] buffer;

            sign = 0;
            if(x < 0)
            {
                sign = 1;
                x = -x;
            }

            if(std.math.isInfinity(x))
            {
                result = sign ? Text.negInfinity : Key.Infinity;
                goto Ldone;
            }

            varg.toInteger(precision, cc);
            if(precision < 1 || precision > 21)
            {
                ret.putVundefined();
                return ValueOutOfRangeError(cc, Key.toPrecision,
                                            "precision");
            }

            p = cast(int)precision;
            if(x != 0)
            {
                /* Step 15
                 * Let e and n be integers such that 10**(p-1) <= n < 10**p
                 * and for which the exact mathematical value of n * 10**(e-p+1) - x
                 * is as close to zero as possible. If there are two such sets
                 * of e and n, pick the e and n for which n * 10**(e-p+1) is larger.
                 */
                n = deconstruct_real(x, p - 1, e);

                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);

                if(e < -6 || e >= p)
                {
                    // result = sign + m[0] + "." + m[1 .. p] + "e" + c + e;
                    string c = (e >= 0) ? "+" : "";
                    result = format("%s%s.%se%s%d", (sign ? "-" : ""),
                                    m[0], m[1 .. $], c, e);
                    goto Ldone;
                }
            }
            else
            {
                // Step 12
                // m = array[p] of '0'
                char* s;
                s = cast(char*)alloca(p * char.sizeof);
                assert(s);
                m = s[0 .. p];
                m[] = '0';

                e = 0;
            }
            if(e != p - 1)
            {
                char* s;

                if(e >= 0)
                {
                    // m = m[0 .. e+1] + "." + m[e+1 .. p];

                    s = cast(char*)alloca((p + 1) * char.sizeof);
                    assert(s);
                    i = e + 1;
                    s[0 .. i] = m[0 .. i];
                    s[i] = '.';
                    s[i + 1 .. p + 1] = m[i .. p];
                    m = s[0 .. p + 1];
                }
                else
                {
                    // m = "0." + (-(e+1) occurrences of the character '0') + m;
                    int imax = 2 + - (e + 1);

                    s = cast(char*)alloca((imax + p) * char.sizeof);
                    assert(s);
                    s[0] = '0';
                    s[1] = '.';
                    s[2 .. imax] = '0';
                    s[imax .. imax + p] = m[0 .. p];
                    m = s[0 .. imax + p];
                }
            }
            if(sign)
                result = Text.dash ~ m.idup;  //TODO: remove idup somehow
            else
                result = m.idup;
        }
    }

    Ldone:
    ret.put(result);
    return null;
}

