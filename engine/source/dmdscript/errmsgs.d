// File generated by textgen.d
// *** ERROR MESSAGES ***

module dmdscript.errmsgs;

import dmdscript.protoerror: cTypeError = TypeError, RangeError, SyntaxError,
    cReferenceError = ReferenceError;

debug import std.stdio;

// deprecated // not used
// {
// enum RuntimePrefixError =
//     err!typeerror("DMDScript fatal runtime error: ");
// enum ComNoDefaultValueError =
//     err!typeerror("No default value for COM object");
// enum ComNoConstructPropertyError =
//     err!typeerror("%s does not have a [[Construct]] property");
// enum DispETypemismatchError =
//     err!typeerror("argument type mismatch for %s");
// enum DispEBadparamcountError =
//     err!typeerror("wrong number of arguments for %s");
// enum ComFunctionError =
//     err!typeerror("%s Invoke() fails with COM error %x");
// enum ComObjectError =
//     err!typeerror("Dcomobject: %s.%s fails with COM error %x");
// }
enum BadSwitchError = syntaxerr!(string)
    ("unrecognized switch '%s'");
enum UndefinedLabelError = syntaxerr!(string, string)
    ("undefined label '%s' in function '%s'");
enum BadCCommentError = syntaxerr!()
    ("unterminated /* */ comment");
enum BadHTMLCommentError = syntaxerr!()
    ("<!-- comment does not end in newline");
enum BadCharCError = syntaxerr!(dchar)
    ("unsupported char '%s'");
enum BadCharXError = syntaxerr!(uint)
    ("unsupported char 0x%04x");
enum BadHexSequenceError = syntaxerr!()
    ("escape hex sequence requires 2 hex digits");
enum UndefinedEscSequenceError = syntaxerr!(uint)
    ("undefined escape sequence \\%c");
enum StringNoEndQuoteError = syntaxerr!(char)
    ("string is missing an end quote %s");
enum UnterminatedStringError = syntaxerr!()
    ("end of file before end of string");
enum BadUSequenceError = syntaxerr!()
    ("\\u sequence must be followed by 4 hex characters");
enum UnrecognizedNLiteralError = syntaxerr!()
    ("unrecognized numeric literal");
enum FplExpectedIdentifierError = syntaxerr!(string)
    ("Identifier expected in FormalParameterList, not %s");
enum FplExpectedCommaError = syntaxerr!(string)
    ("comma expected in FormalParameterList, not %s");
enum ExpectedIdentifierError = syntaxerr!()
    ("identifier expected");
enum ExpectedGenericError = syntaxerr!(string, string)
    ("found '%s' when expecting '%s'");
enum ExpectedIdentifierParamError = syntaxerr!(string)
    ("identifier expected instead of '%s'");
enum ExpectedIdentifier2paramError = syntaxerr!(string, string)
    ("identifier expected following '%s', not '%s'");
// deprecated // not used
// {
// enum UnterminatedBlockError =
//     err!typeerror("EOF found before closing ']' of block statement");
// }
enum TooManyInVarsError = syntaxerr!(size_t)
    ("only one variable can be declared for 'in', not %d");
enum InExpectedError = syntaxerr!(string)
    ("';' or 'in' expected, not '%s'");
enum GotoLabelExpectedError = syntaxerr!(string)
    ("label expected after goto, not '%s'");
enum TryCatchExpectedError = syntaxerr!()
    ("catch or finally expected following try");
enum StatementExpectedError = syntaxerr!(string)
    ("found '%s' instead of statement");
enum ExpectedExpressionError = syntaxerr!(string)
    ("expression expected, not '%s'");
// deprecated // not used
// {
// enum ObjLiteralInInitializerError =
//     err!typeerror("Object literal in initializer");
// enum LabelAlreadyDefinedError =
//     err!typeerror("label '%s' is already defined");
// }
enum SwitchRedundantCaseError = syntaxerr!(string)
    ("redundant case %s");
enum MisplacedSwitchCaseError = syntaxerr!(string)
    ("case %s: is not in a switch statement");
enum SwitchRedundantDefaultError = syntaxerr!()
    ("redundant default in switch statement");
enum MisplacedSwitchDefaultError = syntaxerr!()
    ("default is not in a switch statement");
enum InitNotExpressionError = syntaxerr!()
    ("init statement must be expression or var");
