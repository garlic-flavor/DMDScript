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

import dmdscript.property : StringKey;

//------------------------------------------------------------------------------
enum Key : StringKey
{
    source = StringKey("source"),
    global = StringKey("global"),
    ignoreCase = StringKey("ignoreCase"),
    multiline = StringKey("multiline"),
    lastIndex = StringKey("lastIndex"),
    input = StringKey("input"),
    lastMatch = StringKey("lastMatch"),
    lastParen = StringKey("lastParen"),
    leftContext = StringKey("leftContext"),
    rightContext = StringKey("rightContext"),
    prototype = StringKey("prototype"),
    constructor = StringKey("constructor"),
    toString = StringKey("toString"),
    toLocaleString = StringKey("toLocaleString"),
    toSource = StringKey("toSource"),
    valueOf = StringKey("valueOf"),
    message = StringKey("message"),
    description = StringKey("description"),
    Error = StringKey("Error"),
    name = StringKey("name"),
    length = StringKey("length"),
    NaN = StringKey("NaN"),
    Infinity = StringKey("Infinity"),
    undefined = StringKey("undefined"),
    number = StringKey("number"),
    Object = StringKey("Object"),
    String = StringKey("String"),
    Number = StringKey("Number"),
    Boolean = StringKey("Boolean"),
    Date = StringKey("Date"),
    Array = StringKey("Array"),
    RegExp = StringKey("RegExp"),
    arity = StringKey("arity"),
    arguments = StringKey("arguments"),
    callee = StringKey("callee"),
    caller = StringKey("caller"),                  // extension

    fromCharCode = StringKey("fromCharCode"),
    charAt = StringKey("charAt"),
    charCodeAt = StringKey("charCodeAt"),
    concat = StringKey("concat"),
    indexOf = StringKey("indexOf"),
    lastIndexOf = StringKey("lastIndexOf"),
    localeCompare = StringKey("localeCompare"),
    match = StringKey("match"),
    replace = StringKey("replace"),
    search = StringKey("search"),
    slice = StringKey("slice"),
    split = StringKey("split"),
    substr = StringKey("substr"),
    substring = StringKey("substring"),
    toLowerCase = StringKey("toLowerCase"),
    toLocaleLowerCase = StringKey("toLocaleLowerCase"),
    toUpperCase = StringKey("toUpperCase"),
    toLocaleUpperCase = StringKey("toLocaleUpperCase"),
    hasOwnProperty = StringKey("hasOwnProperty"),
    isPrototypeOf = StringKey("isPrototypeOf"),
    propertyIsEnumerable = StringKey("propertyIsEnumerable"),
    dollar1 = StringKey("$1"),
    dollar2 = StringKey("$2"),
    dollar3 = StringKey("$3"),
    dollar4 = StringKey("$4"),
    dollar5 = StringKey("$5"),
    dollar6 = StringKey("$6"),
    dollar7 = StringKey("$7"),
    dollar8 = StringKey("$8"),
    dollar9 = StringKey("$9"),
    index = StringKey("index"),
    compile = StringKey("compile"),
    test = StringKey("test"),
    exec = StringKey("exec"),
    MAX_VALUE = StringKey("MAX_VALUE"),
    MIN_VALUE = StringKey("MIN_VALUE"),
    NEGATIVE_INFINITY = StringKey("NEGATIVE_INFINITY"),
    POSITIVE_INFINITY = StringKey("POSITIVE_INFINITY"),

    toFixed = StringKey("toFixed"),
    toExponential = StringKey("toExponential"),
    toPrecision = StringKey("toPrecision"),
    abs = StringKey("abs"),
    acos = StringKey("acos"),
    asin = StringKey("asin"),
    atan = StringKey("atan"),
    atan2 = StringKey("atan2"),
    ceil = StringKey("ceil"),
    cos = StringKey("cos"),
    exp = StringKey("exp"),
    floor = StringKey("floor"),
    log = StringKey("log"),
    max = StringKey("max"),
    min = StringKey("min"),
    pow = StringKey("pow"),
    random = StringKey("random"),
    round = StringKey("round"),
    sin = StringKey("sin"),
    sqrt = StringKey("sqrt"),
    tan = StringKey("tan"),
    E = StringKey("E"),
    LN10 = StringKey("LN10"),
    LN2 = StringKey("LN2"),
    LOG2E = StringKey("LOG2E"),
    LOG10E = StringKey("LOG10E"),
    PI = StringKey("PI"),
    SQRT1_2 = StringKey("SQRT1_2"),
    SQRT2 = StringKey("SQRT2"),
    parse = StringKey("parse"),
    UTC = StringKey("UTC"),

