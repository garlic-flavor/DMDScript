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

import dmdscript.primitive : string_t, char_t, Key;
import dmdscript.callcontext : CallContext;
import dmdscript.dobject : Dobject;
import dmdscript.value : Value, DError, vundefined;
import dmdscript.dnative : DnativeFunction, DFD = DnativeFunctionDescriptor,
    installConstants;

debug import std.stdio;

//------------------------------------------------------------------------------
// Configuration
enum MAJOR_VERSION = 5;       /// ScriptEngineMajorVersion
enum MINOR_VERSION = 5;       /// ScriptEngineMinorVersion

enum BUILD_VERSION = 1;       /// ScriptEngineBuildVersion

enum JSCRIPT_CATCH_BUG = 1;   /// emulate Jscript's bug in scoping of
                              /// catch objects in violation of ECMA
enum JSCRIPT_ESCAPEV_BUG = 0; /// emulate Jscript's bug where \v is
                              /// not recognized as vertical tab

enum COPYRIGHT = "Copyright (c) 1999-2010 by Digital Mars"; ///
enum WRITTEN = "by Walter Bright"; ///

///
@safe pure nothrow
string banner()
{
    import std.array : join;
    return [
        "DMDSsript-2 v0.1rc1",
        "Compiled by Digital Mars DMD D compiler",
        "http://www.digitalmars.com",
        "Fork of the original DMDScript 1.16",
        WRITTEN,
        COPYRIGHT,
        ].join("\n");
}

//==============================================================================
///
class Dglobal : Dobject
{
    this(char_t[][] argv)
    {
        import dmdscript.dfunction : Dfunction;
        import dmdscript.property : Property;
        import dmdscript.darray : Darray;
        import dmdscript.dstring : Dstring;
        import dmdscript.dboolean : Dboolean;
        import dmdscript.dnumber : Dnumber;
        import dmdscript.ddate : Ddate;
        import dmdscript.dregexp : Dregexp;
        import dmdscript.derror : Derror;
        import dmdscript.protoerror;
        import dmdscript.dmath : Dmath;
        import dmdscript.primitive : PropertyKey;

        CallContext cc;

        // Dglobal.prototype is implementation-dependent
        super(Dobject.getPrototype, Key.global);

        Dobject f = Dfunction.getPrototype();

        // ECMA 15.1
        // Add in built-in objects which have attribute { DontEnum }

        // Value properties

        version (TEST262)
        {
            installConstants!(
                "NaN", double.nan,
                "Infinity", double.infinity,
                "undefined", vundefined)(this,
                                         Property.Attribute.DontEnum |
                                         Property.Attribute.DontDelete);
        }
        else
        {
            installConstants!(
                "NaN", double.nan,
                "Infinity", double.infinity,
                "undefined", vundefined)(this);
        }

        debug
        {
            auto v = Get(PropertyKey("Infinity"), cc);
            assert(!v.isUndefined);
            assert(v.toNumber(cc) is double.infinity);
        }

        DFD.install(this, Property.Attribute.DontEnum);

        // Now handled by AssertExp()
        // Put(Text.assert, Dglobal_assert(), DontEnum);

        // Constructor properties
        Value val;
        val.put(Dobject.getConstructor);
        DefineOwnProperty(Key.Object, val, Property.Attribute.DontEnum);
        val.put(Dfunction.getConstructor);
        DefineOwnProperty(Key.Function, val, Property.Attribute.DontEnum);
        val.put(Darray.getConstructor);
        DefineOwnProperty(Key.Array, val, Property.Attribute.DontEnum);
        val.put(Dstring.getConstructor);
        DefineOwnProperty(Key.String, val, Property.Attribute.DontEnum);
        val.put(Dboolean.getConstructor);
        DefineOwnProperty(Key.Boolean, val, Property.Attribute.DontEnum);
        val.put(Dnumber.getConstructor);
        DefineOwnProperty(Key.Number, val, Property.Attribute.DontEnum);
        val.put(Ddate.getConstructor);
        DefineOwnProperty(Key.Date, val, Property.Attribute.DontEnum);
        val.put(Dregexp.getConstructor);
        DefineOwnProperty(Key.RegExp, val, Property.Attribute.DontEnum);
        val.put(Derror.getConstructor);
        DefineOwnProperty(Key.Error, val, Property.Attribute.DontEnum);

        val.put(syntaxerror.getConstructor);
        DefineOwnProperty(syntaxerror.Text, val, Property.Attribute.DontEnum);
        val.put(evalerror.getConstructor);
        DefineOwnProperty(evalerror.Text, val, Property.Attribute.DontEnum);
        val.put(referenceerror.getConstructor);
        DefineOwnProperty(referenceerror.Text, val,
                          Property.Attribute.DontEnum);
        val.put(rangeerror.getConstructor);
        DefineOwnProperty(rangeerror.Text, val, Property.Attribute.DontEnum);
        val.put(typeerror.getConstructor);
        DefineOwnProperty(typeerror.Text, val, Property.Attribute.DontEnum);
        val.put(urierror.getConstructor);
        DefineOwnProperty(urierror.Text, val, Property.Attribute.DontEnum);


        // Other properties
        assert(Dmath.object);
        val.put(Dmath.object);
        DefineOwnProperty(Key.Math, val, Property.Attribute.DontEnum);

        // Build an "arguments" property out of argv[],
        // and add it to the global object.
        Darray arguments;

        arguments = new Darray();
        val.put(arguments);
        DefineOwnProperty(Key.arguments, val, Property.Attribute.DontDelete);
        arguments.length.put(argv.length);
        for(int i = 0; i < argv.length; i++)
        {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// Where is this definition?
            val.put(argv[i].idup);
            arguments.Set(PropertyKey(i), val, Property.Attribute.DontEnum, cc);
        }
        val.put(Value.Type.Null);
        arguments.DefineOwnProperty(Key.callee, val,
                                    Property.Attribute.DontEnum);
    }
}

