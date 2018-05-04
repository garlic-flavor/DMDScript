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
alias d_time = long; // to be replaced.

alias number_t = ulong; // needed?
alias real_t = double; // needed?

enum d_time_nan = long.min;

//==============================================================================
package:

//------------------------------------------------------------------------------
enum Text : string
{
    Empty = "",
    Infinity = "Infinity",
    negInfinity = "-Infinity",
    bobjectb = "[object]",
    object = "object",
    string = "string",
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
///
enum Key : PropertyKey
{
    global = PropertyKey("global"),
    toLocaleString = PropertyKey("toLocaleString"),
    prototype = PropertyKey("prototype"),
    constructor = PropertyKey("constructor"),
    toString = PropertyKey("toString"),
    toSource = PropertyKey("toSource"),
    valueOf = PropertyKey("valueOf"),
    message = PropertyKey("message"),
    description = PropertyKey("description"),
    name = PropertyKey("name"),
    length = PropertyKey("length"),

    NaN = PropertyKey("NaN"),
    undefined = PropertyKey("undefined"),
    _null = PropertyKey("null"),
    _true = PropertyKey("true"),
    _false = PropertyKey("false"),
    number = PropertyKey("number"),
    Object = PropertyKey("Object"),
    String = PropertyKey("String"),
    Number = PropertyKey("Number"),
    Boolean = PropertyKey("Boolean"),
    Date = PropertyKey("Date"),
    Array = PropertyKey("Array"),
    RegExp = PropertyKey("RegExp"),
    Error = PropertyKey("Error"),
    Symbol = PropertyKey("Symbol"),
    Map = PropertyKey("Map"),
    Set = PropertyKey("Set"),
    WeakMap = PropertyKey("WeakMap"),
    WeakSet =PropertyKey("WeakSet"),
    ArrayBuffer = PropertyKey("ArrayBuffer"),
    DataView = PropertyKey("DataView"),
    JSON = PropertyKey("JSON"),
    Promise = PropertyKey("Promise"),
    Reflect = PropertyKey("Reflect"),
    Proxy = PropertyKey("Proxy"),

    arguments = PropertyKey("arguments"),
    callee = PropertyKey("callee"),
    caller = PropertyKey("caller"),                  // extension

    Function = PropertyKey("Function"),
    Math = PropertyKey("Math"),

    value = PropertyKey("value"),

    hasInstance = PropertyKey("hasInstance"),
    Iterator = PropertyKey("Iterator"),
}

//------------------------------------------------------------------------------
///
struct PropertyKey
{
    template IsKey(K)
    {
        enum IsKey = is(K : PropertyKey) || is(K : string) || is(K : size_t)
            || is(K : string);
    }

    //--------------------------------------------------------------------
    static @safe pure nothrow
    PropertyKey symbol(string key)
    {
        auto hash = calcHash(key);
        if (hash == cast(size_t)key.ptr)
            key = key.idup;
        return PropertyKey(key, cast(size_t)key.ptr);
    }

    //--------------------------------------------------------------------
    ///
    @safe pure
    this(K)(in auto ref K key) if (IsKey!K)
    {
        static if      (is(K : PropertyKey))
        {
            _text = key._text;
            _hash = key._hash;
        }
        else static if (is(K : string))
        {
            _text = key;
            _hash = calcHash(key);
        }
        else static if (is(K : size_t))
        {
            _text = null;
            _hash = key;
        }
        else static assert (0);
    }

    ///
    @safe @nogc pure nothrow
    this(string str, size_t h)
    {
        _text = str;
        _hash = h;
    }


    //--------------------------------------------------------------------
    @property @safe @nogc pure nothrow
    {
        ///
        size_t hash() const
        {
            return _hash;
        }
        alias toHash = hash;

        ///
        string text() const
        {
            return _text;
        }
        alias text this;

        bool hasString() const
        {
            return _text !is null;
        }
    }

    //--------------------------------------------------------------------
    @safe @nogc pure nothrow
    void put(K)(in auto ref K key) if (IsKey!K)
    {
        static if      (is(K : PropertyKey))
        {
            _text = key._text;
            _hash = key._hash;
        }
        else static if (is(K : string))
        {
            _text = key;
            _hash = calcHash(key);
        }
        else static if (is(K : size_t))
        {
            _text = null;
            _hash = key;
        }
        else static assert (0);
    }

