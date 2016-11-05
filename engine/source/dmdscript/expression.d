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

module dmdscript.expression;

// import std.string;
// import std.algorithm;
// import std.string;
// import std.range;
// import std.exception;
// import std.ascii;

import dmdscript.script;
import dmdscript.lexer;
import dmdscript.scopex;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.irstate;
import dmdscript.ir;
import dmdscript.opcodes;
import dmdscript.identifier;

debug import std.stdio;

/******************************** Expression **************************/

class Expression
{
    enum uint EXPRESSION_SIGNATURE = 0x3AF31E3F;
    uint signature = EXPRESSION_SIGNATURE;

    Loc loc;                    // file location
    TOK op;

    this(Loc loc, TOK op)
    {
        this.loc = loc;
        this.op = op;
        signature = EXPRESSION_SIGNATURE;
    }

    invariant()
    {
        assert(signature == EXPRESSION_SIGNATURE);
        assert(op != TOKreserved && op < TOKmax);
    }

    /**************************
     * Semantically analyze Expression.
     * Determine types, fold constants, e
     */

    Expression semantic(Scope* sc)
    {
        return this;
    }

    override d_string toString()
    {
        import std.exception : assumeUnique;
        char[] buf;

        toBuffer(buf);
        return assumeUnique(buf);
    }

    void toBuffer(ref char[] buf)
    {
        buf ~= toString();
    }

    void checkLvalue(Scope* sc)
    {
        import std.format : format;
        d_string buf;

        //writefln("checkLvalue(), op = %d", op);
        if(sc.funcdef)
        {
            if(sc.funcdef.isAnonymous)
                buf = "anonymous";
            else if(sc.funcdef.name)
                buf = sc.funcdef.name.toString();
        }
        buf ~= format("(%d) : Error: ", loc);
        buf ~= format(Err.CannotAssignTo, toString);

        if(!sc.errinfo.message)
        {
            sc.errinfo.message = buf;
            sc.errinfo.linnum = loc;
            sc.errinfo.srcline = Lexer.locToSrcline(sc.getSource().ptr, loc);
        }
    }

    // Do we match for purposes of optimization?

    bool match(Expression e)
    {
        return false;
    }

    // Is the result of the expression guaranteed to be a boolean?

    bool isBooleanResult()
    {
        return false;
    }

    void toIR(IRstate* irs, idx_t ret)
    {
        debug writef("Expression::toIR('%s')\n", toString());
    }

    void toLvalue(IRstate* irs, out idx_t base, IR* property,
                  out OpOffset opoff)
    {
        base = irs.alloc(1);
        toIR(irs, base);
        property.index = 0;
        opoff = OpOffset.V;
    }
}

/******************************** RealExpression **************************/

class RealExpression : Expression
{
    real_t value;

    this(Loc loc, real_t value)
    {
        super(loc, TOKreal);
        this.value = value;
    }

    override d_string toString()
    {
        import std.format : format;

        d_string buf;
        long i;

        i = cast(long)value;
        if(i == value)
            buf = format("%d", i);
        else
            buf = format("%g", value);
        return buf;
    }

    override void toBuffer(ref tchar[] buf)
    {
        import std.format : format;

        buf ~= format("%g", value);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        //writef("RealExpression::toIR(%g)\n", value);

        if(ret)
            irs.gen_!(Opcode.Number)(loc, ret, value);
    }
}

/******************************** IdentifierExpression **************************/

class IdentifierExpression : Expression
{
    Identifier* ident;

    this(Loc loc, Identifier*  ident)
    {
        super(loc, TOKidentifier);
        this.ident = ident;
    }

    override Expression semantic(Scope* sc)
    {
        return this;
    }

    override d_string toString()
    {
        return ident.toString();
    }

    override void checkLvalue(Scope* sc)
    {
    }

