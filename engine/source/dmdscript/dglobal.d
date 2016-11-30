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

module dmdscript.dglobal;

import dmdscript.script;
import dmdscript.protoerror;
import dmdscript.parse;
import dmdscript.text;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.statement;
import dmdscript.functiondefinition;
import dmdscript.scopex;
import dmdscript.opcodes;
import dmdscript.property;

import dmdscript.dstring;
import dmdscript.darray;
import dmdscript.dregexp;
import dmdscript.dnumber;
import dmdscript.dboolean;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.ddate;
import dmdscript.derror;
import dmdscript.dmath;

d_string arg0string(Value[] arglist)
{
    Value* v = arglist.length ? &arglist[0] : &vundefined;
    return v.toString();
}

/* ====================== Dglobal_eval ================ */

DError* Dglobal_eval(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;

    // ECMA 15.1.2.1
    Value* v;
    immutable(char)[] s;
    FunctionDefinition fd;
    ScriptException exception;
    DError* result;

    //FuncLog funclog(L"Global.eval()");

    v = arglist.length ? &arglist[0] : &vundefined;
    if(v.getType() != Value.TypeName.String)
    {
        ret = *v;
        return null;
    }
    s = v.toString();
    //writef("eval('%ls')\n", s);

    // Parse program
    TopStatement[] topstatements;
    Parser p = new Parser("eval", s, Parser.UseStringtable.No);
    if((exception = p.parseProgram(topstatements)) !is null)
        goto Lsyntaxerror;

    // Analyze, generate code
    fd = new FunctionDefinition(topstatements);
    fd.iseval = 1;
    {
        Scope sc;
        sc.ctor(fd);
        sc.src = s;
        fd.semantic(&sc);
        exception = sc.exception;
        sc.dtor();
    }
    if(exception !is null)
        goto Lsyntaxerror;
    fd.toIR(null);

    // Execute code
    Value[] locals;
    Value[] p1 = null;

    Value* v1 = null;
    static ntry = 0;

    if(fd.nlocals < 128)
        v1 = cast(Value*)alloca(fd.nlocals * Value.sizeof);
    if(v1)
        locals = v1[0 .. fd.nlocals];
    else
    {
        p1 = new Value[fd.nlocals];
        locals = p1;
    }


    version(none)
    {
        Array scopex;
        scopex.reserve(cc.scoperoot + fd.withdepth + 2);
        for(uint u = 0; u < cc.scoperoot; u++)
            scopex.push(cc.scopex.data[u]);

        Array *scopesave = cc.scopex;
        cc.scopex = &scopex;
        Dobject variablesave = cc.variable;
        cc.variable = cc.global;

        fd.instantiate(cc.variable, 0);

        // The this value is the same as the this value of the
        // calling context.
        result = IR.call(cc, othis, fd.code, ret, locals);

        delete p1;
        cc.variable = variablesave;
        cc.scopex = scopesave;
        return result;
    }
    else
    {

        // The scope chain is initialized to contain the same objects,
        // in the same order, as the calling context's scope chain.
        // This includes objects added to the calling context's
        // scope chain by WithStatement.
//    cc.scopex.reserve(fd.withdepth);

        // Variable instantiation is performed using the calling
        // context's variable object and using empty
        // property attributes
        fd.instantiate(cc, Property.Attribute.None);
        // fd.instantiate(cc.scopex, cc.variable, Property.Attribute.None);


        // The this value is the same as the this value of the
        // calling context.
        assert(cc.callerothis);
        result = IR.call(cc, cc.callerothis, fd.code, ret, locals.ptr);
        if(p1)
            delete p1;
        fd = null;
        // if (result) writef("result = '%s'\n", (cast(Value* )result).toString());
        return result;
    }

Lsyntaxerror:
    Dobject o;


//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// solve this.
    // For eval()'s, use location of caller, not the string
    // errinfo.linnum = 0;

    ret.putVundefined();
    o = new syntaxerror.D0(exception);
    auto v2 = new DError;
    v2.put(o);
    return v2;
}

/* ====================== Dglobal_parseInt ================ */