    //--------------------------------------------------------------------
    ///
    @safe
    string toString() const
    {
        import std.conv : to;
        if (_text !is null)
            return _text;
        else
            return _hash.to!string;
    }

    ///
    @trusted
    bool isArrayIndex(out size_t index) const
    {
        if (_text is null)
        {
            index = _hash;
            return true;
        }
        else
            return StringToIndex(_text, index);
    }

    //--------------------------------------------------------------------
    @nogc pure nothrow
    bool opEquals()(in auto ref PropertyKey p) const
    {
        if (_text !is null)
            return 0 == stringcmp(_text, p._text);
        else
            return _hash == p._hash;
    }

private:
    size_t _hash;
    string _text;

static public:
    ///
    @safe nothrow
    const(PropertyKey)* build(string str)
    {
        return new PropertyKey(str);
    }

    ///
    @safe pure nothrow
    const(PropertyKey)* build(string str, size_t hash)
    {
        return new PropertyKey(str, hash);
    }
}
///
alias Identifier = const(PropertyKey)*;

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
            char c = name[j];

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
double StringNumericLiteral(string str, out size_t endidx, int parsefloat)
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
                char c;

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
        number = strtod(cast(char*)s, &endptr);
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
@trusted
string NumberToString(in double n)
{
    import std.format : sformat;
    import core.stdc.string : strlen;
    import std.math : isInfinity, isNaN;

    string str;
    enum string[10]  strs =
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
        char[100] buffer;                // should shrink this to max size,
        // but doesn't really matter
        char* p;

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
            char* q;
            char* t;

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
size_t calcHash(in string s)
{
    size_t hash;

    /* If it looks like an array index, hash it to the
     * same value as if it was an array index.
     * This means that "1234" hashes to the same value as 1234.
     */
    hash = 0;
    foreach(c; s)
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
int stringcmp(in string s1, in string s2)
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

//------------------------------------------------------------------------------
struct RegexLiteral
{
    string source;
    string pattern;
    string flags;
}

//------------------------------------------------------------------------------
//
@safe pure
bool parseUnicode(bool sentinelExists = false)(
    string base, ref size_t index, out dchar ret)
{
    import std.utf : decodeFront, decode;
    import std.conv : to;
    dchar c;
    bool withBracket = false;
    size_t start = index;
    dchar wc = 0;
    ret = '\0';

    static if (!sentinelExists)
    {
        if (base.length <= index)
            goto failure;
    }

    if (base[index] == '{')
    {
        withBracket = true;
        ++index;
    }

    for (size_t n = 0; index < base.length && (n < 4 || withBracket); ++n)
    {
        static if (!sentinelExists)
        {
            if (base.length <= index)
                goto failure;
        }

        c = base[index];
        if      ('0' <= c && c <= '9')
            c -= '0';
        else if ('a' <= c && c <= 'f')
            c -= 'a' - 10;
        else if ('A' <= c && c <= 'F')
            c -= 'A' - 10;
        else if (withBracket && c == '}')
        {
            ++index;
            break;
        }
        else
            goto failure;

        wc <<= 4;
        wc |= c;
        ++index;
    }

    ret = wc;
    return true;

failure:
    return false;
}

//------------------------------------------------------------------------------
///
/*
string_t convertToStdRegexPattern(string_t source,
                                  bool ignoreCase, bool unicode)
{
    import std.ascii : isASCII;
    import std.array : Appender;
    import std.format : format;
    import std.utf : encode;

    Appender!string_t buf;
    char_t[4] tmp;
    size_t j;
    dchar dc;

    buf.reserve(source.length);

    for (size_t i = 0; i < source.length;)
    {
        if (i+1 < source.length && source[i] == '\\' && source[i+1] == 'u')
        {
            j = i + 2;
            if (parseUnicode(source, j, dc))
                i = j;
            else
            {
                buf.put(source[i]);
                ++i;
            }


            if      (dc == '*' || dc == '+' || dc == '?' || dc == '{' ||
                     dc == '}')
            {
                buf.put('\\');
                buf.put(cast(char_t)dc);
            }
            else if (isASCII(dc))
            {
                buf.put(cast(char_t)dc);
            }
            else if (!ignoreCase || !unicode)
            {
                buf.put(format("\\U%08x", dc));
            }
            else
            {
                j = encode(tmp, dc);
                buf.put(tmp[0..j]);
            }
        }
        else
        {
            buf.put(source[i]);
            ++i;
        }
    }
    return buf.data;
}
*/

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