    override bool match(Expression e)
    {
        if(e.op != TOKidentifier)
            return 0;

        IdentifierExpression ie = cast(IdentifierExpression)(e);

        return ident == ie.ident;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        // Identifier* id = ident;

        // assert(id.sizeof == uint.sizeof);
        if(ret)
            irs.gen_!(Opcode.GetScope)(loc, ret, ident);
        else
            irs.gen_!(Opcode.CheckRef)(loc, ident);
    }

    override void toLvalue(IRstate* irs, out idx_t base, IR* property,
                           out OpOffset opoff)
    {
        //irs.gen1(loc, IRthis, base);
        property.id = ident;
        opoff = OpOffset.Scope;
        base = ~0u;
    }
}

/******************************** ThisExpression **************************/

class ThisExpression : Expression
{
    this(Loc loc)
    {
        super(loc, TOKthis);
    }

    override d_string toString()
    {
        return TEXT_this;
    }

    override Expression semantic(Scope* sc)
    {
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        if(ret)
            irs.gen_!(Opcode.This)(loc, ret);
    }
}

/******************************** NullExpression **************************/

class NullExpression : Expression
{
    this(Loc loc)
    {
        super(loc, TOKnull);
    }

    override d_string toString()
    {
        return TEXT_null;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        if(ret)
            irs.gen_!(Opcode.Null)(loc, ret);
    }
}

/******************************** StringExpression **************************/

class StringExpression : Expression
{
    private d_string str;

    this(Loc loc, d_string str)
    {
        //writefln("StringExpression('%s')", string);
        super(loc, TOKstring);
        this.str = str;
    }

    override void toBuffer(ref tchar[] buf)
    {
        import std.format : format;
        import std.ascii : isPrintable;

        buf ~= '"';
        foreach(dchar c; str)
        {
            switch(c)
            {
            case '"':
                buf ~= '\\';
                goto Ldefault;

            default:
                Ldefault:
                if(c & ~0xFF)
                    buf ~= format("\\u%04x", c);
                else if(isPrintable(c))
                    buf ~= cast(tchar)c;
                else
                    buf ~= format("\\x%02x", c);
                break;
            }
        }
        buf ~= '"';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        if(ret)
            irs.gen_!(Opcode.String)(loc, ret, Identifier.build(str));
    }
}

/******************************** RegExpLiteral **************************/

class RegExpLiteral : Expression
{
    private d_string str;

    this(Loc loc, d_string str)
    {
        //writefln("RegExpLiteral('%s')", string);
        super(loc, TOKregexp);
        this.str = str;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= str;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        import std.string : lastIndexOf;
        d_string pattern;
        d_string attribute = null;
        int e;

        uint argc;
        uint argv;
        uint b;

        // Regular expression is of the form:
        //	/pattern/attribute

        // Parse out pattern and attribute strings
        assert(str[0] == '/');
        e = lastIndexOf(str, '/');
        assert(e != -1);
        pattern = str[1 .. e];
        argc = 1;
        if(e + 1 < str.length)
        {
            attribute = str[e + 1 .. $];
            argc++;
        }

        // Generate new Regexp(pattern [, attribute])

        b = irs.alloc(1);
        Identifier* re = Identifier.build(TEXT_RegExp);
        irs.gen_!(Opcode.GetScope)(loc, b, re);
        argv = irs.alloc(argc);
        irs.gen_!(Opcode.String)(loc, argv, Identifier.build(pattern));
        if(argc == 2)
            irs.gen_!(Opcode.String)(loc, argv + 1,
                                     Identifier.build(attribute));
        irs.gen_!(Opcode.New)(loc, ret, b, argc, argv);
        irs.release(b, argc + 1);
    }
}

/******************************** BooleanExpression **************************/

class BooleanExpression : Expression
{
    int boolean;

    this(Loc loc, int boolean)
    {
        super(loc, TOKboolean);
        this.boolean = boolean;
    }

    override d_string toString()
    {
        return boolean ? "true" : "false";
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= toString();
    }

    override bool isBooleanResult()
    {
        return true;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        if(ret)
            irs.gen_!(Opcode.Boolean)(loc, ret, boolean);
    }
}