DError* Dglobal_parseInt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode;

    // ECMA 15.1.2.2
    Value* v2;
    immutable(char)* s;
    immutable(char)* z;
    d_int32 radix;
    int sign = 1;
    d_number number;
    size_t i;
    d_string str;

    str = arg0string(arglist);

    //writefln("Dglobal_parseInt('%s')", string);

    while(i < str.length)
    {
        size_t idx = i;
        dchar c = decode(str, idx);
        if(!isStrWhiteSpaceChar(c))
            break;
        i = idx;
    }
    s = str.ptr + i;
    i = str.length - i;

    if(i)
    {
        if(*s == '-')
        {
            sign = -1;
            s++;
            i--;
        }
        else if(*s == '+')
        {
            s++;
            i--;
        }
    }

    radix = 0;
    if(arglist.length >= 2)
    {
        v2 = &arglist[1];
        radix = v2.toInt32(cc);
    }

    if(radix)
    {
        if(radix < 2 || radix > 36)
        {
            number = d_number.nan;
            goto Lret;
        }
        if(radix == 16 && i >= 2 && *s == '0' &&
           (s[1] == 'x' || s[1] == 'X'))
        {
            s += 2;
            i -= 2;
        }
    }
    else if(i >= 1 && *s != '0')
    {
        radix = 10;
    }
    else if(i >= 2 && (s[1] == 'x' || s[1] == 'X'))
    {
        radix = 16;
        s += 2;
        i -= 2;
    }
    else
        radix = 8;

    number = 0;
    for(z = s; i; z++, i--)
    {
        d_int32 n;
        tchar c;

        c = *z;
        if('0' <= c && c <= '9')
            n = c - '0';
        else if('A' <= c && c <= 'Z')
            n = c - 'A' + 10;
        else if('a' <= c && c <= 'z')
            n = c - 'a' + 10;
        else
            break;
        if(radix <= n)
            break;
        number = number * radix + n;
    }
    if(z == s)
    {
        number = d_number.nan;
        goto Lret;
    }
    if(sign < 0)
        number = -number;

    version(none)     // ECMA says to silently ignore trailing characters
    {
        while(z - &str[0] < str.length)
        {
            if(!isStrWhiteSpaceChar(*z))
            {
                number = d_number.nan;
                goto Lret;
            }
            z++;
        }
    }

    Lret:
    ret.put(number);
    return null;
}

/* ====================== Dglobal_parseFloat ================ */

DError* Dglobal_parseFloat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // ECMA 15.1.2.3
    d_number n;
    size_t endidx;

    d_string str = arg0string(arglist);
    n = StringNumericLiteral(str, endidx, 1);

    ret.put(n);
    return null;
}

/* ====================== Dglobal_escape ================ */

int ISURIALNUM(dchar c)
{
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
}

tchar[16 + 1] TOHEX = "0123456789ABCDEF";

DError* Dglobal_escape(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.string : indexOf;

    // ECMA 15.1.2.4
    d_string s;
    uint escapes;
    uint unicodes;
    size_t slen;

    s = arg0string(arglist);
    escapes = 0;
    unicodes = 0;
    foreach(dchar c; s)
    {
        slen++;
        if(c >= 0x100)
            unicodes++;
        else
        if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            escapes++;
    }
    if((escapes + unicodes) == 0)
    {
        ret.put(assumeUnique(s));
        return null;
    }
    else
    {
        //writefln("s.length = %d, escapes = %d, unicodes = %d", s.length, escapes, unicodes);
        char[] R = new char[slen + escapes * 2 + unicodes * 5];
        char* r = R.ptr;
        foreach(dchar c; s)
        {
            if(c >= 0x100)
            {
                r[0] = '%';
                r[1] = 'u';
                r[2] = TOHEX[(c >> 12) & 15];
                r[3] = TOHEX[(c >> 8) & 15];
                r[4] = TOHEX[(c >> 4) & 15];
                r[5] = TOHEX[c & 15];
                r += 6;
            }
            else if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            {
                r[0] = '%';
                r[1] = TOHEX[c >> 4];
                r[2] = TOHEX[c & 15];
                r += 3;
            }
            else
            {
                r[0] = cast(tchar)c;
                r++;
            }
        }
        assert(r - R.ptr == R.length);
        ret.put(assumeUnique(R));
        return null;
    }
}

/* ====================== Dglobal_unescape ================ */

