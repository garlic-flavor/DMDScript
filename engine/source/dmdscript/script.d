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

module dmdscript.script;

import dmdscript.value;
import dmdscript.dobject;
import dmdscript.program;
import dmdscript.text;
import dmdscript.functiondefinition;

debug import std.stdio;
/* =================== Configuration ======================= */

enum uint MAJOR_VERSION = 5;       // ScriptEngineMajorVersion
enum uint MINOR_VERSION = 5;       // ScriptEngineMinorVersion

enum uint BUILD_VERSION = 1;       // ScriptEngineBuildVersion

enum uint JSCRIPT_CATCH_BUG = 1;   // emulate Jscript's bug in scoping of
                                   // catch objects in violation of ECMA
enum uint JSCRIPT_ESCAPEV_BUG = 0; // emulate Jscript's bug where \v is
                                   // not recognized as vertical tab

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

alias char tchar;

alias ulong number_t;
alias double real_t;

alias uint Loc;                 // file location (line number)

// Aliases for script primitive types
alias uint d_boolean;
alias double d_number;
alias int d_int32;
alias uint d_uint32;
alias ushort d_uint16;
alias immutable(tchar)[] d_string;
alias d_time = long;
enum d_time_nan = long.min;

int logflag;    // used for debugging

//
class ScriptException : Exception
{
    int code; // for what?

    @nogc @safe pure nothrow
    this(d_string msg, d_string file = __FILE__, size_t line = __LINE__)
    { super(msg, file, line); }

    @safe pure
    this(d_string message, d_string sourcename, d_string source,
         immutable(tchar)* pos, string file = __FILE__, size_t line = __LINE__)
    { super(message, file, line); addSource(sourcename, source, pos); }

    @safe pure
    this(d_string message, d_string sourcename, d_string source,
         Loc loc, string file = __FILE__, size_t line = __LINE__)
    { super(message, file, line); addSource(sourcename, source, loc); }

    @safe pure
    this(d_string msg, Loc loc, string file = __FILE__, size_t line = __LINE__)
    { super(msg, file, line); addSource(loc); }


    @safe pure
    void addSource(d_string sourcename, d_string source, Loc loc)
    { trance ~= SourceDescriptor(sourcename, source, loc); }

    @safe pure
    void addSource(d_string sourcename, d_string source,
                   immutable(tchar)* pos)
    { trance ~= SourceDescriptor(sourcename, source, pos); }

    void addSource(d_string sourcename, d_string source)
    { foreach (ref one; trance) one.addSource(sourcename, source); }

    override void toString(scope void delegate(in char[]) sink) const
    {
        debug
        {
            char[20] tmpBuff = void;

            sink(typeid(this).name);
            sink("@"); sink(file);
            sink("("); sink(sizeToTempString(line, tmpBuff, 10)); sink(")");

            if (0 < msg.length)
                sink(": ");
            else
                sink("\n");
        }

        if (0 < msg.length)
        { sink(msg); sink("\n"); }

        try
        {
            foreach (one; trance)
                one.toString(sink);
        }
        catch (Throwable){}

        debug
        {
            if (info)
            {
                try
                {
                    sink("\n--------------------");
                    foreach (t; info)
                    { sink("\n"); sink(t); }
                }
                catch (Throwable){}
            }
        }
    }
    alias toString = super.toString;

private:
    import core.internal.traits : externDFunc;
    alias sizeToTempString = externDFunc!(
        "core.internal.string.unsignedToTempString",
        char[] function(ulong, char[], uint) @safe pure nothrow @nogc);

    struct SourceDescriptor
    {
        d_string name;
        d_string buf;
        immutable(tchar)* pos; // pos is in buf.
        Loc linnum; // source line number (1 based, 0 if not available)

        @trusted @nogc pure nothrow
        this(d_string name, d_string buf, immutable(tchar)* pos)
        {
            this.name = name;
            this.buf = buf;
            this.pos = pos;

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }

        @safe @nogc pure nothrow
        this(d_string name, d_string buf, Loc linnum)
        {
            this.name = name;
            this.buf = buf;
            this.linnum = linnum;
        }

        @safe @nogc pure nothrow
        this(Loc linnum)
        { this.linnum = linnum; }