enum MisplacedBreakError = syntaxerr!()
    ("can only break from within loop or switch");
enum MisplacedContinueError = syntaxerr!()
    ("continue is not in a loop");
enum UndefinedStatementLabelError = syntaxerr!(string)
    ("Statement label '%s' is undefined");
// deprecated // not used
// {
// enum GotoIntoWithError =
//     err!typeerror("cannot goto into with statement");
// }
enum MisplacedReturnError = syntaxerr!()
    ("can only return from within function");
enum NoThrowExpressionError = syntaxerr!()
    ("no expression for throw");
// deprecated // not used
// {
// enum UndefinedObjectSymbolError =
//     err!typeerror("%s.%s is undefined");
// }

//------------------------------------------------------------------------------

enum FunctionWantsNumberError = err!(cTypeError, string, string)
    ("Number.prototype.%s() expects a Number not a %s");
enum FunctionWantsStringError = err!(cTypeError, string, string)
    ("String.prototype.%s() expects a String not a %s");
enum FunctionWantsDateError = err!(cTypeError, string, string)
    ("Date.prototype.%s() expects a Date not a %s");
enum UndefinedNoCall2Error = err!(cTypeError, string, string)
    ("%s %s is undefined and has no Call method");
enum UndefinedNoCall3Error = err!(cTypeError, string, string, string)
    ("%s %s.%s is undefined and has no Call method");
enum FunctionWantsBoolError = err!(cTypeError, string, string)
    ("Boolean.prototype.%s() expects a Boolean not a %s");
enum ArrayLenOutOfBoundsError = err!(RangeError, double)
    ("arg to Array(len) must be 0 .. 2**32-1, not %.16g");
enum ValueOutOfRangeError = err!(RangeError, string, string)
    ("Number.prototype.%s() %s out of range");
enum TypeError = err!(cTypeError, string)
    ("TypeError in %s");
enum RegexpCompileError = err!(SyntaxError, string)
    ("Error compiling regular expression : %s");
enum NotTransferrableError = err!(cTypeError, string)
    ("%s not transferrable");
enum CannotConvertToObject2Error = err!(cTypeError, string, string)
    ("%s %s cannot convert to Object");
enum CannotConvertToObject3Error = err!(cTypeError, string, string, string)
    ("%s %s.%s cannot convert to Object");
enum CannotConvertToObject4Error = err!(cTypeError, string)
    ("cannot convert %s to Object");
enum CannotAssignToError = err!(cReferenceError, string)
    ("cannot assign to %s");
enum CannotEscapeKeywordError = syntaxerr!(string)
    ("escaped expression is not permitted to %s");
enum CannotAssignError = err!(cTypeError, string, string)
    ("cannot assign %s to %s");
enum CannotAssignTo2Error = err!(cTypeError, string, string)
    ("cannot assign to %s.%s");
enum FunctionNotLvalueError = err!cTypeError
    ("cannot assign to function");
enum RhsMustBeObjectError = err!(cTypeError, string, string)
    ("RHS of %s must be an Object, not a %s");
enum CannotPutToPrimitiveError = err!(cTypeError, string, string, string)
    ("can't Put('%s', %s) to a primitive %s");
enum CannotPutIndexToPrimitiveError =
    err!(cTypeError, uint, string, string)
    ("can't Put(%u, %s) to a primitive %s");
enum ObjectCannotBePrimitiveError = err!cTypeError
    ("object cannot be converted to a primitive type");
enum CannotGetFromPrimitiveError = err!(cTypeError, string, string, string)
    ("can't Get(%s) from primitive %s(%s)");
enum CannotGetIndexFromPrimitiveError =
    err!(cTypeError, size_t, string, string)
    ("can't Get(%d) from primitive %s(%s)");
enum PrimitiveNoConstructError = err!(cTypeError, string)
    ("primitive %s has no Construct method");
enum PrimitiveNoCallError = err!(cTypeError, string)
    ("primitive %s has no Call method");
enum ForInMustBeObjectError = err!cTypeError
    ("for-in must be on an object, not a primitive");
enum AssertError = err!(cTypeError, size_t)
    ("assert() line %d");
// deprecated // not used
// {
// enum ObjectNoCallError =
//     err!typeerror("object does not have a [[Call]] property");

// enum SSError =
//     err!typeerror("%s: %s");
// }
enum NoDefaultPutError = err!cTypeError
    ("no Default Put for object");
