// File generated by textgen.d
// *** ERROR MESSAGES ***

module dmdscript.errmsgs;

import dmdscript.protoerror;
import dmdscript.primitive : char_t, string_t;

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
enum BadSwitchError = syntaxerr!(string_t)
    ("unrecognized switch '%s'");
enum UndefinedLabelError = syntaxerr!(string_t, string_t)
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
enum StringNoEndQuoteError = syntaxerr!(char_t)
    ("string is missing an end quote %s");
enum UnterminatedStringError = syntaxerr!()
    ("end of file before end of string");
enum BadUSequenceError = syntaxerr!()
    ("\\u sequence must be followed by 4 hex characters");
enum UnrecognizedNLiteralError = syntaxerr!()
    ("unrecognized numeric literal");
enum FplExpectedIdentifierError = syntaxerr!(string_t)
    ("Identifier expected in FormalParameterList, not %s");
enum FplExpectedCommaError = syntaxerr!(string_t)
    ("comma expected in FormalParameterList, not %s");
enum ExpectedIdentifierError = syntaxerr!()
    ("identifier expected");
enum ExpectedGenericError = syntaxerr!(string_t, string_t)
    ("found '%s' when expecting '%s'");
enum ExpectedIdentifierParamError = syntaxerr!(string_t)
    ("identifier expected instead of '%s'");
enum ExpectedIdentifier2paramError = syntaxerr!(string_t, string_t)
    ("identifier expected following '%s', not '%s'");
// deprecated // not used
// {
// enum UnterminatedBlockError =
//     err!typeerror("EOF found before closing ']' of block statement");
// }
enum TooManyInVarsError = syntaxerr!(size_t)
    ("only one variable can be declared for 'in', not %d");
enum InExpectedError = syntaxerr!(string_t)
    ("';' or 'in' expected, not '%s'");
enum GotoLabelExpectedError = syntaxerr!(string_t)
    ("label expected after goto, not '%s'");
enum TryCatchExpectedError = syntaxerr!()
    ("catch or finally expected following try");
enum StatementExpectedError = syntaxerr!(string_t)
    ("found '%s' instead of statement");
enum ExpectedExpressionError = syntaxerr!(string_t)
    ("expression expected, not '%s'");
// deprecated // not used
// {
// enum ObjLiteralInInitializerError =
//     err!typeerror("Object literal in initializer");
// enum LabelAlreadyDefinedError =
//     err!typeerror("label '%s' is already defined");
// }
enum SwitchRedundantCaseError = syntaxerr!(string_t)
    ("redundant case %s");
enum MisplacedSwitchCaseError = syntaxerr!(string_t)
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
enum UndefinedStatementLabelError = syntaxerr!(string_t)
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
enum FunctionWantsNumberError = err!(typeerror, string_t, string_t)
    ("Number.prototype.%s() expects a Number not a %s");
enum FunctionWantsStringError = err!(typeerror, string_t, string_t)
    ("String.prototype.%s() expects a String not a %s");
enum FunctionWantsDateError = err!(typeerror, string_t, string_t)
    ("Date.prototype.%s() expects a Date not a %s");
enum UndefinedNoCall2Error = err!(typeerror, string_t, string_t)
    ("%s %s is undefined and has no Call method");
enum UndefinedNoCall3Error = err!(typeerror, string_t, string_t, string_t)
    ("%s %s.%s is undefined and has no Call method");
enum FunctionWantsBoolError = err!(typeerror, string_t, string_t)
    ("Boolean.prototype.%s() expects a Boolean not a %s");
enum ArrayLenOutOfBoundsError = err!(rangeerror, double)
    ("arg to Array(len) must be 0 .. 2**32-1, not %.16g");
enum ValueOutOfRangeError = err!(rangeerror, string_t, string_t)
    ("Number.prototype.%s() %s out of range");
enum TypeError = err!(typeerror, string_t)
    ("TypeError in %s");
enum RegexpCompileError = err!syntaxerror
    ("Error compiling regular expression");
enum NotTransferrableError = err!(typeerror, string_t)
    ("%s not transferrable");
enum CannotConvertToObject2Error = err!(typeerror, string_t, string_t)
    ("%s %s cannot convert to Object");
enum CannotConvertToObject3Error = err!(typeerror, string_t, string_t, string_t)
    ("%s %s.%s cannot convert to Object");
enum CannotConvertToObject4Error = err!(typeerror, string_t)
    ("cannot convert %s to Object");
enum CannotAssignToError = err!(typeerror, string_t)
    ("cannot assign to %s");
enum CannotAssignError = err!(typeerror, string_t, string_t)
    ("cannot assign %s to %s");
enum CannotAssignTo2Error = err!(typeerror, string_t, string_t)
    ("cannot assign to %s.%s");
enum FunctionNotLvalueError = err!typeerror
    ("cannot assign to function");
