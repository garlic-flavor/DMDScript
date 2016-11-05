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


module dmdscript.text;

//------------------------------------------------------------------------------
enum Text
{
    Empty = "",
    source = "source",
    global = "global",
    ignoreCase = "ignoreCase",
    multiline = "multiline",
    lastIndex = "lastIndex",
    input = "input",
    lastMatch = "lastMatch",
    lastParen = "lastParen",
    leftContext = "leftContext",
    rightContext = "rightContext",
    prototype = "prototype",
    constructor = "constructor",
    toString = "toString",
    toLocaleString = "toLocaleString",
    toSource = "toSource",
    valueOf = "valueOf",
    message = "message",
    description = "description",
    Error = "Error",
    name = "name",
    length = "length",
    NaN = "NaN",
    Infinity = "Infinity",
    negInfinity = "-Infinity",
    bobjectb = "[object]",
    undefined = "undefined",
    _null = "null",
    _true = "true",
    _false = "false",
    object = "object",
    string = "enum string",
    number = "number",
    boolean = "boolean",
    Object = "Object",
    String = "String",
    Number = "Number",
    Boolean = "Boolean",
    Date = "Date",
    Array = "Array",
    RegExp = "RegExp",
    arity = "arity",
    arguments = "arguments",
    callee = "callee",
    caller = "caller",                  // extension
    EvalError = "EvalError",
    RangeError = "RangeError",
    ReferenceError = "ReferenceError",
    SyntaxError = "SyntaxError",
    TypeError = "TypeError",
    URIError = "URIError",
    _this = "this",
    fromCharCode = "fromCharCode",
    charAt = "charAt",
    charCodeAt = "charCodeAt",
    concat = "concat",
    indexOf = "indexOf",
    lastIndexOf = "lastIndexOf",
    localeCompare = "localeCompare",
    match = "match",
    replace = "replace",
    search = "search",
    slice = "slice",
    split = "split",
    substr = "substr",
    substring = "substring",
    toLowerCase = "toLowerCase",
    toLocaleLowerCase = "toLocaleLowerCase",
    toUpperCase = "toUpperCase",
    toLocaleUpperCase = "toLocaleUpperCase",
    hasOwnProperty = "hasOwnProperty",
    isPrototypeOf = "isPrototypeOf",
    propertyIsEnumerable = "propertyIsEnumerable",
    dollar1 = "$1",
    dollar2 = "$2",
    dollar3 = "$3",
    dollar4 = "$4",
    dollar5 = "$5",
    dollar6 = "$6",
    dollar7 = "$7",
    dollar8 = "$8",
    dollar9 = "$9",
    index = "index",
    compile = "compile",
    test = "test",
    exec = "exec",
    MAX_VALUE = "MAX_VALUE",
    MIN_VALUE = "MIN_VALUE",
    NEGATIVE_INFINITY = "NEGATIVE_INFINITY",
    POSITIVE_INFINITY = "POSITIVE_INFINITY",
    dash = "-",
    toFixed = "toFixed",
    toExponential = "toExponential",
    toPrecision = "toPrecision",
    abs = "abs",
    acos = "acos",
    asin = "asin",
    atan = "atan",
    atan2 = "atan2",
    ceil = "ceil",
    cos = "cos",
    exp = "exp",
    floor = "floor",
    log = "log",
    max = "max",
    min = "min",
    pow = "pow",
    random = "random",
    round = "round",
    sin = "sin",
    sqrt = "sqrt",
    tan = "tan",
    E = "E",
    LN10 = "LN10",
    LN2 = "LN2",
    LOG2E = "LOG2E",
    LOG10E = "LOG10E",
    PI = "PI",
    SQRT1_2 = "SQRT1_2",
    SQRT2 = "SQRT2",
    parse = "parse",
    UTC = "UTC",

    getTime = "getTime",
    getYear = "getYear",
    getFullYear = "getFullYear",
    getUTCFullYear = "getUTCFullYear",
    getDate = "getDate",
    getUTCDate = "getUTCDate",
    getMonth = "getMonth",
    getUTCMonth = "getUTCMonth",
    getDay = "getDay",
    getUTCDay = "getUTCDay",
    getHours = "getHours",
    getUTCHours = "getUTCHours",
    getMinutes = "getMinutes",
    getUTCMinutes = "getUTCMinutes",
    getSeconds = "getSeconds",
    getUTCSeconds = "getUTCSeconds",
    getMilliseconds = "getMilliseconds",
    getUTCMilliseconds = "getUTCMilliseconds",
    getTimezoneOffset = "getTimezoneOffset",
    getVarDate = "getVarDate",

    setTime = "setTime",
    setYear = "setYear",
    setFullYear = "setFullYear",
    setUTCFullYear = "setUTCFullYear",
    setDate = "setDate",
    setUTCDate = "setUTCDate",
    setMonth = "setMonth",
    setUTCMonth = "setUTCMonth",
    setDay = "setDay",
    setUTCDay = "setUTCDay",
    setHours = "setHours",
    setUTCHours = "setUTCHours",
    setMinutes = "setMinutes",
    setUTCMinutes = "setUTCMinutes",
    setSeconds = "setSeconds",
    setUTCSeconds = "setUTCSeconds",
    setMilliseconds = "setMilliseconds",
    setUTCMilliseconds = "setUTCMilliseconds",

    toDateString = "toDateString",
    toTimeString = "toTimeString",
    toLocaleDateString = "toLocaleDateString",
    toLocaleTimeString = "toLocaleTimeString",
    toUTCString = "toUTCString",
    toGMTString = "toGMTString",

    comma = ",",
    join = "join",
    pop = "pop",
    push = "push",
    reverse = "reverse",
    shift = "shift",
    sort = "sort",
    splice = "splice",
    unshift = "unshift",
    apply = "apply",
    call = "call",
    _function = "function",

    eval = "eval",
    parseInt = "parseInt",
    parseFloat = "parseFloat",
    escape = "escape",
    unescape = "unescape",
    isNaN = "isNaN",
    isFinite = "isFinite",
    decodeURI = "decodeURI",
    decodeURIComponent = "decodeURIComponent",
    encodeURI = "encodeURI",
    encodeURIComponent = "encodeURIComponent",

    print = "print",
    println = "println",
    readln = "readln",
    getenv = "getenv",
    _assert = "assert",

    Function = "Function",
    Math = "Math",

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

    anchor = "anchor",
    big = "big",
    blink = "blink",
    bold = "bold",
    fixed = "fixed",
    fontcolor = "fontcolor",
    fontsize = "fontsize",
    italics = "italics",
    link = "link",
    small = "small",
    strike = "strike",
    sub = "sub",
    sup = "sup",

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

    ScriptEngine = "ScriptEngine",
    ScriptEngineBuildVersion = "ScriptEngineBuildVersion",
    ScriptEngineMajorVersion = "ScriptEngineMajorVersion",
    ScriptEngineMinorVersion = "ScriptEngineMinorVersion",
    DMDScript = "DMDScript",

    date = "date",
    unknown = "unknown",
}