/******************************** ArrayLiteral **************************/

class ArrayLiteral : Expression
{
    Expression[] elements;

    this(Loc loc, Expression[] elements)
    {
        super(loc, TOKarraylit);
        this.elements = elements;
    }

    override Expression semantic(Scope* sc)
    {
        foreach(ref Expression e; elements)
        {
            if(e)
                e = e.semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        buf ~= '[';
        foreach(Expression e; elements)
        {
            if(i)
                buf ~= ',';
            i = 1;
            if(e)
                e.toBuffer(buf);
        }
        buf ~= ']';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        size_t argc;
        idx_t argv;
        idx_t b;
        idx_t v;

        b = irs.alloc(1);
        static Identifier* ar;
        if(!ar)
            ar = Identifier.build(TEXT_Array);
        irs.gen_!(Opcode.GetScope)(loc, b, ar);
        if(elements.length)
        {
            Expression e;

            argc = elements.length;
            argv = irs.alloc(argc);
            if(argc > 1)
            {
                uint i;

                // array literal [a, b, c] is equivalent to:
                //	new Array(a,b,c)
                for(i = 0; i < argc; i++)
                {
                    e = elements[i];
                    if(e)
                    {
                        e.toIR(irs, argv + i);
                    }
                    else
                        irs.gen_!(Opcode.Undefined)(loc, argv + i);
                }
                irs.gen_!(Opcode.New)(loc, ret, b, argc, argv);
            }
            else
            {   //	[a] translates to:
                //	ret = new Array(1);
                //  ret[0] = a

                irs.gen_!(Opcode.Number)(loc, argv, 1.0);
                irs.gen_!(Opcode.New)(loc, ret, b, argc, argv);

                e = elements[0];
                v = irs.alloc(1);
                if(e)
                    e.toIR(irs, v);
                else
                    irs.gen_!(Opcode.Undefined)(loc, v);
                irs.gen_!(Opcode.PutS)(loc, v, ret, Identifier.build(TEXT_0));
                irs.release(v, 1);
            }
            irs.release(argv, argc);
        }
        else
        {
            // Generate new Array()
            irs.gen_!(Opcode.New)(loc, ret, b, 0, 0);
        }
        irs.release(b, 1);
    }
}

/******************************** FieldLiteral **************************/

class Field
{
    Identifier* ident;
    Expression exp;

    this(Identifier*  ident, Expression exp)
    {
        this.ident = ident;
        this.exp = exp;
    }
}

/******************************** ObjectLiteral **************************/

class ObjectLiteral : Expression
{
    Field[] fields;

    this(Loc loc, Field[] fields)
    {
        super(loc, TOKobjectlit);
        this.fields = fields;
    }

    override Expression semantic(Scope* sc)
    {
        foreach(Field f; fields)
        {
            f.exp = f.exp.semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        buf ~= '{';
        foreach(Field f; fields)
        {
            if(i)
                buf ~= ',';
            i = 1;
            buf ~= f.ident.toString();
            buf ~= ':';
            f.exp.toBuffer(buf);
        }
        buf ~= '}';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t b;

        b = irs.alloc(1);
        //irs.gen2(loc, IRstring, b, TEXT_Object);
        irs.gen_!(Opcode.GetScope)(loc, b, Identifier.build(TEXT_Object));
        // Generate new Object()
        irs.gen_!(Opcode.New)(loc, ret, b, 0, 0);
        if(fields.length)
        {
            uint x;

            x = irs.alloc(1);
            foreach(Field f; fields)
            {
                f.exp.toIR(irs, x);
                irs.gen_!(Opcode.PutS)(loc, x, ret, f.ident);
            }
        }
    }
}

/******************************** FunctionLiteral **************************/

class FunctionLiteral : Expression
{
    FunctionDefinition func;

    this(Loc loc, FunctionDefinition func)
    {
        super(loc, TOKobjectlit);
        this.func = func;
    }

