// File generated by textgen.d
// *** ERROR MESSAGES ***

module dmdscript.errmsgs;

import dmdscript.protoerror;
import dmdscript.script;

private struct err(alias Proto, ARGS...)
{
    import dmdscript.value : DError, toDError;

    d_string fmt;

    @safe @nogc pure nothrow
    this(d_string fmt) { this.fmt = fmt; }

    DError* opCall(ARGS args, Loc linnum = 0, string file = __FILE__,
                   size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), linnum, file, line)
            .toDError!Proto;
    }
    alias opCall this;

    @safe
    ScriptException toThrow(ARGS args, Loc linnum = 0, string file = __FILE__,
                            size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), linnum, file, line);
    }

    @safe
    ScriptException toThrow(ARGS args, d_string sourcename, d_string source,
                            Loc loc, string f = __FILE__,
                            size_t l = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), sourcename, source,
                                   loc, f, l);
    }
}

private struct syntaxerr(ARGS...)
{
    d_string fmt;

    @safe @nogc pure nothrow
    this(d_string fmt) { this.fmt = fmt; }

    @safe
    ScriptException opCall(ARGS args, Loc linnum = 0, string file = __FILE__,
                           size_t line = __LINE__) const
    {
        import std.format : format;
        return new ScriptException(fmt.format(args), linnum, file, line);
    }

    alias opCall this;
}

enum RuntimePrefixError =
    err!typeerror("DMDScript fatal runtime error: ");
enum ComNoDefaultValueError =
    err!typeerror("No default value for COM object");
enum ComNoConstructPropertyError =
    err!typeerror("%s does not have a [[Construct]] property");
enum DispETypemismatchError =
    err!typeerror("argument type mismatch for %s");
enum DispEBadparamcountError =
    err!typeerror("wrong number of arguments for %s");
enum ComFunctionErrororError =
    err!typeerror("%s Invoke() fails with COM error %x");
enum ComObjectErrororError =
    err!typeerror("Dcomobject: %s.%s fails with COM error %x");
enum BadSwitchError = syntaxerr!(d_string)
    ("unrecognized switch '%s'");
enum UndefinedLabelError = syntaxerr!(d_string, d_string)
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
enum StringNoEndQuoteError = syntaxerr!(tchar)
    ("string is missing an end quote %s");
enum UnterminatedStringError = syntaxerr!()
    ("end of file before end of string");
enum BadUSequenceError = syntaxerr!()
    ("\\u sequence must be followed by 4 hex characters");
enum UnrecognizedNLiteralError = syntaxerr!()
    ("unrecognized numeric literal");
enum FplExpectedIdentifierError = syntaxerr!(d_string)
    ("Identifier expected in FormalParameterList, not %s");
enum FplExpectedCommaError = syntaxerr!(d_string)
    ("comma expected in FormalParameterList, not %s");
enum ExpectedIdentifierError = syntaxerr!()
    ("identifier expected");
enum ExpectedGenericError = syntaxerr!(d_string, d_string)
    ("found '%s' when expecting '%s'");
enum ExpectedIdentifierParamError = syntaxerr!(d_string)
    ("identifier expected instead of '%s'");
enum ExpectedIdentifier2paramError = syntaxerr!(d_string, d_string)
    ("identifier expected following '%s', not '%s'");
enum UnterminatedBlockError =
    err!typeerror("EOF found before closing ']' of block statement");
enum TooManyInVarsError = syntaxerr!(size_t)
    ("only one variable can be declared for 'in', not %d");
enum InExpectedError = syntaxerr!(d_string)
    ("';' or 'in' expected, not '%s'");
enum GotoLabelExpectedError = syntaxerr!(d_string)
    ("label expected after goto, not '%s'");
enum TryCatchExpectedError = syntaxerr!()
    ("catch or finally expected following try");
enum StatementExpectedError = syntaxerr!(d_string)
    ("found '%s' instead of statement");
enum ExpectedExpressionError = syntaxerr!(d_string)
    ("expression expected, not '%s'");
enum ObjLiteralInInitializerError =
    err!typeerror("Object literal in initializer");
enum LabelAlreadyDefinedError =
    err!typeerror("label '%s' is already defined");
enum SwitchRedundantCaseError = syntaxerr!(d_string)
    ("redundant case %s");
enum MisplacedSwitchCaseError = syntaxerr!(d_string)
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
enum UndefinedStatementLabelError = syntaxerr!(d_string)
    ("Statement label '%s' is undefined");
enum GotoIntoWithError =
    err!typeerror("cannot goto into with statement");
enum MisplacedReturnError = syntaxerr!()
    ("can only return from within function");
enum NoThrowExpressionError = syntaxerr!()
    ("no expression for throw");
enum UndefinedObjectSymbolError =
    err!typeerror("%s.%s is undefined");
enum FunctionWantsNumberError = err!(typeerror, d_string, d_string)
    ("Number.prototype.%s() expects a Number not a %s");
enum FunctionWantsStringError = err!(typeerror, d_string, d_string)
    ("String.prototype.%s() expects a String not a %s");
enum FunctionWantsDateError = err!(typeerror, d_string, d_string)
    ("Date.prototype.%s() expects a Date not a %s");