        @trusted @nogc pure nothrow
        void addSource(d_string name, d_string buf)
        {
            if (this.name.length == 0 && this.buf.length == 0)
            {
                this.name = name;
                this.buf = buf;
            }

            assert (buf.length == 0 || pos is null ||
                    (buf.ptr <= pos && pos < buf.ptr + buf.length));
        }

        void toString(scope void delegate(in char[]) sink) const
        {
             import std.conv : to;
             import std.array : replace;
             import std.range : repeat, take;

             char[2] tmpBuff = void;
             string srcline;
             int charpos = -1;
             Loc linnum = this.linnum;
             enum Tab = "    ";

             if (0 < buf.length)
             {
                 if      (pos !is null)
                     srcline = buf.getLineAt(pos, linnum, charpos);
                 else if (0 < linnum)
                     srcline = buf.getLineAt(linnum);
             }

             if (0 < name.length && 0 < linnum)
             {
                 sink(name);
                 sink("(");
                 sink(sizeToTempString(linnum, tmpBuff, 10));
                 sink(")");
             }

             if (0 < srcline.length)
             {
                 size_t col = 0;
                 for (size_t i = 0; i < srcline.length && i < charpos; ++i)
                 {
                     if (srcline[i] == '\t') col += Tab.length;
                     else ++col;
                 }

                 sink("\n"); sink(srcline.replace("\t", Tab).to!string);

                 if (0 <= charpos)
                 {
                     sink("\n");
                     sink(' '.repeat.take(col).to!string);
                     sink("^");
                 }
             }
        }

    }
    SourceDescriptor[] trance;
}

//
struct CallContext
{
    Dobject[] scopex; // current scope chain
    Dobject            variable;         // object for variable instantiation
    Dobject            global;           // global object
    uint               scoperoot;        // number of entries in scope[] starting from 0
                                         // to copy onto new scopes
    uint               globalroot;       // number of entries in scope[] starting from 0
                                         // that are in the "global" context. Always <= scoperoot
    void*              lastnamedfunc;    // points to the last named function added as an event
    Program            prog;
    Dobject            callerothis;      // caller's othis
    Dobject            caller;           // caller function object
    FunctionDefinition callerf;

    Status value;                // place to store exception; must be same size as Value
    uint               linnum;     // source line number of exception (1 based, 0 if not available)

    int                Interrupt;  // !=0 if cancelled due to interrupt
}

struct Global
{
    string copyright = "Copyright (c) 1999-2010 by Digital Mars";
    string written = "by Walter Bright";
}

Global global;

string banner()
{
    import std.conv : text;
    return text(
               "DMDSsript-2 v0.1rc1\n",
               "Compiled by Digital Mars DMD D compiler\n",
               "http://www.digitalmars.com\n",
               "Fork of the original DMDScript 1.16\n",
               global.written,"\n",
               global.copyright
               );
}

int isStrWhiteSpaceChar(dchar c)
{
    switch(c)
    {
    case ' ':
    case '\t':
    case 0xA0:          // <NBSP>
    case '\f':
    case '\v':
    case '\r':
    case '\n':
    case 0x2028:        // <LS>
    case 0x2029:        // <PS>
    case 0x2001:        // <USP>
    case 0x2000:        // should we do this one?
        return 1;

    default:
        break;
    }
    return 0;
}


/************************
 * Convert d_string to an index, if it is one.
 * Returns:
 *	true	it's an index, and *index is set
 *	false	it's not an index
 */
@safe @nogc pure nothrow
int StringToIndex(d_string name, out d_uint32 index)
{
    if(name.length)
    {
        d_uint32 i = 0;

        for(uint j = 0; j < name.length; j++)
        {
            tchar c = name[j];

            switch(c)
            {
            case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
                if((i == 0 && j) ||             // if leading zeros
                   i >= 0xFFFFFFFF / 10)        // or overflow
                    goto Lnotindex;
                i = i * 10 + c - '0';
                break;

            default:
                goto Lnotindex;
            }
        }
        index = i;
        return true;
    }

    Lnotindex:
    return false;
}


/********************************
 * Parse string numeric literal into a number.
 * Input:
 *	parsefloat	0: convert per ECMA 9.3.1
 *			1: convert per ECMA 15.1.2.3 (global.parseFloat())
 */