enum RhsMustBeObjectError = err!(typeerror, string_t, string_t)
    ("RHS of %s must be an Object, not a %s");
enum CannotPutToPrimitiveError = err!(typeerror, string_t, string_t, string_t)
    ("can't Put('%s', %s) to a primitive %s");
enum CannotPutIndexToPrimitiveError =
    err!(typeerror, uint, string_t, string_t)
    ("can't Put(%u, %s) to a primitive %s");
enum ObjectCannotBePrimitiveError = err!typeerror
    ("object cannot be converted to a primitive type");
enum CannotGetFromPrimitiveError = err!(typeerror, string_t, string_t, string_t)
    ("can't Get(%s) from primitive %s(%s)");
enum CannotGetIndexFromPrimitiveError =
    err!(typeerror, size_t, string_t, string_t)
    ("can't Get(%d) from primitive %s(%s)");
enum PrimitiveNoConstructError = err!(typeerror, string_t)
    ("primitive %s has no Construct method");
enum PrimitiveNoCallError = err!(typeerror, string_t)
    ("primitive %s has no Call method");
enum ForInMustBeObjectError = err!typeerror
    ("for-in must be on an object, not a primitive");
enum AssertError = err!(typeerror, size_t)
    ("assert() line %d");
// deprecated // not used
// {
// enum ObjectNoCallError =
//     err!typeerror("object does not have a [[Call]] property");

// enum SSError =
//     err!typeerror("%s: %s");
// }
enum NoDefaultPutError = err!typeerror
    ("no Default Put for object");
enum SNoConstructError = err!(typeerror, string_t)
    ("%s does not have a [[Construct]] property");
enum SNoCallError = err!(typeerror, string_t)
    ("%s does not have a [[Call]] property");
enum SNoInstanceError = err!(typeerror, string_t)
    ("%s does not have a [[HasInstance]] property");
enum LengthIntError = err!rangeerror
    ("length property must be an integer");
enum TlsNotTransferrableError = err!typeerror
    ("Array.prototype.toLocaleString() not transferrable");
enum TsNotTransferrableError = err!typeerror
    ("Function.prototype.toString() not transferrable");
enum ArrayArgsError = err!typeerror
    ("Function.prototype.apply(): argArray must be array or arguments object");
enum MustBeObjectError = err!(typeerror, string_t)
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
enum NotValidUTFError = err!(typeerror, string_t, string_t, uint)
    ("%s.%s expects a valid UTF codepoint not \\u%x");
enum UndefinedVarError = err!(referenceerror, string_t)
    ("Variable '%s' is not defined");
enum CantBreakInternalError = syntaxerr!(string_t)
    ("Can't break to internal loop label %s");
// deprecated // not used
// {
// enum EUnexpectedError =
//     err!typeerror("Unexpected");
// }

enum NoDefaultValueError = err!typeerror
    ("No [[DefaultValue]]");

enum ReferenceError = err!(referenceerror, string_t)
    ("%s");

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// needs more proper implementation.
enum CannotPutError = err!(typeerror)("Cannot put error");
enum CreateDataPropertyError = err!(typeerror)("Cannot create a property");
enum CreateMethodPropertyError = err!(typeerror)("Cannot create a method property");
enum NotCallableError = err!(typeerror, string_t)
    ("%s is not callable");
enum CantDeleteError = err!(typeerror, string_t)
    ("fail to delete %s.");


//==============================================================================
private:

//------------------------------------------------------------------------------
//
struct err(alias Proto, ARGS...)
{
    import dmdscript.value : DError, toDError;
    import dmdscript.opcodes : IR;
    import dmdscript.exception : ScriptException;

    string_t fmt; //

    //
    @safe @nogc pure nothrow
    this(string_t fmt)
    {
        this.fmt = fmt;
    }

    //
    @safe
    DError* opCall(ARGS args, string file = __FILE__,
                   size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), file, line)
            .toDError!Proto;
    }
    alias opCall this;

    //
    @safe
    ScriptException toThrow(ARGS args, string file = __FILE__,
                            size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), file, line);
    }

    //
    @safe
    ScriptException toThrow(ARGS args, string_t sourcename, string_t source,
                            uint linnum, string f = __FILE__,
                            size_t l = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), sourcename, source,
                                   linnum, f, l);
    }
}

//------------------------------------------------------------------------------
struct syntaxerr(ARGS...)
{
    import dmdscript.exception : ScriptException;

    string_t fmt; //

    //
    @safe @nogc pure nothrow
    this(string_t fmt) { this.fmt = fmt; }

    //
    @safe
    ScriptException opCall(ARGS args, uint linnum = 0, string file = __FILE__,
                           size_t line = __LINE__) const
    {
        import std.format : format;

        return new ScriptException(fmt.format(args), linnum, file, line);
    }
    alias opCall this;
}