//==============================================================================
private:

//------------------------------------------------------------------------------
@DFD(1)
DError* eval(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import core.sys.posix.stdlib : alloca;
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.exception : ScriptException;
    import dmdscript.statement : TopStatement;
    import dmdscript.parse : Parser;
    import dmdscript.scopex : Scope;
    import dmdscript.lexer : Mode;
    import dmdscript.property : Property;
    import dmdscript.opcodes : IR;
    import dmdscript.protoerror : syntaxerror;
    import dmdscript.callcontext : DefinedFunctionScope;

    // ECMA 15.1.2.1
    Value* v;
    string_t s;
    FunctionDefinition fd;
    ScriptException exception;
    DError* result;
    Dobject callerothis;
    Dobject[] scopes;

    v = arglist.length ? &arglist[0] : &undefined;
    if(v.type != Value.Type.String)
    {
        ret = *v;
        return null;
    }
    s = v.toString(cc);

    // Parse program
    TopStatement[] topstatements;
    auto p = new Parser!(Mode.None)("eval", s);
    if((exception = p.parseProgram(topstatements)) !is null)
    {

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// solve this.
    // For eval()'s, use location of caller, not the string
    // errinfo.linnum = 0;
        ret.putVundefined();
        return new DError(new syntaxerror(exception));
    }

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

    debug
    {
        import dmdscript.program : Program;
        if (cc.dumpMode & Program.DumpMode.Statement)
            TopStatement.dump(topstatements).writeln;
    }


    if(exception !is null)
    {

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// solve this.
    // For eval()'s, use location of caller, not the string
    // errinfo.linnum = 0;
        ret.putVundefined();
        return new DError(new syntaxerror(exception));
    }
    fd.toIR(null);

    debug
    {
        import dmdscript.opcodes : IR;
        if (cc.dumpMode & Program.DumpMode.IR)
            IR.toString(fd.code).writeln;
    }

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
        scopes = cc.scopes;
        assert (0 < scopes.length);
        assert (cc.callerothis);
        auto dfs = DefinedFunctionScope(scopes[0..$-1], scopes[$-1],
                                        pthis, fd, cc.callerothis);

        cc.push(dfs);
        result = IR.call(cc, cc.callerothis, fd.code, ret, locals.ptr);
        if (result !is null)
        {
            result.addTrace(null, "eval", s);
        }
        cc.pop(dfs);

        if(p1)
            delete p1;
        fd = null;

        return result;
    }

}

//------------------------------------------------------------------------------
@DFD(2)
DError* parseInt(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.utf : decode;
    import dmdscript.primitive : isStrWhiteSpaceChar;

    // ECMA 15.1.2.2
    Value* v2;
    immutable(char)* s;
    immutable(char)* z;
    int radix;
    int sign = 1;
    double number;
    size_t i;
    string_t str;

    str = arg0string(cc, arglist);

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
            number = double.nan;
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
        int n;
        char_t c;

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
        number = double.nan;
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
                number = double.nan;
                goto Lret;
            }
            z++;
        }
    }

    Lret:
    ret.put(number);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* parseFloat(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : StringNumericLiteral;

    // ECMA 15.1.2.3
    double n;
    size_t endidx;

    string_t str = arg0string(cc, arglist);
    n = StringNumericLiteral(str, endidx, 1);

    ret.put(n);
    return null;
}

//------------------------------------------------------------------------------
int ISURIALNUM(dchar c)
{
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
}

char_t[16 + 1] TOHEX = "0123456789ABCDEF";

