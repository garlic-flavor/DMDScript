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
// Configuration
enum MAJOR_VERSION = 5;       // ScriptEngineMajorVersion
enum MINOR_VERSION = 5;       // ScriptEngineMinorVersion

enum BUILD_VERSION = 1;       // ScriptEngineBuildVersion

enum JSCRIPT_CATCH_BUG = 1;   // emulate Jscript's bug in scoping of
                              // catch objects in violation of ECMA
enum JSCRIPT_ESCAPEV_BUG = 0; // emulate Jscript's bug where \v is
                              // not recognized as vertical tab

//------------------------------------------------------------------------------
//
alias tchar = char;
alias line_number = uint;
alias tstring = immutable(tchar)[];
alias d_time = long;

// Aliases for script primitive types
// alias d_boolean = bool;
// alias d_number = double;
// alias d_int32 = int;
// alias d_uint32 = uint;
// alias d_int16 = short;
// alias d_uint16 = ushort;
// alias d_int8 = byte;
// alias d_uint8 = ubyte;

alias number_t = ulong;
alias real_t = double;

//alias d_boolean = uint;

//------------------------------------------------------------------------------
enum d_time_nan = long.min;

//------------------------------------------------------------------------------
package:

//
enum Text : tstring
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

    Iterator = "Iterator",
}

//
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

enum Cmask = 0xdf; // ('a' & Cmask) == 'A'

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


/*
Parse string numeric literal into a number.
Input:
    parsefloat    0: convert per ECMA 9.3.1
                  1: convert per ECMA 15.1.2.3 (global.parseFloat())
*/
@trusted
double StringNumericLiteral(tstring str, out size_t endidx, int parsefloat)
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