    override Expression semantic(Scope* sc)
    {
        func = cast(FunctionDefinition)(func.semantic(sc));
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        func.toBuffer(buf);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        func.toIR(null);
        irs.gen_!(Opcode.Object)(loc, ret, func);
    }
}

/***************************** UnaExp *************************************/

class UnaExp : Expression
{
    Expression e1;

    this(Loc loc, TOK op, Expression e1)
    {
        super(loc, op);
        this.e1 = e1;
    }

    override Expression semantic(Scope* sc)
    {
        e1 = e1.semantic(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= Token.toString(op);
        buf ~= ' ';
        e1.toBuffer(buf);
    }
}

/***************************** BinExp *************************************/

class BinExp : Expression
{
    Expression e1;
    Expression e2;

    this(Loc loc, TOK op, Expression e1, Expression e2)
    {
        super(loc, op);
        this.e1 = e1;
        this.e2 = e2;
    }

    override Expression semantic(Scope* sc)
    {
        e1 = e1.semantic(sc);
        e2 = e2.semantic(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= ' ';
        buf ~= Token.toString(op);
        buf ~= ' ';
        e2.toBuffer(buf);
    }

    void binIR(IRstate* irs, idx_t ret, Opcode ircode)
    {
        idx_t b;
        idx_t c;

        if(ret)
        {
            b = irs.alloc(1);
            e1.toIR(irs, b);
            if(e1.match(e2))
            {
                irs.gen_!GenIR3(loc, ircode, ret, b, b);
            }
            else
            {
                c = irs.alloc(1);
                e2.toIR(irs, c);
                irs.gen_!GenIR3(loc, ircode, ret, b, c);
                irs.release(c, 1);
            }
            irs.release(b, 1);
        }
        else
        {
            e1.toIR(irs, 0);
            e2.toIR(irs, 0);
        }
    }
}

/************************************************************/

/* Handle ++e and --e
 */

class PreExp : UnaExp
{
    Opcode ircode;

    this(Loc loc, Opcode ircode, Expression e)
    {
        super(loc, TOKplusplus, e);
        this.ircode = ircode;
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;
        IR property;
        OpOffset opoff;

        //writef("PreExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        final switch(opoff)
        {
        case OpOffset.None:
            irs.gen_!GenIR3(loc, ircode, ret, base, property.index);
            break;
        case OpOffset.S:
            irs.gen_!GenIR3S(loc, cast(Opcode)(ircode + opoff),
                             ret, base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen_!GenIRScope3(loc, cast(Opcode)(ircode + opoff),
                                 ret, property.id, property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }
}

/************************************************************/

class PostIncExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKplusplus, e);
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;
        IR property;
        OpOffset opoff;

        //writef("PostIncExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        final switch(opoff)
        {
        case OpOffset.None:
            if (ret)
                irs.gen_!(Opcode.PostInc)(loc, ret, base, property.index);
            else
                irs.gen_!(Opcode.PreInc)(loc, ret, base, property.index);
            break;
        case OpOffset.S:
            if (ret)
                irs.gen_!(Opcode.PostIncS)(loc, ret, base, property.id);
            else
                irs.gen_!(Opcode.PreIncS)(loc, ret, base, property.id);
            break;
        case OpOffset.Scope:
            if (ret)
                irs.gen_!(Opcode.PostIncScope)(loc, ret, property.id);
            else
                irs.gen_!(Opcode.PreIncScope)(loc, ret, property.id,
                                              property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }
}

/****************************************************************/

class PostDecExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKplusplus, e);
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;
        IR property;
        OpOffset opoff;

        //writef("PostDecExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        final switch(opoff)
        {
        case OpOffset.None:
            if (ret)
                irs.gen_!(Opcode.PostDec)(loc, ret, base, property.index);
            else
                irs.gen_!(Opcode.PreDec)(loc, ret, base, property.index);
            break;
        case OpOffset.S:
            if (ret)
                irs.gen_!(Opcode.PostDecS)(loc, ret, base, property.id);
            else
                irs.gen_!(Opcode.PreDecS)(loc, ret, base, property.id);
            break;
        case OpOffset.Scope:
            if (ret)
                irs.gen_!(Opcode.PostDecScope)(loc, ret, property.id);
            else
                irs.gen_!(Opcode.PreDecScope)(loc, ret, property.id,
                                              property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }
}

/************************************************************/

class DotExp : UnaExp
{
    Identifier* ident;