DError* Dglobal_unescape(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.utf : encode;

    // ECMA 15.1.2.5
    d_string s;
    Unqual!(ForeachType!d_string)[] R; // char[] type is assumed.

    s = arg0string(arglist);
    //writefln("Dglobal.unescape(s = '%s')", s);
    for(size_t k = 0; k < s.length; k++)
    {
        tchar c = s[k];

        if(c == '%')
        {
            if(k + 6 <= s.length && s[k + 1] == 'u')
            {
                uint u;

                u = 0;
                for(int i = 2;; i++)
                {
                    uint x;

                    if(i == 6)
                    {
                        encode(R, cast(dchar)u);
                        k += 5;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
            else if(k + 3 <= s.length)
            {
                uint u;

                u = 0;
                for(int i = 1;; i++)
                {
                    uint x;

                    if(i == 3)
                    {
                        encode(R, cast(dchar)u);
                        k += 2;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
        }
        R ~= c;
        L1:
        ;
    }

    ret.put(R.assumeUnique);
    return null;
}

/* ====================== Dglobal_isNaN ================ */

DError* Dglobal_isNaN(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isNaN;

    // ECMA 15.1.2.6
    Value* v;
    d_number n;
    d_boolean b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &vundefined;
    n = v.toNumber(cc);
    b = isNaN(n) ? true : false;
    ret.put(b);
    return null;
}

/* ====================== Dglobal_isFinite ================ */

DError* Dglobal_isFinite(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isFinite;

    // ECMA 15.1.2.7
    Value* v;
    d_number n;
    d_boolean b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &vundefined;
    n = v.toNumber(cc);
    b = isFinite(n) ? true : false;
    ret.put(b);
    return null;
}

/* ====================== Dglobal_ URI Functions ================ */

DError* URI_error(d_string s)
{
    Dobject o = new urierror.D0(s ~ "() failure");
    auto v = new DError;
    v.put(o);
    return v;
}

DError* Dglobal_decodeURI(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decode, URIException;
    // ECMA v3 15.1.3.1
    d_string s;

    s = arg0string(arglist);
    try
    {
        s = decode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(Text.decodeURI);
    }
    ret.put(s);
    return null;
}

DError* Dglobal_decodeURIComponent(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decodeComponent, URIException;
    // ECMA v3 15.1.3.2
    d_string s;

    s = arg0string(arglist);
    try
    {
        s = decodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(Text.decodeURIComponent);
    }
    ret.put(s);
    return null;
}

DError* Dglobal_encodeURI(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encode, URIException;

    // ECMA v3 15.1.3.3
    d_string s;

    s = arg0string(arglist);
    try
    {
        s = encode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(Text.encodeURI);
    }
    ret.put(s);
    return null;
}

DError* Dglobal_encodeURIComponent(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encodeComponent, URIException;
    // ECMA v3 15.1.3.4
    d_string s;

    s = arg0string(arglist);
    try
    {
        s = encodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(Text.encodeURIComponent);
    }
    ret.put(s);
    return null;
}

/* ====================== Dglobal_print ================ */

static void dglobal_print(
    ref CallContext cc, Dobject othis, out Value ret, Value[] arglist)
{
    import std.stdio : writef;
    // Our own extension
    if(arglist.length)
    {
        uint i;

        for(i = 0; i < arglist.length; i++)
        {
            d_string s = arglist[i].toString();

            writef("%s", s);
        }
    }

    ret.putVundefined();
}

DError* Dglobal_print(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    return null;
}

/* ====================== Dglobal_println ================ */

DError* Dglobal_println(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.stdio : writef;

    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    writef("\n");
    return null;
}

/* ====================== Dglobal_readln ================ */

DError* Dglobal_readln(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.stdio : EOF;
    import std.utf : encode;
    import core.stdc.stdio : getchar;

    // Our own extension
    dchar c;
    Unqual!(ForeachType!d_string)[] s;

    for(;; )
    {
        version(linux)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(Windows)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(OSX)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else version(FreeBSD)
        {
            c = getchar();
            if(c == EOF)
                break;
        }
        else
        {
            static assert(0);
        }
        if(c == '\n')
            break;
        encode(s, c);
    }
    ret.put(s.assumeUnique);
    return null;
}

/* ====================== Dglobal_getenv ================ */

DError* Dglobal_getenv(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.string : toStringz;
    import core.sys.posix.stdlib : getenv;
    import core.stdc.string : strlen;

    // Our own extension
    ret.putVundefined();
    if(arglist.length)
    {
        d_string s = arglist[0].toString();
        char* p = getenv(toStringz(s));
        if(p)
            ret.put(p[0 .. strlen(p)].idup);
        else
            ret.putVnull();
    }
    return null;
}


/* ====================== Dglobal_ScriptEngine ================ */

DError* Dglobal_ScriptEngine(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(Text.DMDScript);
    return null;
}

DError* Dglobal_ScriptEngineBuildVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(BUILD_VERSION);
    return null;
}

DError* Dglobal_ScriptEngineMajorVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MAJOR_VERSION);
    return null;
}

DError* Dglobal_ScriptEngineMinorVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MINOR_VERSION);
    return null;
}

/* ====================== Dglobal =========================== */

class Dglobal : Dobject
{
    this(tchar[][] argv)
    {
        super(Dobject.getPrototype());  // Dglobal.prototype is implementation-dependent

        //writef("Dglobal.Dglobal(%x)\n", this);

        Dobject f = Dfunction.getPrototype();

        classname = Text.global;

        // ECMA 15.1
        // Add in built-in objects which have attribute { DontEnum }

        // Value properties

        DefineOwnProperty(Text.NaN, d_number.nan,
               Property.Attribute.DontEnum |
               Property.Attribute.DontDelete);
        DefineOwnProperty(Text.Infinity, d_number.infinity,
               Property.Attribute.DontEnum |
               Property.Attribute.DontDelete);
        DefineOwnProperty(Text.undefined, vundefined,
               Property.Attribute.DontEnum |
               Property.Attribute.DontDelete);
        static enum NativeFunctionData[] nfd =
        [
            // Function properties
            { Text.eval, &Dglobal_eval, 1 },
            { Text.parseInt, &Dglobal_parseInt, 2 },
            { Text.parseFloat, &Dglobal_parseFloat, 1 },
            { Text.escape, &Dglobal_escape, 1 },
            { Text.unescape, &Dglobal_unescape, 1 },
            { Text.isNaN, &Dglobal_isNaN, 1 },
            { Text.isFinite, &Dglobal_isFinite, 1 },
            { Text.decodeURI, &Dglobal_decodeURI, 1 },
            { Text.decodeURIComponent, &Dglobal_decodeURIComponent, 1 },
            { Text.encodeURI, &Dglobal_encodeURI, 1 },
            { Text.encodeURIComponent, &Dglobal_encodeURIComponent, 1 },

            // Dscript unique function properties
            { Text.print, &Dglobal_print, 1 },
            { Text.println, &Dglobal_println, 1 },
            { Text.readln, &Dglobal_readln, 0 },
            { Text.getenv, &Dglobal_getenv, 1 },

            // Jscript compatible extensions
            { Text.ScriptEngine, &Dglobal_ScriptEngine, 0 },
            { Text.ScriptEngineBuildVersion, &Dglobal_ScriptEngineBuildVersion, 0 },
            { Text.ScriptEngineMajorVersion, &Dglobal_ScriptEngineMajorVersion, 0 },
            { Text.ScriptEngineMinorVersion, &Dglobal_ScriptEngineMinorVersion, 0 },
        ];

        DnativeFunction.initialize(this, nfd, Property.Attribute.DontEnum);

        // Now handled by AssertExp()
        // Put(Text.assert, Dglobal_assert(), DontEnum);

        // Constructor properties

        DefineOwnProperty(Text.Object, Dobject.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Function, Dfunction.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Array, Darray.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.String, Dstring.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Boolean, Dboolean.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Number, Dnumber.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Date, Ddate.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.RegExp, Dregexp.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(Text.Error, Derror.getConstructor,
            Property.Attribute.DontEnum);

        DefineOwnProperty(syntaxerror.Text, syntaxerror.D0.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(evalerror.Text, evalerror.D0.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(referenceerror.Text, referenceerror.D0.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(rangeerror.Text, rangeerror.D0.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(typeerror.Text, typeerror.D0.getConstructor,
            Property.Attribute.DontEnum);
        DefineOwnProperty(urierror.Text, urierror.D0.getConstructor,
            Property.Attribute.DontEnum);


        // Other properties

        assert(Dmath.object);
        DefineOwnProperty(Text.Math, Dmath.object, Property.Attribute.DontEnum);

        // Build an "arguments" property out of argv[],
        // and add it to the global object.
        Darray arguments;

        arguments = new Darray();
        DefineOwnProperty(Text.arguments, arguments, Property.Attribute.DontDelete);
        arguments.length.put(argv.length);
        CallContext cc;
        for(int i = 0; i < argv.length; i++)
        {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// Where is this definition?
            arguments.Set(i, argv[i].idup, Property.Attribute.DontEnum, cc);
        }
        arguments.DefineOwnProperty(Text.callee, vnull, Property.Attribute.DontEnum);
    }
}

