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

//
private struct _TextImpl
{
    import dmdscript.script : d_string;
    const d_string entity;
    const size_t hash;
    alias entity this;

    this(d_string str)
    {
        import dmdscript.value : Value;

        entity = str;
        hash = Value.calcHash(entity);
    }
}

//------------------------------------------------------------------------------
enum Text
{
    Empty = _TextImpl(""),
    source = _TextImpl("source"),
    global = _TextImpl("global"),
    ignoreCase = _TextImpl("ignoreCase"),
    multiline = _TextImpl("multiline"),
    lastIndex = _TextImpl("lastIndex"),
    input = _TextImpl("input"),
    lastMatch = _TextImpl("lastMatch"),
    lastParen = _TextImpl("lastParen"),
    leftContext = _TextImpl("leftContext"),
    rightContext = _TextImpl("rightContext"),
    prototype = _TextImpl("prototype"),
    constructor = _TextImpl("constructor"),
    toString = _TextImpl("toString"),
    toLocaleString = _TextImpl("toLocaleString"),
    toSource = _TextImpl("toSource"),
    valueOf = _TextImpl("valueOf"),
    message = _TextImpl("message"),
    description = _TextImpl("description"),
    Error = _TextImpl("Error"),
    name = _TextImpl("name"),
    length = _TextImpl("length"),
    NaN = _TextImpl("NaN"),
    Infinity = _TextImpl("Infinity"),
    negInfinity = _TextImpl("-Infinity"),
    bobjectb = _TextImpl("[object]"),
    undefined = _TextImpl("undefined"),
    _null = _TextImpl("null"),
    _true = _TextImpl("true"),
    _false = _TextImpl("false"),
    object = _TextImpl("object"),
    string = _TextImpl("enum string"),
    number = _TextImpl("number"),
    boolean = _TextImpl("boolean"),
    Object = _TextImpl("Object"),
    String = _TextImpl("String"),
    Number = _TextImpl("Number"),
    Boolean = _TextImpl("Boolean"),
    Date = _TextImpl("Date"),
    Array = _TextImpl("Array"),
    RegExp = _TextImpl("RegExp"),
    arity = _TextImpl("arity"),
    arguments = _TextImpl("arguments"),
    callee = _TextImpl("callee"),
    caller = _TextImpl("caller"),                  // extension
    EvalError = _TextImpl("EvalError"),
    RangeError = _TextImpl("RangeError"),
    ReferenceError = _TextImpl("ReferenceError"),
    SyntaxError = _TextImpl("SyntaxError"),
    TypeError = _TextImpl("TypeError"),
    URIError = _TextImpl("URIError"),
    _this = _TextImpl("this"),
    fromCharCode = _TextImpl("fromCharCode"),
    charAt = _TextImpl("charAt"),
    charCodeAt = _TextImpl("charCodeAt"),
    concat = _TextImpl("concat"),
    indexOf = _TextImpl("indexOf"),
    lastIndexOf = _TextImpl("lastIndexOf"),
    localeCompare = _TextImpl("localeCompare"),
    match = _TextImpl("match"),
    replace = _TextImpl("replace"),
    search = _TextImpl("search"),
    slice = _TextImpl("slice"),
    split = _TextImpl("split"),
    substr = _TextImpl("substr"),
    substring = _TextImpl("substring"),
    toLowerCase = _TextImpl("toLowerCase"),
    toLocaleLowerCase = _TextImpl("toLocaleLowerCase"),
    toUpperCase = _TextImpl("toUpperCase"),
    toLocaleUpperCase = _TextImpl("toLocaleUpperCase"),
    hasOwnProperty = _TextImpl("hasOwnProperty"),
    isPrototypeOf = _TextImpl("isPrototypeOf"),
    propertyIsEnumerable = _TextImpl("propertyIsEnumerable"),
    dollar1 = _TextImpl("$1"),
    dollar2 = _TextImpl("$2"),
    dollar3 = _TextImpl("$3"),
    dollar4 = _TextImpl("$4"),
    dollar5 = _TextImpl("$5"),
    dollar6 = _TextImpl("$6"),
    dollar7 = _TextImpl("$7"),
    dollar8 = _TextImpl("$8"),
    dollar9 = _TextImpl("$9"),
    index = _TextImpl("index"),
    compile = _TextImpl("compile"),
    test = _TextImpl("test"),
    exec = _TextImpl("exec"),
    MAX_VALUE = _TextImpl("MAX_VALUE"),
    MIN_VALUE = _TextImpl("MIN_VALUE"),
    NEGATIVE_INFINITY = _TextImpl("NEGATIVE_INFINITY"),
    POSITIVE_INFINITY = _TextImpl("POSITIVE_INFINITY"),
    dash = _TextImpl("-"),
    toFixed = _TextImpl("toFixed"),
    toExponential = _TextImpl("toExponential"),
    toPrecision = _TextImpl("toPrecision"),
    abs = _TextImpl("abs"),
    acos = _TextImpl("acos"),
    asin = _TextImpl("asin"),
    atan = _TextImpl("atan"),
    atan2 = _TextImpl("atan2"),
    ceil = _TextImpl("ceil"),
    cos = _TextImpl("cos"),
    exp = _TextImpl("exp"),
    floor = _TextImpl("floor"),
    log = _TextImpl("log"),
    max = _TextImpl("max"),
    min = _TextImpl("min"),
    pow = _TextImpl("pow"),
    random = _TextImpl("random"),
    round = _TextImpl("round"),
    sin = _TextImpl("sin"),
    sqrt = _TextImpl("sqrt"),
    tan = _TextImpl("tan"),
    E = _TextImpl("E"),
    LN10 = _TextImpl("LN10"),
    LN2 = _TextImpl("LN2"),
    LOG2E = _TextImpl("LOG2E"),
    LOG10E = _TextImpl("LOG10E"),
    PI = _TextImpl("PI"),
    SQRT1_2 = _TextImpl("SQRT1_2"),
    SQRT2 = _TextImpl("SQRT2"),
    parse = _TextImpl("parse"),
    UTC = _TextImpl("UTC"),