    this(Loc loc, Expression e, Identifier*  ident)
    {
        super(loc, TOKdot, e);
        this.ident = ident;
    }

    override void checkLvalue(Scope* sc)
    {
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '.';
        buf ~= ident.toString();
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;

        //writef("DotExp::toIR('%s')\n", toChars());
        version(all)
        {
            // Some test cases depend on things like:
            //		foo.bar;
            // generating a property get even if the result is thrown away.
            base = irs.alloc(1);
            e1.toIR(irs, base);
            irs.gen_!(Opcode.GetS)(loc, ret, base, ident);
        }
        else
        {
            if(ret)
            {
                base = irs.alloc(1);
                e1.toIR(irs, base);
                irs.gen_!(Opcode.GetS)(loc, ret, base, ident);
            }
            else
                e1.toIR(irs, 0);
        }
    }

    override void toLvalue(IRstate* irs, out idx_t base, IR* property,
                           out OpOffset opoff)
    {
        base = irs.alloc(1);
        e1.toIR(irs, base);
        property.id = ident;
        opoff = OpOffset.S;
    }
}

/************************************************************/

class CallExp : UnaExp
{
    Expression[] arguments;

    this(Loc loc, Expression e, Expression[] arguments)
    {
        //writef("CallExp(e1 = %x)\n", e);
        super(loc, TOKcall, e);
        this.arguments = arguments;
    }

    override Expression semantic(Scope* sc)
    {
        IdentifierExpression ie;

        //writef("CallExp(e1=%x, %d, vptr=%x)\n", e1, e1.op, *(uint *)e1);
        //writef("CallExp(e1='%s')\n", e1.toString());
        e1 = e1.semantic(sc);
        /*if(e1.op != TOKcall)
            e1.checkLvalue(sc);
*/
        foreach(ref Expression e; arguments)
        {
            e = e.semantic(sc);
        }
        if(arguments.length == 1)
        {
            if(e1.op == TOKidentifier)
            {
                ie = cast(IdentifierExpression )e1;
                if(ie.ident.toString() == "assert")
                {
                    return new AssertExp(loc, arguments[0]);
                }
            }
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '(';
        for(size_t u = 0; u < arguments.length; u++)
        {
            if(u)
                buf ~= ", ";
            arguments[u].toBuffer(buf);
        }
        buf ~= ')';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        // ret = base.property(argc, argv)
        // CALL ret,base,property,argc,argv
        idx_t base;
        size_t argc;
        idx_t argv;
        IR property;
        OpOffset opoff;

        //writef("CallExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);

        if(arguments.length)
        {
            uint u;

            argc = arguments.length;
            argv = irs.alloc(argc);
            for(u = 0; u < argc; u++)
            {
                Expression e;

                e = arguments[u];
                e.toIR(irs, argv + u);
            }
            arguments[] = null;         // release to GC
            arguments = null;
        }
        else
        {
            argc = 0;
            argv = 0;
        }

        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen_!(Opcode.Call)(loc, ret, base, property.index, argc, argv);
            break;
        case OpOffset.S:
            irs.gen_!(Opcode.CallS)(loc, ret, base, property.id, argc, argv);
            break;
        case OpOffset.Scope:
            irs.gen_!(Opcode.CallScope)(loc, ret, property.id, argc, argv);
            break;
        case OpOffset.V:
            irs.gen_!(Opcode.CallV)(loc, ret, base, argc, argv);
            break;
        }
        irs.release(argv, argc);
    }
}
/************************************************************/

class AssertExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKassert, e);
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "assert(";
        e1.toBuffer(buf);
        buf ~= ')';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        Loc linnum;
        size_t u;
        idx_t b;

