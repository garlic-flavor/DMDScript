/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */

// This module should not depend any modules other than phobos.
module dmdscript.primitive;

//------------------------------------------------------------------------------
//
alias char_t = char;
alias string_t = immutable(char_t)[];
alias d_time = long; // to be replaced.

alias number_t = ulong; // needed?
alias real_t = double; // needed?

enum d_time_nan = long.min;


//==============================================================================
package:

//------------------------------------------------------------------------------
enum Text : string_t
{
    Empty = "",
    Infinity = "Infinity",
    negInfinity = "-Infinity",
    bobjectb = "[object]",
    _null = "null",
    _true = "true",
    _false = "false",
    object = "object",
    string = "enum string",
    boolean = "boolean",
    _this = "this",
    dash = "-",

    comma = ",",
    _function = "function",

    _assert = "assert",

    _0 = "0",
    _1 = "1",
    _2 = "2",
    _3 = "3",
    _4 = "4",
    _5 = "5",
    _6 = "6",
    _7 = "7",
    _8 = "8",
    _9 = "9",

    Enumerator = "Enumerator",
    item = "item",
    atEnd = "atEnd",
    moveNext = "moveNext",
    moveFirst = "moveFirst",

    VBArray = "VBArray",
    dimensions = "dimensions",
    getItem = "getItem",
    lbound = "lbound",
    toArray = "toArray",
    ubound = "ubound",

    DMDScript = "DMDScript",

    date = "date",
    unknown = "unknown",
}

//------------------------------------------------------------------------------
enum Key : StringKey
{
    global = StringKey("global"),
    toLocaleString = StringKey("toLocaleString"),
    prototype = StringKey("prototype"),
    constructor = StringKey("constructor"),
    toString = StringKey("toString"),
    toSource = StringKey("toSource"),
    valueOf = StringKey("valueOf"),
    message = StringKey("message"),
    description = StringKey("description"),
    name = StringKey("name"),
    length = StringKey("length"),

    NaN = StringKey("NaN"),
    undefined = StringKey("undefined"),
    number = StringKey("number"),
    Object = StringKey("Object"),
    String = StringKey("String"),
    Number = StringKey("Number"),
    Boolean = StringKey("Boolean"),
    Date = StringKey("Date"),
    Array = StringKey("Array"),
    RegExp = StringKey("RegExp"),
    Error = StringKey("Error"),
    Symbol = StringKey("Symbol"),
    Map = StringKey("Map"),
    Set = StringKey("Set"),
    WeakMap = StringKey("WeakMap"),
    WeakSet =StringKey("WeakSet"),
    ArrayBuffer = StringKey("ArrayBuffer"),
    DataView = StringKey("DataView"),
    JSON = StringKey("JSON"),
    Promise = StringKey("Promise"),
    Reflect = StringKey("Reflect"),
    Proxy = StringKey("Proxy"),

    arguments = StringKey("arguments"),
    callee = StringKey("callee"),
    caller = StringKey("caller"),                  // extension

    Function = StringKey("Function"),
    Math = StringKey("Math"),

    value = StringKey("value"),

    hasInstance = StringKey("hasInstance"),
    Iterator = StringKey("Iterator"),
}

//------------------------------------------------------------------------------
//
struct StringKey
{
    //
    string_t entity;
    alias entity this;

    //
    @safe @nogc pure nothrow
    this(string_t str)
    {
        entity = str;
        if (__ctfe)
            _hash = calcHash(entity);
    }

    //
    @safe @nogc pure nothrow
    this(string_t str, size_t h)
    {
        entity = str;
        _hash = h;
    }

    //
    @safe pure nothrow
    this(in uint idx)
    {
        import std.conv : to;
        entity = idx.to!string_t;
        if (__ctfe)
            _hash = calcHash(entity);
    }

    //
    @property @safe @nogc pure nothrow
    size_t hash() const
    {
        if (0 < _hash)
            return _hash;
        return calcHash(entity);
    }

    //
    @property @safe @nogc pure nothrow
    size_t hash()
    {
        if (0 == _hash)
            _hash = calcHash(entity);
        return _hash;
    }

    //
    @property @safe @nogc pure nothrow
    size_t calculatedHash() const
    {
        return _hash;
    }

    //
    @safe @nogc pure nothrow
    bool opEquals(in ref StringKey rvalue) const
    {
        return entity == rvalue.entity;
    }

    //
    @safe @nogc pure nothrow
    bool opEquals(in string_t rvalue) const
    {
        return entity == rvalue;
    }

    //
    @safe @nogc pure nothrow
    string_t toString() const
    {
        return entity;
    }