    getTime = _TextImpl("getTime"),
    getYear = _TextImpl("getYear"),
    getFullYear = _TextImpl("getFullYear"),
    getUTCFullYear = _TextImpl("getUTCFullYear"),
    getDate = _TextImpl("getDate"),
    getUTCDate = _TextImpl("getUTCDate"),
    getMonth = _TextImpl("getMonth"),
    getUTCMonth = _TextImpl("getUTCMonth"),
    getDay = _TextImpl("getDay"),
    getUTCDay = _TextImpl("getUTCDay"),
    getHours = _TextImpl("getHours"),
    getUTCHours = _TextImpl("getUTCHours"),
    getMinutes = _TextImpl("getMinutes"),
    getUTCMinutes = _TextImpl("getUTCMinutes"),
    getSeconds = _TextImpl("getSeconds"),
    getUTCSeconds = _TextImpl("getUTCSeconds"),
    getMilliseconds = _TextImpl("getMilliseconds"),
    getUTCMilliseconds = _TextImpl("getUTCMilliseconds"),
    getTimezoneOffset = _TextImpl("getTimezoneOffset"),
    getVarDate = _TextImpl("getVarDate"),

    setTime = _TextImpl("setTime"),
    setYear = _TextImpl("setYear"),
    setFullYear = _TextImpl("setFullYear"),
    setUTCFullYear = _TextImpl("setUTCFullYear"),
    setDate = _TextImpl("setDate"),
    setUTCDate = _TextImpl("setUTCDate"),
    setMonth = _TextImpl("setMonth"),
    setUTCMonth = _TextImpl("setUTCMonth"),
    setDay = _TextImpl("setDay"),
    setUTCDay = _TextImpl("setUTCDay"),
    setHours = _TextImpl("setHours"),
    setUTCHours = _TextImpl("setUTCHours"),
    setMinutes = _TextImpl("setMinutes"),
    setUTCMinutes = _TextImpl("setUTCMinutes"),
    setSeconds = _TextImpl("setSeconds"),
    setUTCSeconds = _TextImpl("setUTCSeconds"),
    setMilliseconds = _TextImpl("setMilliseconds"),
    setUTCMilliseconds = _TextImpl("setUTCMilliseconds"),