@DFD(1)
DError* escape(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.string : indexOf;

    // ECMA 15.1.2.4
    string_t s;
    uint escapes;
    uint unicodes;
    size_t slen;

    s = arg0string(cc, arglist);
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
                r[0] = cast(char_t)c;
                r++;
            }
        }
        assert(r - R.ptr == R.length);
        ret.put(assumeUnique(R));
        return null;
    }
}

//------------------------------------------------------------------------------
@DFD(1)
DError* unescape(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.exception : assumeUnique;
    import std.traits : Unqual, ForeachType;
    import std.utf : encode;

    // ECMA 15.1.2.5
    string_t s;
    Unqual!(ForeachType!string_t)[] R; // char[] type is assumed.

    s = arg0string(cc, arglist);
    //writefln("Dglobal.unescape(s = '%s')", s);
    for(size_t k = 0; k < s.length; k++)
    {
        char_t c = s[k];

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

//------------------------------------------------------------------------------
@DFD(1)
DError* isNaN(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isNaN;

    // ECMA 15.1.2.6
    Value* v;
    double n;
    bool b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &undefined;
    n = v.toNumber(cc);
    b = isNaN(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* isFinite(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.math : isFinite;

    // ECMA 15.1.2.7
    Value* v;
    double n;
    bool b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &undefined;
    n = v.toNumber(cc);
    b = isFinite(n) ? true : false;
    ret.put(b);
    return null;
}

//------------------------------------------------------------------------------
DError* URI_error(string_t s)
{
    import dmdscript.protoerror : urierror;

    Dobject o = new urierror(s ~ "() failure");
    auto v = new DError;
    v.put(o);
    return v;
}
@DFD(1)
DError* decodeURI(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decode, URIException;
    // ECMA v3 15.1.3.1
    string_t s;

    s = arg0string(cc, arglist);
    try
    {
        s = decode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(__FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* decodeURIComponent(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : decodeComponent, URIException;
    // ECMA v3 15.1.3.2
    string_t s;

    s = arg0string(cc, arglist);
    try
    {
        s = decodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(__FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* encodeURI(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encode, URIException;

    // ECMA v3 15.1.3.3
    string_t s;

    s = arg0string(cc, arglist);
    try
    {
        s = encode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(__FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* encodeURIComponent(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.uri : encodeComponent, URIException;
    // ECMA v3 15.1.3.4
    string_t s;

    s = arg0string(cc, arglist);
    try
    {
        s = encodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(__FUNCTION__);
    }
    ret.put(s);
    return null;
}

//------------------------------------------------------------------------------
void dglobal_print(
    ref CallContext cc, Dobject othis, out Value ret, Value[] arglist)
{
    import std.stdio : writef;
    // Our own extension
    if(arglist.length)
    {
        uint i;

        for(i = 0; i < arglist.length; i++)
        {
            version (Windows) // FUUU******UUUCK!!
            {
                import dmdscript.protoerror : D0base;
                import std.windows.charset : toMBSz;

                if (arglist[i].type == Value.Type.Object)
                {
                    if (auto err = cast(D0base)arglist[i].object)
                    {
                        err.exception.toString((b){printf("%s", b.toMBSz);});
                        continue;
                    }
                }

                printf("%s", arglist[i].toString(cc).toMBSz);
            }
            else
            {
                string_t s = arglist[i].toString(cc);

                writef("%s", s);
            }
        }
    }

    ret.putVundefined();
}

//------------------------------------------------------------------------------
@DFD(1)
DError* print(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    return null;
}

//------------------------------------------------------------------------------
@DFD(1)
DError* println(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import std.stdio : writef;

    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    writef("\n");
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* readln(
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
    Unqual!(ForeachType!string_t)[] s;

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

//------------------------------------------------------------------------------
@DFD(1)
DError* getenv(
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
        string_t s = arglist[0].toString(cc);
        char* p = getenv(toStringz(s));
        if(p)
            ret.put(p[0 .. strlen(p)].idup);
        else
            ret.putVnull();
    }
    return null;
}


//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngine(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive : Text;

    ret.put(Text.DMDScript);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineBuildVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(BUILD_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineMajorVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MAJOR_VERSION);
    return null;
}

//------------------------------------------------------------------------------
@DFD(0)
DError* ScriptEngineMinorVersion(
    DnativeFunction pthis, ref CallContext cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    ret.put(MINOR_VERSION);
    return null;
}

//------------------------------------------------------------------------------

//
string_t arg0string(ref CallContext cc, Value[] arglist)
{
    Value* v = arglist.length ? &arglist[0] : &undefined;
    return v.toString(cc);
}

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// I want to remove this.
auto undefined = vundefined;