enum SNoConstructError = err!(cTypeError, string)
    ("%s does not have a [[Construct]] property");
enum SNoCallError = err!(cTypeError, string)
    ("%s does not have a [[Call]] property");
enum SNoInstanceError = err!(cTypeError, string)
    ("%s does not have a [[HasInstance]] property");
enum LengthIntError = err!RangeError
    ("length property must be an integer");
enum TlsNotTransferrableError = err!cTypeError
    ("Array.prototype.toLocaleString() not transferrable");
enum TsNotTransferrableError = err!cTypeError
    ("Function.prototype.toString() not transferrable");
enum ArrayArgsError = err!cTypeError
    ("Function.prototype.apply(): argArray must be array or arguments object");
enum MustBeObjectError = err!(cTypeError, string)
    (".prototype must be an Object, not a %s");
// deprecated // not used
// {
// enum VbarrayExpectedError =
//     err!typeerror("VBArray expected, not a %s");
// enum VbarraySubscriptError =
//     err!typeerror("VBArray subscript out of range");
// enum ActivexError =
//     err!typeerror("Type mismatch");
// enum NoPropertyError =
//     err!typeerror("no property %s");
// enum PutFailedError =
//     err!typeerror("Put of %s failed");
// enum GetFailedError =
//     err!typeerror("Get of %s failed");
// enum NotCollectionError =
//     err!typeerror("argument not a collection");
// }
enum NotValidUTFError = err!(cTypeError, string, string, uint)
    ("%s.%s expects a valid UTF codepoint not \\u%x");
enum UndefinedVarError = err!(cReferenceError, string)
    ("Variable '%s' is not defined");
enum CantBreakInternalError = syntaxerr!(string)
    ("Can't break to internal loop label %s");
// deprecated // not used
// {
// enum EUnexpectedError =
//     err!cTypeError("Unexpected");
// }

enum NoDefaultValueError = err!cTypeError
    ("No [[DefaultValue]]");

enum ReferenceError = err!(cReferenceError, string)
    ("%s");

version (TEST262)
{
    enum HTMLEndCommentError = syntaxerr!()
        ("--> comment does not allowed.");
}

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// needs more proper implementation.
enum CannotPutError = err!(cTypeError)("Cannot put error");
enum CreateDataPropertyError = err!(cTypeError)("Cannot create a property");
enum CreateMethodPropertyError = err!(cTypeError)("Cannot create a method property");
enum NotCallableError = err!(cTypeError, string)
    ("%s is not callable");
enum CantDeleteError = err!(cTypeError, string)
    ("fail to delete %s.");


enum PreventExtensionsFailureError = err!(cTypeError, string)
    ("[%s].PreventExtensions() failed.");

//==============================================================================
private:

//------------------------------------------------------------------------------
//
struct err(alias Ctor, ARGS...)
{
    import dmdscript.value : DError, toDError;
    import dmdscript.opcodes : IR;
    import dmdscript.exception : ScriptException;
    import dmdscript.drealm: Drealm;

    string fmt; //

    //
    @safe @nogc pure nothrow
    this(string fmt)
    {
        this.fmt = fmt;
    }

    //
    @safe
    DError* opCall(Drealm realm, ARGS args, string file = __FILE__,
                   size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(Ctor.Text, fmt.format(args), file, line)
            .toDError!Ctor(realm);
    }
    alias opCall this;

    //
    @safe
    ScriptException toThrow(ARGS args, string file = __FILE__,
                            size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(Ctor.Text, fmt.format(args), file, line);
    }

    // //
    @safe
    ScriptException toThrow(ARGS args, uint linnum, string funcname,
                            string f = __FILE__, size_t l = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(
            Ctor.Text, fmt.format(args), funcname, linnum, f, l);
    }
}

//------------------------------------------------------------------------------
struct syntaxerr(ARGS...)
{
    import dmdscript.exception : ScriptException;

    string fmt; //

    //
    @safe @nogc pure nothrow
    this(string fmt) { this.fmt = fmt; }

    //
    @safe
    ScriptException opCall(ARGS args, uint linnum = 0, string file = __FILE__,
                           size_t line = __LINE__) const
    {
        import std.format : format;

        return new ScriptException(SyntaxError.Text, fmt.format(args), linnum,
                                   file, line);
    }
    alias opCall this;
}