    getTime = StringKey("getTime"),
    getYear = StringKey("getYear"),
    getFullYear = StringKey("getFullYear"),
    getUTCFullYear = StringKey("getUTCFullYear"),
    getDate = StringKey("getDate"),
    getUTCDate = StringKey("getUTCDate"),
    getMonth = StringKey("getMonth"),
    getUTCMonth = StringKey("getUTCMonth"),
    getDay = StringKey("getDay"),
    getUTCDay = StringKey("getUTCDay"),
    getHours = StringKey("getHours"),
    getUTCHours = StringKey("getUTCHours"),
    getMinutes = StringKey("getMinutes"),
    getUTCMinutes = StringKey("getUTCMinutes"),
    getSeconds = StringKey("getSeconds"),
    getUTCSeconds = StringKey("getUTCSeconds"),
    getMilliseconds = StringKey("getMilliseconds"),
    getUTCMilliseconds = StringKey("getUTCMilliseconds"),
    getTimezoneOffset = StringKey("getTimezoneOffset"),
    getVarDate = StringKey("getVarDate"),

    setTime = StringKey("setTime"),
    setYear = StringKey("setYear"),
    setFullYear = StringKey("setFullYear"),
    setUTCFullYear = StringKey("setUTCFullYear"),
    setDate = StringKey("setDate"),
    setUTCDate = StringKey("setUTCDate"),
    setMonth = StringKey("setMonth"),
    setUTCMonth = StringKey("setUTCMonth"),
    setDay = StringKey("setDay"),
    setUTCDay = StringKey("setUTCDay"),
    setHours = StringKey("setHours"),
    setUTCHours = StringKey("setUTCHours"),
    setMinutes = StringKey("setMinutes"),
    setUTCMinutes = StringKey("setUTCMinutes"),
    setSeconds = StringKey("setSeconds"),
    setUTCSeconds = StringKey("setUTCSeconds"),
    setMilliseconds = StringKey("setMilliseconds"),
    setUTCMilliseconds = StringKey("setUTCMilliseconds"),

    toDateString = StringKey("toDateString"),
    toTimeString = StringKey("toTimeString"),
    toLocaleDateString = StringKey("toLocaleDateString"),
    toLocaleTimeString = StringKey("toLocaleTimeString"),
    toUTCString = StringKey("toUTCString"),
    toGMTString = StringKey("toGMTString"),

    join = StringKey("join"),
    pop = StringKey("pop"),
    push = StringKey("push"),
    reverse = StringKey("reverse"),
    shift = StringKey("shift"),
    sort = StringKey("sort"),
    splice = StringKey("splice"),
    unshift = StringKey("unshift"),
    apply = StringKey("apply"),
    call = StringKey("call"),

    eval = StringKey("eval"),
    parseInt = StringKey("parseInt"),
    parseFloat = StringKey("parseFloat"),
    escape = StringKey("escape"),
    unescape = StringKey("unescape"),
    isNaN = StringKey("isNaN"),
    isFinite = StringKey("isFinite"),
    decodeURI = StringKey("decodeURI"),
    decodeURIComponent = StringKey("decodeURIComponent"),
    encodeURI = StringKey("encodeURI"),
    encodeURIComponent = StringKey("encodeURIComponent"),

    print = StringKey("print"),
    println = StringKey("println"),
    readln = StringKey("readln"),
    getenv = StringKey("getenv"),

    Function = StringKey("Function"),
    Math = StringKey("Math"),

    anchor = StringKey("anchor"),
    big = StringKey("big"),
    blink = StringKey("blink"),
    bold = StringKey("bold"),
    fixed = StringKey("fixed"),
    fontcolor = StringKey("fontcolor"),
    fontsize = StringKey("fontsize"),
    italics = StringKey("italics"),
    link = StringKey("link"),
    small = StringKey("small"),
    strike = StringKey("strike"),
    sub = StringKey("sub"),
    sup = StringKey("sup"),

    ScriptEngine = StringKey("ScriptEngine"),
    ScriptEngineBuildVersion = StringKey("ScriptEngineBuildVersion"),
    ScriptEngineMajorVersion = StringKey("ScriptEngineMajorVersion"),
    ScriptEngineMinorVersion = StringKey("ScriptEngineMinorVersion"),

    value = StringKey("value"),
    writable = StringKey("writable"),
    get = StringKey("get"),
    set = StringKey("set"),
    enumerable = StringKey("enumerable"),
    configurable = StringKey("configurable"),

    EvalError = StringKey("EvalError"),
    RangeError = StringKey("RangeError"),
    ReferenceError = StringKey("ReferenceError"),
    SyntaxError = StringKey("SyntaxError"),
    TypeError = StringKey("TypeError"),
    URIError = StringKey("URIError"),
}

enum Text
{
    Empty = "",
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