        b = ret ? ret : irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen_!(Opcode.JT)(loc, 0, b);
        linnum = cast(Loc)loc;
        irs.gen_!(Opcode.Assert)(loc, linnum);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* NewExp ***********************************/

class NewExp : UnaExp
{
    Expression[] arguments;

    this(Loc loc, Expression e, Expression[] arguments)
    {
        super(loc, TOKnew, e);
        this.arguments = arguments;
    }

    override Expression semantic(Scope* sc)
    {
        e1 = e1.semantic(sc);
        for(size_t a = 0; a < arguments.length; a++)
        {
            arguments[a] = arguments[a].semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= Token.toString(op);
        buf ~= ' ';

        e1.toBuffer(buf);
        buf ~= '(';
        for(size_t a = 0; a < arguments.length; a++)
        {
            arguments[a].toBuffer(buf);
        }
        buf ~= ')';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        // ret = new b(argc, argv)
        // CALL ret,b,argc,argv
        idx_t b;
        size_t argc;
        idx_t argv;

        //writef("NewExp::toIR('%s')\n", toChars());
        b = irs.alloc(1);
        e1.toIR(irs, b);
        if(arguments.length)
        {
            uint u;

            argc = arguments.length;
            argv = irs.alloc(argc);
            for(u = 0; u < argc; u++)
            {
                Expression e;

                e = arguments[u];
                e.toIR(irs, argv + u);
            }
        }
        else
        {
            argc = 0;
            argv = 0;
        }

        irs.gen_!(Opcode.New)(loc, ret, b, argc, argv);
        irs.release(argv, argc);
        irs.release(b, 1);
    }
}

/************************************************************/

class XUnaExp : UnaExp
{
    Opcode ircode;

    this(Loc loc, TOK op, Opcode ircode, Expression e)
    {
        super(loc, op, e);
        this.ircode = ircode;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        e1.toIR(irs, ret);
        if(ret)
            irs.gen_!GenIR1(loc, ircode, ret);
    }
}

class NotExp : XUnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKnot, Opcode.Not, e);
    }

    override bool isBooleanResult()
    {
        return true;
    }
}

class DeleteExp : UnaExp
{
    bool lval;
    this(Loc loc, Expression e)
    {
        super(loc, TOKdelete, e);
    }

    override Expression semantic(Scope* sc)
    {
        e1.checkLvalue(sc);
        lval = sc.errinfo.message == null;
        //delete don't have to operate on Lvalue, while slightly stupid but perfectly by the standard
        if(!lval)
               sc.errinfo.message = null;
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;
        IR property;
        OpOffset opoff;

        if(lval)
        {
            e1.toLvalue(irs, base, &property, opoff);

            final switch(opoff)
            {
            case OpOffset.None:
                irs.gen_!(Opcode.Del)(loc, ret, base, property.index);
                break;
            case OpOffset.S:
                irs.gen_!(Opcode.DelS)(loc, ret, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen_!(Opcode.DelScope)(loc, ret, property.id);
                break;
            case OpOffset.V:
                assert(0);
            }
        }
        else
        {
            //e1.toIR(irs,ret);
            irs.gen_!(Opcode.Boolean)(loc, ret, true);
        }
    }
}

/************************* CommaExp ***********************************/

class CommaExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKcomma, e1, e2);
    }

    override void checkLvalue(Scope* sc)
    {
        e2.checkLvalue(sc);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        e1.toIR(irs, idxNull);
        e2.toIR(irs, ret);
    }
}

/************************* ArrayExp ***********************************/

class ArrayExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKarray, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        checkLvalue(sc);
        return this;
    }

    override void checkLvalue(Scope* sc)
    {
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '[';
        e2.toBuffer(buf);
        buf ~= ']';
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t base;
        IR property;
        OpOffset opoff;

        if(ret)
        {
            toLvalue(irs, base, &property, opoff);
            final switch(opoff)
            {
            case OpOffset.None:
                irs.gen_!(Opcode.Get)(loc, ret, base, property.index);
                break;
            case OpOffset.S:
                irs.gen_!(Opcode.GetS)(loc, ret, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen_!(Opcode.GetScope)(loc, ret, property.id);
                break;
            case OpOffset.V:
                assert(0);
            }
        }
        else
        {
            e1.toIR(irs, 0);
            e2.toIR(irs, 0);
        }
    }

    override void toLvalue(IRstate* irs, out idx_t base, IR* property,
                           out OpOffset opoff)
    {
        uint index;

        base = irs.alloc(1);
        e1.toIR(irs, base);
        index = irs.alloc(1);
        e2.toIR(irs, index);
        property.index = index;
        opoff = OpOffset.None;
    }
}

/************************* AssignExp ***********************************/

class AssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKassign, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        //writefln("AssignExp.semantic()");
        super.semantic(sc);
        if(e1.op != TOKcall)            // special case for CallExp lvalue's
            e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t b;

        //writef("AssignExp::toIR('%s')\n", toChars());
        if(e1.op == TOKcall)            // if CallExp
        {
            assert(cast(CallExp)(e1));  // make sure we got it right

            // Special case a function call as an lvalue.
            // This can happen if:
            //	foo() = 3;
            // A Microsoft extension, it means to assign 3 to the default property of
            // the object returned by foo(). It only has meaning for com objects.
            // This functionality should be worked into toLvalue() if it gets used
            // elsewhere.

            idx_t base;
            size_t argc;
            idx_t argv;
            IR property;
            OpOffset opoff;
            CallExp ec = cast(CallExp)e1;

            if(ec.arguments.length)
                argc = ec.arguments.length + 1;
            else
                argc = 1;

            argv = irs.alloc(argc);

            e2.toIR(irs, argv + (argc - 1));

            ec.e1.toLvalue(irs, base, &property, opoff);

            if(ec.arguments.length)
            {
                uint u;

                for(u = 0; u < ec.arguments.length; u++)
                {
                    Expression e;

                    e = ec.arguments[u];
                    e.toIR(irs, argv + (u + 0));
                }
                ec.arguments[] = null;          // release to GC
                ec.arguments = null;
            }

            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen_!(Opcode.PutCall)(loc, ret, base, property.index,
                                          argc, argv);
                break;
            case OpOffset.S:
                irs.gen_!(Opcode.PutCallS)(loc, ret, base, property.id,
                                           argc, argv);
                break;
            case OpOffset.Scope:
                irs.gen_!(Opcode.PutCallScope)(loc, ret, property.id,
                                               argc, argv);
                break;
            case OpOffset.V:
                irs.gen_!(Opcode.PutCallV)(loc, ret, base, argc, argv);
                break;
            }
            irs.release(argv, argc);
        }
        else
        {
            size_t base;
            IR property;
            OpOffset opoff;

            b = ret ? ret : irs.alloc(1);
            e2.toIR(irs, b);

            e1.toLvalue(irs, base, &property, opoff);
            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen_!(Opcode.Put)(loc, b, base, property.index);
                break;
            case OpOffset.S:
                irs.gen_!(Opcode.PutS)(loc, b, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen_!(Opcode.PutScope)(loc, b, property.id);
                break;
            case OpOffset.V:
                assert(0);
            }
            if(!ret)
                irs.release(b, 1);
        }
    }
}

/************************* AddAssignExp ***********************************/

class AddAssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKplusass, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate* irs, uint ret)
    {
        /*if(ret == 0 && e2.op == TOKreal &&
           (cast(RealExpression)e2).value == 1)//disabled for better standard conformance
        {
            uint base;
            IR property;
            int opoff;

            //writef("AddAssign to PostInc('%s')\n", toChars());
            e1.toLvalue(irs, base, &property, opoff);
            assert(opoff != 3);
            if(opoff == 2)
                irs.gen2(loc, IRpostincscope, ret, property.index);
            else
                irs.gen3(loc, IRpostinc + opoff, ret, base, property.index);
        }
        else*/
        {
            idx_t r;
            idx_t base;
            IR property;
            OpOffset opoff;

            //writef("AddAssignExp::toIR('%s')\n", toChars());
            e1.toLvalue(irs, base, &property, opoff);
            r = ret ? ret : irs.alloc(1);
            e2.toIR(irs, r);
            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen_!(Opcode.AddAsS)(loc, r, base, property.index);
                break;
            case OpOffset.S:
                irs.gen_!(Opcode.AddAsSS)(loc, r, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen_!(Opcode.AddAsSScope)(loc, r, property.id,
                                              property.id.toHash);
                break;
            case OpOffset.V:
                assert(0);
            }

            if(!ret)
                irs.release(r, 1);
        }
    }
}

/************************* BinAssignExp ***********************************/

class BinAssignExp : BinExp
{
    Opcode ircode = Opcode.Error;

    this(Loc loc, TOK op, Opcode ircode, Expression e1, Expression e2)
    {
        super(loc, op, e1, e2);
        this.ircode = ircode;
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t b;
        idx_t c;
        idx_t r;
        idx_t base;
        IR property;
        OpOffset opoff;

        //writef("BinExp::binAssignIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        b = irs.alloc(1);
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen_!(Opcode.Get)(loc, b, base, property.index);
            break;
        case OpOffset.S:
            irs.gen_!(Opcode.GetS)(loc, b, base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen_!(Opcode.GetScope)(loc, b, property.id);
            break;
        case OpOffset.V:
            assert(0);
        }
        c = irs.alloc(1);
        e2.toIR(irs, c);
        r = ret ? ret : irs.alloc(1);
        irs.gen_!GenIR3(loc, ircode, r, b, c);
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen_!(Opcode.Put)(loc, r, base, property.index);
            break;
        case OpOffset.S:
            irs.gen_!(Opcode.PutS)(loc, r, base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen_!(Opcode.PutScope)(loc, r, property.id);
            break;
        case OpOffset.V:
            assert(0);
        }
        if(!ret)
            irs.release(r, 1);
    }
}

/************************* AddExp *****************************/

class AddExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKplus, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, Opcode.Add);
    }
}

/************************* XBinExp ***********************************/

class XBinExp : BinExp
{
    Opcode ircode = Opcode.Error;

    this(Loc loc, TOK op, Opcode ircode, Expression e1, Expression e2)
    {
        super(loc, op, e1, e2);
        this.ircode = ircode;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, ircode);
    }
}

/************************* OrOrExp ***********************************/

class OrOrExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKoror, e1, e2);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u;
        idx_t b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen_!(Opcode.JT)(loc, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* AndAndExp ***********************************/

class AndAndExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKandand, e1, e2);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u;
        idx_t b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen_!(Opcode.JF)(loc, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* CmpExp ***********************************/

class CmpExp : BinExp
{
    Opcode ircode = Opcode.Error;

    this(Loc loc, TOK tok, Opcode ircode, Expression e1, Expression e2)
    {
        super(loc, tok, e1, e2);
        this.ircode = ircode;
    }

    override bool isBooleanResult()
    {
        return true;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, ircode);
    }
}

/*************************** InExp **************************/

class InExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKin, e1, e2);
    }
    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, Opcode.In);
    }
}

/****************************************************************/

class CondExp : BinExp
{
    Expression econd;

    this(Loc loc, Expression econd, Expression e1, Expression e2)
    {
        super(loc, TOKquestion, e1, e2);
        this.econd = econd;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u1;
        idx_t u2;
        idx_t b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        econd.toIR(irs, b);
        u1 = irs.getIP();
        irs.gen_!(Opcode.JF)(loc, 0, b);
        e1.toIR(irs, ret);
        u2 = irs.getIP();
        irs.gen_!(Opcode.Jmp)(loc, 0);
        irs.patchJmp(u1, irs.getIP());
        e2.toIR(irs, ret);
        irs.patchJmp(u2, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