d_number StringNumericLiteral(d_string str, out size_t endidx, int parsefloat)
{
    import std.string : toStringz;
    import core.sys.posix.stdlib : strtod;

    // Convert StringNumericLiteral using ECMA 9.3.1
    d_number number;
    int sign = 0;
    size_t i;
    size_t len;
    size_t eoff;
    if(!str.length)
        return 0;
    // Skip leading whitespace
    eoff = str.length;
    foreach(size_t j, dchar c; str)
    {
        if(!isStrWhiteSpaceChar(c))
        {
            eoff = j;
            break;
        }
    }
    str = str[eoff .. $];
    len = str.length;

    // Check for [+|-]
    i = 0;
    if(len)
    {
        switch(str[0])
        {
        case '+':
            sign = 0;
            i++;
            break;

        case '-':
            sign = 1;
            i++;
            break;

        default:
            sign = 0;
            break;
        }
    }

    size_t inflen = (cast(string)(Text.Infinity)).length;
    if(len - i >= inflen &&
       str[i .. i + inflen] == Text.Infinity)
    {
        number = sign ? -d_number.infinity : d_number.infinity;
        endidx = eoff + i + inflen;
    }
    else if(len - i >= 2 &&
            str[i] == '0' && (str[i + 1] == 'x' || str[i + 1] == 'X'))
    {
        // Check for 0[x|X]HexDigit...
        number = 0;
        if(parsefloat)
        {   // Do not recognize the 0x, treat it as if it's just a '0'
            i += 1;
        }
        else
        {
            i += 2;
            for(; i < len; i++)
            {
                tchar c;

                c = str[i];          // don't need to decode UTF here
                if('0' <= c && c <= '9')
                    number = number * 16 + (c - '0');
                else if('a' <= c && c <= 'f')
                    number = number * 16 + (c - 'a' + 10);
                else if('A' <= c && c <= 'F')
                    number = number * 16 + (c - 'A' + 10);
                else
                    break;
            }
        }
        if(sign)
            number = -number;
        endidx = eoff + i;
    }
    else
    {
        char* endptr;
        const (char) * s = toStringz(str[i .. len]);

        //endptr = s;//Fixed: No need to fill endptr prior to stdtod
        number = strtod(s, &endptr);
        endidx = (endptr - s) + i;

        //printf("s = '%s', endidx = %d, eoff = %d, number = %g\n", s, endidx, eoff, number);

        // Correctly produce a -0 for the
        // string "-1e-2000"
        if(sign)
            number = -number;
        if(endidx == i && (parsefloat || i != 0))
            number = d_number.nan;
        endidx += eoff;
    }

    return number;
}

int localeCompare(CallContext *cc, d_string s1, d_string s2)
{   // no locale support here
    import std.string : cmp;
    return cmp(s1, s2);
}

package @trusted @nogc pure nothrow
d_string getLineAt(d_string base, const(tchar)* p,
                   out Loc linnum, out int charpos)
{
    assert(base.ptr <= p && p <= base.ptr + base.length);

    immutable(char)* s;
    immutable(char)* slinestart;

    linnum = 1;
    if (0 == base.length || p is null) return null;

    // Find the beginning of the line
    slinestart = base.ptr;
    for(s = base.ptr; s < p; ++s)
    {
        if(*s == '\n')
        {
            ++linnum;
            slinestart = s + 1;
        }
    }
    charpos = cast(int)(p - slinestart);

    // Find the end of the line
    loop: for(;;)
    {
        switch(*s)
        {
        case '\n':
        case 0:
        case 0x1A:
            break loop;
        default:
            ++s;
        }
    }
    while(slinestart < s && s[-1] == '\r') --s;
    return slinestart[0.. s - slinestart];
}

package @trusted @nogc pure nothrow
d_string getLineAt(d_string src, Loc loc)
{
    immutable(tchar)* slinestart;
    immutable(tchar)* s;
    uint linnum = 1;

    if(!src)
        return null;
    slinestart = src.ptr;
    loop: for(s = src.ptr;; ++s)
    {
        switch(*s)
        {
        case '\n':
            if(loc <= linnum) break loop;
            slinestart = s + 1;
            ++linnum;
            break;

        case 0:
        case 0x1A:
            break loop;
        default:
        }
    }

    // Remove trailing \r's
    while(slinestart < s && s[-1] == '\r') --s;

    return slinestart[0 .. slinestart - s];
}