enum UndefinedNoCall2Error = err!(typeerror, d_string, d_string)
    ("%s %s is undefined and has no Call method");
enum UndefinedNoCall3Error = err!(typeerror, d_string, d_string, d_string)
    ("%s %s.%s is undefined and has no Call method");
enum FunctionWantsBoolError = err!(typeerror, d_string, d_string)
    ("Boolean.prototype.%s() expects a Boolean not a %s");
enum ArrayLenOutOfBoundsError = err!(rangeerror, d_number)
    ("arg to Array(len) must be 0 .. 2**32-1, not %.16g");
enum ValueOutOfRangeError = err!(rangeerror, d_string, d_string)
    ("Number.prototype.%s() %s out of range");
enum TypeError = err!(typeerror, d_string)
    ("TypeError in %s");
enum RegexpCompileError = err!syntaxerror
    ("Error compiling regular expression");
enum NotTransferrableError = err!(typeerror, d_string)
    ("%s not transferrable");
enum CannotConvertToObject2Error = err!(typeerror, d_string, d_string)
    ("%s %s cannot convert to Object");
enum CannotConvertToObject3Error = err!(typeerror, d_string, d_string, d_string)
    ("%s %s.%s cannot convert to Object");
enum CannotConvertToObject4Error = err!(typeerror, d_string)
    ("cannot convert %s to Object");
enum CannotAssignToError = err!(typeerror, d_string)
    ("cannot assign to %s");
enum CannotAssignError = err!(typeerror, d_string, d_string)
    ("cannot assign %s to %s");
enum CannotAssignTo2Error = err!(typeerror, d_string, d_string)
    ("cannot assign to %s.%s");
enum FunctionNotLvalueError =
    err!typeerror("cannot assign to function");
enum RhsMustBeObjectError = err!(typeerror, d_string, d_string)
    ("RHS of %s must be an Object, not a %s");
enum CannotPutToPrimitiveError = err!(typeerror, d_string, d_string, d_string)
    ("can't Put('%s', %s) to a primitive %s");
enum CannotPutIndexToPrimitiveError =
    err!(typeerror, d_uint32, d_string, d_string)
    ("can't Put(%u, %s) to a primitive %s");
enum ObjectCannotBePrimitiveError = err!typeerror
    ("object cannot be converted to a primitive type");
enum CannotGetFromPrimitiveError = err!(typeerror, d_string, d_string, d_string)
    ("can't Get(%s) from primitive %s(%s)");
enum CannotGetIndexFromPrimitiveError =
    err!(typeerror, size_t, d_string, d_string)
    ("can't Get(%d) from primitive %s(%s)");
enum PrimitiveNoConstructError = err!(typeerror, d_string)
    ("primitive %s has no Construct method");
enum PrimitiveNoCallError = err!(typeerror, d_string)
    ("primitive %s has no Call method");
enum ForInMustBeObjectError = err!typeerror
    ("for-in must be on an object, not a primitive");
enum AssertError = err!(typeerror, size_t)
    ("assert() line %d");
enum ObjectNoCallError =
    err!typeerror("object does not have a [[Call]] property");
enum SSError =
    err!typeerror("%s: %s");
enum NoDefaultPutError =
    err!typeerror("no Default Put for object");
enum SNoConstructError = err!(typeerror, d_string)
    ("%s does not have a [[Construct]] property");
enum SNoCallError = err!(typeerror, d_string)
    ("%s does not have a [[Call]] property");
enum SNoInstanceError = err!(typeerror, d_string)
    ("%s does not have a [[HasInstance]] property");
enum LengthIntError =
    err!rangeerror("length property must be an integer");
enum TlsNotTransferrableError =
    err!typeerror("Array.prototype.toLocaleString() not transferrable");
enum TsNotTransferrableError =
    err!typeerror("Function.prototype.toString() not transferrable");
enum ArrayArgsError = err!typeerror
    ("Function.prototype.apply(): argArray must be array or arguments object");
enum MustBeObjectError = err!(typeerror, d_string)
    (".prototype must be an Object, not a %s");
enum VbarrayExpectedError =
    err!typeerror("VBArray expected, not a %s");
enum VbarraySubscriptError =
    err!typeerror("VBArray subscript out of range");
enum ActivexError =
    err!typeerror("Type mismatch");
enum NoPropertyError =
    err!typeerror("no property %s");
enum PutFailedError =
    err!typeerror("Put of %s failed");
enum GetFailedError =
    err!typeerror("Get of %s failed");
enum NotCollectionError =
    err!typeerror("argument not a collection");
enum NotValidUTFError = err!(typeerror, d_string, d_string, uint)
    ("%s.%s expects a valid UTF codepoint not \\u%x");
enum UndefinedVarError = err!(referenceerror, d_string)
    ("Variable '%s' is not defined");
enum CantBreakInternalError = syntaxerr!(d_string)
    ("Can't break to internal loop label %s");
enum EUnexpectedError =
    err!typeerror("Unexpected");

enum NoDefaultValueError =
    err!typeerror("No [[DefaultValue]]");

enum ReferenceError = err!(referenceerror, d_string)
    ("%s");