    toDateString = _TextImpl("toDateString"),
    toTimeString = _TextImpl("toTimeString"),
    toLocaleDateString = _TextImpl("toLocaleDateString"),
    toLocaleTimeString = _TextImpl("toLocaleTimeString"),
    toUTCString = _TextImpl("toUTCString"),
    toGMTString = _TextImpl("toGMTString"),

    comma = _TextImpl(","),
    join = _TextImpl("join"),
    pop = _TextImpl("pop"),
    push = _TextImpl("push"),
    reverse = _TextImpl("reverse"),
    shift = _TextImpl("shift"),
    sort = _TextImpl("sort"),
    splice = _TextImpl("splice"),
    unshift = _TextImpl("unshift"),
    apply = _TextImpl("apply"),
    call = _TextImpl("call"),
    _function = _TextImpl("function"),

    eval = _TextImpl("eval"),
    parseInt = _TextImpl("parseInt"),
    parseFloat = _TextImpl("parseFloat"),
    escape = _TextImpl("escape"),
    unescape = _TextImpl("unescape"),
    isNaN = _TextImpl("isNaN"),
    isFinite = _TextImpl("isFinite"),
    decodeURI = _TextImpl("decodeURI"),
    decodeURIComponent = _TextImpl("decodeURIComponent"),
    encodeURI = _TextImpl("encodeURI"),
    encodeURIComponent = _TextImpl("encodeURIComponent"),

    print = _TextImpl("print"),
    println = _TextImpl("println"),
    readln = _TextImpl("readln"),
    getenv = _TextImpl("getenv"),
    _assert = _TextImpl("assert"),

    Function = _TextImpl("Function"),
    Math = _TextImpl("Math"),

    _0 = _TextImpl("0"),
    _1 = _TextImpl("1"),
    _2 = _TextImpl("2"),
    _3 = _TextImpl("3"),
    _4 = _TextImpl("4"),
    _5 = _TextImpl("5"),
    _6 = _TextImpl("6"),
    _7 = _TextImpl("7"),
    _8 = _TextImpl("8"),
    _9 = _TextImpl("9"),

    anchor = _TextImpl("anchor"),
    big = _TextImpl("big"),
    blink = _TextImpl("blink"),
    bold = _TextImpl("bold"),
    fixed = _TextImpl("fixed"),
    fontcolor = _TextImpl("fontcolor"),
    fontsize = _TextImpl("fontsize"),
    italics = _TextImpl("italics"),
    link = _TextImpl("link"),
    small = _TextImpl("small"),
    strike = _TextImpl("strike"),
    sub = _TextImpl("sub"),
    sup = _TextImpl("sup"),

    Enumerator = _TextImpl("Enumerator"),
    item = _TextImpl("item"),
    atEnd = _TextImpl("atEnd"),
    moveNext = _TextImpl("moveNext"),
    moveFirst = _TextImpl("moveFirst"),

    VBArray = _TextImpl("VBArray"),
    dimensions = _TextImpl("dimensions"),
    getItem = _TextImpl("getItem"),
    lbound = _TextImpl("lbound"),
    toArray = _TextImpl("toArray"),
    ubound = _TextImpl("ubound"),

    ScriptEngine = _TextImpl("ScriptEngine"),
    ScriptEngineBuildVersion = _TextImpl("ScriptEngineBuildVersion"),
    ScriptEngineMajorVersion = _TextImpl("ScriptEngineMajorVersion"),
    ScriptEngineMinorVersion = _TextImpl("ScriptEngineMinorVersion"),
    DMDScript = _TextImpl("DMDScript"),

    date = _TextImpl("date"),
    unknown = _TextImpl("unknown"),

    value = _TextImpl("value"),
    writable = _TextImpl("writable"),
    get = _TextImpl("get"),
    set = _TextImpl("set"),
    enumerable = _TextImpl("enumerable"),
    configurable = _TextImpl("configurable"),
}


/+
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

    value = "value",
    writable = "writable",
    get = "get",
    set = "set",
    enumerable = "enumerable",
    configurable = "configurable",
}
+/