    //
    @safe @nogc pure nothrow
    size_t toHash()
    {
        if (0 == _hash)
            _hash = calcHash(entity);
        return _hash;
    }

    //
    @safe @nogc pure nothrow
    size_t toHash() const
    {
        if (0 == _hash)
            return calcHash(entity);
        else
            return _hash;
    }

    //
    @safe @nogc pure nothrow
    void put(string_t str)
    {
        entity = str;
        _hash = calcHash(entity);
    }

private:
    size_t _hash;

package static:

    //
    @safe pure nothrow
    StringKey* build(string_t key)
    {
        return new StringKey(key, calcHash(key));
    }
}

//------------------------------------------------------------------------------
@safe @nogc pure nothrow
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

//------------------------------------------------------------------------------
enum Cmask = 0xdf; // ('a' & Cmask) == 'A'

//------------------------------------------------------------------------------
/*
Convert d_string to an index, if it is one.
Returns:
    true    it's an index, and *index is set
    false   it's not an index
 */
@safe @nogc pure nothrow
bool StringToIndex(string name, out uint index)
{
    if(name.length)
    {
        uint i = 0;

        for(uint j = 0; j < name.length; j++)
        {
            char_t c = name[j];

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


//------------------------------------------------------------------------------
/*
Parse string numeric literal into a number.
Input:
    parsefloat    0: convert per ECMA 9.3.1
                  1: convert per ECMA 15.1.2.3 (global.parseFloat())
*/
@trusted
double StringNumericLiteral(string_t str, out size_t endidx, int parsefloat)
{
    import std.string : toStringz;
    import core.sys.posix.stdlib : strtod;

    // Convert StringNumericLiteral using ECMA 9.3.1
    double number;
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
    if(0 < len)
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

    size_t inflen = Text.Infinity.length;
    if(len - i >= inflen && str[i .. i + inflen] == Text.Infinity)
    {
        number = sign ? -double.infinity : double.infinity;
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
                char_t c;

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
        const(char)* s = toStringz(str[i .. len]);

        //endptr = s;//Fixed: No need to fill endptr prior to stdtod
        number = strtod(s, &endptr);
        endidx = (endptr - s) + i;

        //printf("s = '%s', endidx = %d, eoff = %d, number = %g\n", s, endidx, eoff, number);

        // Correctly produce a -0 for the
        // string "-1e-2000"
        if(sign)
            number = -number;
        if(endidx == i && (parsefloat || i != 0))
            number = double.nan;
        endidx += eoff;
    }

    return number;
}

//------------------------------------------------------------------------------
string_t NumberToString(in double n)
{
    import std.format : sformat;
    import core.stdc.string : strlen;
    import std.math : isInfinity, isNaN;

    string_t str;
    enum string_t[10]  strs =
        [ Text._0, Text._1, Text._2, Text._3, Text._4,
          Text._5, Text._6, Text._7, Text._8, Text._9 ];

    if(n.isNaN)
        str = Key.NaN;
    else if(n >= 0 && n <= 9 && n == cast(int)n)
        str = strs[cast(int)n];
    else if(n.isInfinity)
    {
        if(n < 0)
            str = Text.negInfinity;
        else
            str = Text.Infinity;
    }
    else
    {
        char_t[100] buffer;                // should shrink this to max size,
        // but doesn't really matter
        char_t* p;

        // ECMA 262 requires %.21g (21 digits) of precision. But, the
        // C runtime library doesn't handle that. Until the C runtime
        // library is upgraded to ANSI C 99 conformance, use
        // 16 digits, which is all the GCC library will round correctly.

        sformat(buffer, "%.16g\0", n);
        //std.c.stdio.sprintf(buffer.ptr, "%.16g", number);

        // Trim leading spaces
        for(p = buffer.ptr; *p == ' '; p++)
        {
        }


        {             // Trim any 0's following exponent 'e'
            char_t* q;
            char_t* t;

            for(q = p; *q; q++)
            {
                if(*q == 'e')
                {
                    q++;
                    if(*q == '+' || *q == '-')
                        q++;
                    t = q;
                    while(*q == '0')
                        q++;
                    if(t != q)
                    {
                        for(;; )
                        {
                            *t = *q;
                            if(*t == 0)
                                break;
                            t++;
                            q++;
                        }
                    }
                    break;
                }
            }
        }
        str = p[0 .. strlen(p)].idup;
    }
    return str;
}

//------------------------------------------------------------------------------
//
@safe @nogc pure nothrow
size_t calcHash(in size_t u)
{
    static if      (size_t.sizeof == 4)
        return u ^ 0x55555555;
    else static if (size_t.sizeof == 8) // Is this OK?
        return u ^ 0x5555555555555555;
    else static assert(0);
}

//------------------------------------------------------------------------------
//
@safe @nogc pure nothrow
size_t calcHash(in double d)
{
    return calcHash(cast(size_t)d);
}

//------------------------------------------------------------------------------
//
@trusted @nogc pure nothrow
size_t calcHash(in string_t s)
{
    size_t hash;

    /* If it looks like an array index, hash it to the
     * same value as if it was an array index.
     * This means that "1234" hashes to the same value as 1234.
     */
    hash = 0;
    foreach(char_t c; s)
    {
        switch(c)
        {
        case '0':       hash *= 10;             break;
        case '1':       hash = hash * 10 + 1;   break;

        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            hash = hash * 10 + (c - '0');
            break;

        default:
        {
            uint len = s.length;
            ubyte* str = cast(ubyte*)s.ptr;

            hash = 0;
            while(1)
            {
                switch(len)
                {
                case 0:
                    break;

                case 1:
                    hash *= 9;
                    hash += *cast(ubyte*)str;
                    break;

                case 2:
                    hash *= 9;
                    if (__ctfe)
                        hash += str[0..2].toNative!ushort;
                    else
                        hash += *cast(ushort*)str;
                    break;

                case 3:
                    hash *= 9;
                    if (__ctfe)
                        hash += (str[0..2].toNative!ushort << 8) +
                            (cast(ubyte*)str)[2];
                    else
                        hash += (*cast(ushort*)str << 8) +
                            (cast(ubyte*)str)[2];
                    break;

                default:
                    hash *= 9;
                    if (__ctfe)
                        hash += str[0..4].toNative!uint;
                    else
                        hash += *cast(uint*)str;
                    str += 4;
                    len -= 4;
                    continue;
                }
                break;
            }
            break;
        }
        // return s.hash;
        }
    }
    return calcHash(hash);
}

//------------------------------------------------------------------------------
/*
Use this instead of std.string.cmp() because
we don't care about lexicographic ordering.
This is faster.
*/
@trusted @nogc pure nothrow
int stringcmp(in string_t s1, in string_t s2)
{
    import core.stdc.string : memcmp;

    int c = s1.length - s2.length;
    if(c == 0)
    {
        if(s1.ptr == s2.ptr)
            return 0;
        c = memcmp(s1.ptr, s2.ptr, s1.length);
    }
    return c;
}



//==============================================================================
private:

// for calcHash at CTFE.
@safe @nogc pure nothrow
T toNative(T, size_t N = T.sizeof)(in ubyte[] buf)
{
    assert(N <= buf.length);
    static if      (N == 1)
        return buf[0];
    else static if (N == 2)
    {
        version      (BigEndian)
            return ((cast(ushort)buf[0]) << 8) | (cast(ushort)buf[1]);
        else version (LittleEndian)
            return (cast(ushort)buf[0]) | ((cast(ushort)buf[1]) << 8);
        else static assert(0);
    }
    else static if (N == 4)
    {
        version      (BigEndian)
            return ((cast(uint)buf[0]) << 24) |
                   ((cast(uint)buf[1]) << 16) |
                   ((cast(uint)buf[2]) << 8) |
                   (cast(uint)buf[3]);
        else version (LittleEndian)
            return (cast(uint)buf[0]) |
                   ((cast(uint)buf[1]) << 8) |
                   ((cast(uint)buf[2]) << 16) |
                   ((cast(uint)buf[3]) << 24);
        else static assert(0);
    }
    else static if (N == 8)
    {
        version      (BigEndian)
            return ((cast(ulong)buf[0]) << 56) |
                   ((cast(ulong)buf[1]) << 48) |
                   ((cast(ulong)buf[2]) << 40) |
                   ((cast(ulong)buf[3]) << 32) |
                   ((cast(ulong)buf[4]) << 24) |
                   ((cast(ulong)buf[5]) << 16) |
                   ((cast(ulong)buf[6]) << 8) |
                   (cast(ulong)buf[7]);
        else version (LittleEndian)
            return (cast(ulong)buf[0]) |
                   ((cast(ulong)buf[1]) << 8) |
                   ((cast(ulong)buf[2]) << 16) |
                   ((cast(ulong)buf[3]) << 24) |
                   ((cast(ulong)buf[4]) << 32) |
                   ((cast(ulong)buf[5]) << 40) |
                   ((cast(ulong)buf[6]) << 48) |
                   ((cast(ulong)buf[7]) << 56);
        else static assert(0);
    }
    else static assert(0);
}
