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

import dmdscript.primitive;
import dmdscript.script;
import dmdscript.lexer;
import dmdscript.scopex;
import dmdscript.key;
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

    line_number loc;                    // file location
    Tok op;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op)
    {
        this.loc = loc;
        this.op = op;
        signature = EXPRESSION_SIGNATURE;
    }

    invariant()
    {
        assert(signature == EXPRESSION_SIGNATURE);
        assert(op != Tok.reserved && op <= Tok.max);
    }

    /**************************
     * Semantically analyze Expression.
     * Determine types, fold constants, e
     */

    Expression semantic(Scope* sc)
    {
        return this;
    }

    void checkLvalue(Scope* sc)
    {
        import std.format : format;
        tstring sourcename;

        assert(sc !is null);
        if(sc.funcdef)
        {
            if(sc.funcdef.isAnonymous)
                sourcename = "anonymous";
            else if(sc.funcdef.name)
                sourcename = sc.funcdef.name.toString;
        }

        if (sc.exception is null)
        {
            sc.exception = CannotAssignToError.toThrow(
                toString, sourcename, sc.getSource, loc);
        }
        assert(sc.exception !is null);
        debug throw sc.exception;
    }

    // Do we match for purposes of optimization?

    @safe @nogc pure nothrow
    bool match(Expression e) const
    {
        return false;
    }

    // Is the result of the expression guaranteed to be a boolean?

    @safe @nogc pure nothrow
    bool isBooleanResult() const
    {
        return false;
    }

    void toIR(IRstate* irs, idx_t ret)
    {
        assert(0, "Expression::toIR('" ~ toString() ~ "')", );
    }

    void toLvalue(IRstate* irs, out idx_t base, IR* property,
                  out OpOffset opoff)
    {
        base = irs.alloc(1)[0];
        toIR(irs, base);
        property.index = 0;
        opoff = OpOffset.V;
    }

    final override
    tstring toString()
    {
        import std.array : Appender;

        Appender!tstring buf;
        toBuffer(b=>buf.put(b));
        return buf.data;
    }

    void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        assert(0);
    }
}

/******************************** RealExpression **************************/

final class RealExpression : Expression
{
    real_t value;

    @safe @nogc pure nothrow
    this(line_number loc, real_t value)
    {
        super(loc, Tok.Real);
        this.value = value;
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret) const
    {
        if(ret)
            irs.gen!(Opcode.Number)(loc, ret, value);
    }

    override @trusted
    void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        import std.conv : to;
        sink(value.to!string);
    }
}

/******************************** IdentifierExpression **************************/

final class IdentifierExpression : Expression
{
    Identifier* ident;

    @safe @nogc pure nothrow
    this(line_number loc, Identifier*  ident)
    {
        super(loc, Tok.Identifier);
        this.ident = ident;
    }

    override @safe @nogc pure nothrow
    Expression semantic(Scope* sc)
    {
        return this;
    }

    override @safe @nogc pure nothrow
    void checkLvalue(Scope* sc) const
    {
    }

    override bool match(Expression e) const
    {
        if(e.op != Tok.Identifier)
            return 0;

        auto ie = cast(IdentifierExpression)(e);

        return ident == ie.ident;
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret)
    {
        // Identifier* id = ident;

        // assert(id.sizeof == uint.sizeof);
        if(ret)
            irs.gen!(Opcode.GetScope)(loc, ret, ident);
        else
            irs.gen!(Opcode.CheckRef)(loc, ident);
    }

    override @trusted @nogc pure nothrow
    void toLvalue(IRstate* irs, out idx_t base, IR* property,
                  out OpOffset opoff)
    {
        //irs.gen1(loc, IRthis, base);
        property.id = ident;
        opoff = OpOffset.Scope;
        base = ~0u;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    { sink(ident.toString); }
}

/******************************** ThisExpression **************************/

final class ThisExpression : Expression
{
    @safe @nogc pure nothrow
    this(line_number loc)
    {
        super(loc, Tok.This);
    }

    override @safe @nogc pure nothrow
    Expression semantic(Scope* sc)
    {
        return this;
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret) const
    {
        if(ret)
            irs.gen!(Opcode.This)(loc, ret);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(Text._this);
    }
}

/******************************** NullExpression **************************/

final class NullExpression : Expression
{
    @safe @nogc pure nothrow
    this(line_number loc)
    {
        super(loc, Tok.Null);
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret) const
    {
        if(ret)
            irs.gen!(Opcode.Null)(loc, ret);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(Text._null);
    }
}

/******************************** StringExpression **************************/

final class StringExpression : Expression
{
    private tstring str;

    @safe @nogc pure nothrow
    this(line_number loc, tstring str)
    {
        //writefln("StringExpression('%s')", string);
        super(loc, Tok.String);
        this.str = str;
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret) const
    {
        if(ret)
            irs.gen!(Opcode.String)(loc, ret, Identifier.build(str));
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        import std.format : format;
        import std.ascii : isPrintable;

        sink("\"");
        foreach(dchar c; str)
        {
            switch(c)
            {
            case '"':
                sink("\\");
                goto Ldefault;

            default:
                Ldefault:
                if(c & ~0xFF)
                    sink(format("\\u%04x", c));
                else if(isPrintable(c))
                    sink([cast(tchar)c]);
                else
                    sink(format("\\x%02x", c));
                break;
            }
        }
        sink("\"");
    }
}

/******************************** RegExpLiteral **************************/

final class RegExpLiteral : Expression
{
    private tstring str;

    @safe @nogc pure nothrow
    this(line_number loc, tstring str)
    {
        //writefln("RegExpLiteral('%s')", string);
        super(loc, Tok.Regexp);
        this.str = str;
    }

    override void toIR(IRstate* irs, idx_t ret) const
    {
        import std.string : lastIndexOf;
        tstring pattern;
        tstring attribute = null;
        sizediff_t e;

        size_t argc;
        LocalVariables argv;
        LocalVariables b;

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
        auto re = Identifier.build(Key.RegExp);
        irs.gen!(Opcode.GetScope)(loc, b[0], re);
        argv = irs.alloc(argc);
        irs.gen!(Opcode.String)(loc, argv[0], Identifier.build(pattern));
        if(argv.length == 2)
            irs.gen!(Opcode.String)(loc, argv[1], Identifier.build(attribute));
        irs.gen!(Opcode.New)(loc, ret, b[0], argv.length, argv[0]);

        irs.release(argv);
        irs.release(b);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(str);
    }
}

/******************************** BooleanExpression **************************/

final class BooleanExpression : Expression
{
    private bool boolean;

    @safe @nogc pure nothrow
    this(line_number loc, bool boolean)
    {
        super(loc, Tok.Boolean);
        this.boolean = boolean;
    }

    override bool isBooleanResult() const
    {
        return true;
    }

    override @safe
    void toIR(IRstate* irs, idx_t ret) const
    {
        if(ret)
            irs.gen!(Opcode.Boolean)(loc, ret, boolean);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(boolean ? "true" : "false");
    }
}

/******************************** ArrayLiteral **************************/

final class ArrayLiteral : Expression
{
    private Expression[] elements;

    @safe @nogc pure nothrow
    this(line_number loc, Expression[] elements)
    {
        super(loc, Tok.Arraylit);
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

    override void toIR(IRstate* irs, idx_t ret)
    {
        LocalVariables argv;
        LocalVariables b;

        b = irs.alloc(1);
        static Identifier* ar;
        if(!ar)
            ar = Identifier.build(Key.Array);
        irs.gen!(Opcode.GetScope)(loc, b[0], ar);
        if(elements.length)
        {
            Expression e;

            argv = irs.alloc(elements.length);
            if(1 < argv.length)
            {
                // array literal [a, b, c] is equivalent to:
                //	new Array(a,b,c)
                for(size_t i = 0; i < argv.length; i++)
                {
                    e = elements[i];
                    if(e)
                    {
                        e.toIR(irs, argv[i]);
                    }
                    else
                        irs.gen!(Opcode.Undefined)(loc, argv[i]);
                }
                irs.gen!(Opcode.New)(loc, ret, b[0], argv.length, argv[0]);
            }
            else
            {   //	[a] translates to:
                //	ret = new Array(1);
                //  ret[0] = a

                irs.gen!(Opcode.Number)(loc, argv[0], 1.0);
                irs.gen!(Opcode.New)(loc, ret, b[0], argv.length, argv[0]);

                e = elements[0];
                auto v = irs.alloc(1);
                if(e)
                    e.toIR(irs, v[0]);
                else
                    irs.gen!(Opcode.Undefined)(loc, v[0]);
                irs.gen!(Opcode.PutS)(loc, v[0], ret,
                                      Identifier.build(Text._0));
                irs.release(v);
            }
            irs.release(argv);
        }
        else
        {
            // Generate new Array()
            irs.gen!(Opcode.New)(loc, ret, b[0], 0, 0);
        }
        irs.release(b);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        uint i;

        sink("[");
        foreach(e; elements)
        {
            if(i)
                sink(",");
            i = 1;
            if(e)
                e.toBuffer(sink);
        }
        sink("]");
    }
}

/******************************** FieldLiteral **************************/

final class Field
{
    private Identifier* ident;
    private Expression exp;

    @safe @nogc pure nothrow
    this(Identifier* ident, Expression exp)
    {
        this.ident = ident;
        this.exp = exp;
    }
}

/******************************** ObjectLiteral **************************/

final class ObjectLiteral : Expression
{
    private Field[] fields;

    @safe @nogc pure nothrow
    this(line_number loc, Field[] fields)
    {
        super(loc, Tok.Objectlit);
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

    override void toIR(IRstate* irs, idx_t ret)
    {
        LocalVariables b;

        b = irs.alloc(1);
        //irs.gen2(loc, IRstring, b, Text.Object);
        irs.gen!(Opcode.GetScope)(loc, b[0], Identifier.build(Key.Object));
        // Generate new Object()
        irs.gen!(Opcode.New)(loc, ret, b[0], 0, 0);
        if(fields.length)
        {
            auto x = irs.alloc(1);
            foreach(Field f; fields)
            {
                f.exp.toIR(irs, x[0]);
                irs.gen!(Opcode.PutS)(loc, x[0], ret, f.ident);
            }
            irs.lvm.collect(x);
        }
        irs.lvm.collect(b);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        uint i;

        sink("{");
        foreach(f; fields)
        {
            if(i)
                sink(",");
            i = 1;
            sink(f.ident.toString);
            sink(":");
            f.exp.toBuffer(sink);
        }
        sink("}");
    }
}

/******************************** FunctionLiteral **************************/

final class FunctionLiteral : Expression
{
    private FunctionDefinition func;

    @safe @nogc pure nothrow
    this(line_number loc, FunctionDefinition func)
    {
        super(loc, Tok.Objectlit);
        this.func = func;
    }

    override Expression semantic(Scope* sc)
    {
        func = func.semantic(sc);
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        func.toIR(null);
        irs.gen!(Opcode.Object)(loc, ret, func);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        func.toBuffer(sink);
    }
}

/***************************** UnaExp *************************************/

class UnaExp : Expression
{
    protected Expression e1;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op, Expression e1)
    {
        super(loc, op);
        this.e1 = e1;
    }

    override Expression semantic(Scope* sc)
    {
        e1 = e1.semantic(sc);
        return this;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(Token.toString(op));
        sink(" ");
        e1.toBuffer(sink);
    }
}

/***************************** BinExp *************************************/

class BinExp : Expression
{
    Expression e1;
    Expression e2;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op, Expression e1, Expression e2)
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

    void binIR(IRstate* irs, idx_t ret, Opcode ircode)
    {
        if(ret)
        {
            auto b = irs.alloc(1);
            e1.toIR(irs, b[0]);
            if(e1.match(e2))
            {
                irs.gen!GenIR3(loc, ircode, ret, b[0], b[0]);
            }
            else
            {
                auto c = irs.alloc(1);
                e2.toIR(irs, c[0]);
                irs.gen!GenIR3(loc, ircode, ret, b[0], c[0]);
                irs.release(c);
            }
            irs.release(b);
        }
        else
        {
            e1.toIR(irs, 0);
            e2.toIR(irs, 0);
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink(" ");
        sink(Token.toString(op));
        sink(" ");
        e2.toBuffer(sink);
    }
}

/************************************************************/

/* Handle ++e and --e
 */

final class PreExp : UnaExp
{
    private Opcode ircode;

    @safe @nogc pure nothrow
    this(line_number loc, Opcode ircode, Expression e)
    {
        super(loc, Tok.Plusplus, e);
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
        idx_t base;
        IR property;
        OpOffset opoff;

        //writef("PreExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        final switch(opoff)
        {
        case OpOffset.None:
            irs.gen!GenIR3(loc, ircode, ret, base, property.index);
            break;
        case OpOffset.S:
            irs.gen!GenIR3S(loc, cast(Opcode)(ircode + opoff),
                             ret, base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen!GenIRScope3(loc, cast(Opcode)(ircode + opoff),
                                 ret, property.id, property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink(Token.toString(op));
    }
}

/************************************************************/

final class PostIncExp : UnaExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e)
    {
        super(loc, Tok.Plusplus, e);
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
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
                irs.gen!(Opcode.PostInc)(loc, ret, base, property.index);
            else
                irs.gen!(Opcode.PreInc)(loc, ret, base, property.index);
            break;
        case OpOffset.S:
            if (ret)
                irs.gen!(Opcode.PostIncS)(loc, ret, base, property.id);
            else
                irs.gen!(Opcode.PreIncS)(loc, ret, base, property.id);
            break;
        case OpOffset.Scope:
            if (ret)
                irs.gen!(Opcode.PostIncScope)(loc, ret, property.id);
            else
                irs.gen!(Opcode.PreIncScope)(loc, ret, property.id,
                                              property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink(Token.toString(op));
    }
}

/****************************************************************/

final class PostDecExp : UnaExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e)
    {
        super(loc, Tok.Plusplus, e);
    }

    override Expression semantic(Scope* sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
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
                irs.gen!(Opcode.PostDec)(loc, ret, base, property.index);
            else
                irs.gen!(Opcode.PreDec)(loc, ret, base, property.index);
            break;
        case OpOffset.S:
            if (ret)
                irs.gen!(Opcode.PostDecS)(loc, ret, base, property.id);
            else
                irs.gen!(Opcode.PreDecS)(loc, ret, base, property.id);
            break;
        case OpOffset.Scope:
            if (ret)
                irs.gen!(Opcode.PostDecScope)(loc, ret, property.id);
            else
                irs.gen!(Opcode.PreDecScope)(loc, ret, property.id,
                                              property.id.toHash);
            break;
        case OpOffset.V:
            assert(0);
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink(Token.toString(op));
    }
}

/************************************************************/

final class DotExp : UnaExp
{
    private Identifier* ident;

    @safe @nogc pure nothrow
    this(line_number loc, Expression e, Identifier*  ident)
    {
        super(loc, Tok.Dot, e);
        this.ident = ident;
    }

    override @safe @nogc pure nothrow
    void checkLvalue(Scope* sc) {}

    override void toIR(IRstate* irs, idx_t ret)
    {
        LocalVariables base;

        //writef("DotExp::toIR('%s')\n", toChars());
        version(all)
        {
            // Some test cases depend on things like:
            //		foo.bar;
            // generating a property get even if the result is thrown away.
            base = irs.alloc(1);
            e1.toIR(irs, base[0]);
            irs.gen!(Opcode.GetS)(loc, ret, base[0], ident);

            irs.lvm.collect(base);
        }
        else
        {
            if(ret)
            {
                base = irs.alloc(1);
                e1.toIR(irs, base);
                irs.gen!(Opcode.GetS)(loc, ret, base, ident);

                irs.lvm.collect(base);
            }
            else
                e1.toIR(irs, 0);
        }
    }

    override void toLvalue(IRstate* irs, out idx_t base, IR* property,
                           out OpOffset opoff)
    {
        auto tmp = irs.alloc(1);
        base = tmp[0];
        e1.toIR(irs, base);
        property.id = ident;
        opoff = OpOffset.S;
        irs.lvm.collect(tmp);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink(".");
        sink(ident.toString);
    }
}

/************************************************************/

final class CallExp : UnaExp
{
    private Expression[] arguments;

    @safe @nogc pure nothrow
    this(line_number loc, Expression e, Expression[] arguments)
    {
        //writef("CallExp(e1 = %x)\n", e);
        super(loc, Tok.Call, e);
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
            if(e1.op == Tok.Identifier)
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

    override void toIR(IRstate* irs, idx_t ret)
    {
        // ret = base.property(argc, argv)
        // CALL ret,base,property,argc,argv
        idx_t base;
        LocalVariables argv;
        IR property;
        OpOffset opoff;

        //writef("CallExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);

        if(arguments.length)
        {
            argv = irs.alloc(arguments.length);
            for(size_t u = 0; u < argv.length; u++)
            {
                auto e = arguments[u];
                e.toIR(irs, argv[u]);
            }
            arguments[] = null;         // release to GC
            arguments = null;
        }

        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen!(Opcode.Call)(loc, ret, base, property.index,
                                  argv.length, argv[0]);
            break;
        case OpOffset.S:
            irs.gen!(Opcode.CallS)(loc, ret, base, property.id,
                                   argv.length, argv[0]);
            break;
        case OpOffset.Scope:
            irs.gen!(Opcode.CallScope)(loc, ret, property.id,
                                       argv.length, argv[0]);
            break;
        case OpOffset.V:
            irs.gen!(Opcode.CallV)(loc, ret, base, argv.length, argv[0]);
            break;
        }
        irs.release(argv);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink("(");
        for(size_t u = 0; u < arguments.length; u++)
        {
            if(u)
                sink(", ");
            arguments[u].toBuffer(sink);
        }
        sink(")");
    }
}
/************************************************************/

final class AssertExp : UnaExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e)
    {
        super(loc, Tok.Assert, e);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        line_number linnum;
        size_t u;
        idx_t b;
        LocalVariables tmp;

        if (0 < ret)
            b = ret;
        else
        {
            tmp = irs.alloc(1);
            b = tmp[0];
        }

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen!(Opcode.JT)(loc, 0, b);
        linnum = cast(line_number)loc;
        irs.gen!(Opcode.Assert)(loc, linnum);
        irs.patchJmp(u, irs.getIP);

        irs.release(tmp);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink("assert(");
        e1.toBuffer(sink);
        sink(")");
    }
}

/************************* NewExp ***********************************/

final class NewExp : UnaExp
{
    private Expression[] arguments;

    @safe @nogc pure nothrow
    this(line_number loc, Expression e, Expression[] arguments)
    {
        super(loc, Tok.New, e);
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

    override void toIR(IRstate* irs, idx_t ret)
    {
        // ret = new b(argc, argv)
        // CALL ret,b,argc,argv
        LocalVariables b;
        LocalVariables argv;

        //writef("NewExp::toIR('%s')\n", toChars());
        b = irs.alloc(1);
        e1.toIR(irs, b[0]);
        if(arguments.length)
        {
            argv = irs.alloc(arguments.length);
            for(size_t u = 0; u < argv.length; u++)
            {
                auto e = arguments[u];
                e.toIR(irs, argv[u]);
            }
        }

        irs.gen!(Opcode.New)(loc, ret, b[0], argv.length, argv[0]);
        irs.release(argv);
        irs.release(b);
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(Token.toString(op));
        sink(" ");

        e1.toBuffer(sink);
        sink("(");
        for(size_t a = 0; a < arguments.length; a++)
        {
            arguments[a].toBuffer(sink);
        }
        sink(")");
    }
}

/************************************************************/

class XUnaExp : UnaExp
{
    protected Opcode ircode;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op, Opcode ircode, Expression e)
    {
        super(loc, op, e);
        this.ircode = ircode;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        e1.toIR(irs, ret);
        if(ret)
            irs.gen!GenIR1(loc, ircode, ret);
    }
}

final class NotExp : XUnaExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e)
    {
        super(loc, Tok.Not, Opcode.Not, e);
    }

    override bool isBooleanResult() const
    {
        return true;
    }
}

final class DeleteExp : UnaExp
{
    private bool lval;

    @safe @nogc pure nothrow
    this(line_number loc, Expression e)
    {
        super(loc, Tok.Delete, e);
    }

    override Expression semantic(Scope* sc)
    {
        e1.checkLvalue(sc);
        lval = sc.exception is null;
        //delete don't have to operate on Lvalue, while slightly stupid but perfectly by the standard

// Should I?
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        if(!lval)
               sc.exception = null;
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
                irs.gen!(Opcode.Del)(loc, ret, base, property.index);
                break;
            case OpOffset.S:
                irs.gen!(Opcode.DelS)(loc, ret, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen!(Opcode.DelScope)(loc, ret, property.id);
                break;
            case OpOffset.V:
                assert(0);
            }
        }
        else
        {
            //e1.toIR(irs,ret);
            irs.gen!(Opcode.Boolean)(loc, ret, true);
        }
    }
}

/************************* CommaExp ***********************************/

final class CommaExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Comma, e1, e2);
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

final class ArrayExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Array, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        checkLvalue(sc);
        return this;
    }

    override @safe @nogc pure nothrow
    void checkLvalue(Scope* sc) const {}

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
                irs.gen!(Opcode.Get)(loc, ret, base, property.index);
                break;
            case OpOffset.S:
                irs.gen!(Opcode.GetS)(loc, ret, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen!(Opcode.GetScope)(loc, ret, property.id);
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
        LocalVariables tmp;
        idx_t index;

        tmp = irs.alloc(1);
        base = tmp[0];
        irs.lvm.collect(tmp);
        e1.toIR(irs, base);
        tmp = irs.alloc(1);
        index = tmp[0];
        irs.lvm.collect(tmp);
        e2.toIR(irs, index);
        property.index = index;
        opoff = OpOffset.None;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        e1.toBuffer(sink);
        sink("[");
        e2.toBuffer(sink);
        sink("]");
    }
}

/************************* AssignExp ***********************************/

final class AssignExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Assign, e1, e2);
    }

    override Expression semantic(Scope* sc)
    {
        //writefln("AssignExp.semantic()");
        super.semantic(sc);
        if(e1.op != Tok.Call)            // special case for CallExp lvalue's
            e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t b;

        //writef("AssignExp::toIR('%s')\n", toChars());
        if(e1.op == Tok.Call)            // if CallExp
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
            LocalVariables argv;
            IR property;
            OpOffset opoff;
            CallExp ec = cast(CallExp)e1;

            if(ec.arguments.length)
                argc = ec.arguments.length + 1;
            else
                argc = 1;

            argv = irs.alloc(argc);

            e2.toIR(irs, argv[$ - 1]);

            ec.e1.toLvalue(irs, base, &property, opoff);

            if(ec.arguments.length)
            {
                for(size_t u = 0; u < ec.arguments.length; u++)
                {
                    auto e = ec.arguments[u];
                    e.toIR(irs, argv[u]);
                }
                ec.arguments[] = null;          // release to GC
                ec.arguments = null;
            }

            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen!(Opcode.PutCall)(loc, ret, base, property.index,
                                          argv.length, argv[0]);
                break;
            case OpOffset.S:
                irs.gen!(Opcode.PutCallS)(loc, ret, base, property.id,
                                           argv.length, argv[0]);
                break;
            case OpOffset.Scope:
                irs.gen!(Opcode.PutCallScope)(loc, ret, property.id,
                                               argv.length, argv[0]);
                break;
            case OpOffset.V:
                irs.gen!(Opcode.PutCallV)(loc, ret, base,
                                          argv.length, argv[0]);
                break;
            }
            irs.release(argv);
        }
        else
        {
            idx_t base;
            LocalVariables tmp;
            IR property;
            OpOffset opoff;

            if (0 < ret)
                b = ret;
            else
            {
                tmp = irs.alloc(1);
                b = tmp[0];
            }

            e1.toLvalue(irs, base, &property, opoff);
            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen!(Opcode.Put)(loc, b, base, property.index);
                break;
            case OpOffset.S:
                irs.gen!(Opcode.PutS)(loc, b, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen!(Opcode.PutScope)(loc, b, property.id);
                break;
            case OpOffset.V:
                assert(0);
            }
            irs.release(tmp);
        }
    }
}

/************************* AddAssignExp ***********************************/

final class AddAssignExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Plusass, e1, e2);
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
            LocalVariables tmp;
            idx_t r;
            idx_t base;
            IR property;
            OpOffset opoff;

            //writef("AddAssignExp::toIR('%s')\n", toChars());
            e1.toLvalue(irs, base, &property, opoff);
            if (0 < ret)
                r = ret;
            else
            {
                tmp = irs.alloc(1);
                r = tmp[0];
            }
            e2.toIR(irs, r);
            final switch (opoff)
            {
            case OpOffset.None:
                irs.gen!(Opcode.AddAsS)(loc, r, base, property.index);
                break;
            case OpOffset.S:
                irs.gen!(Opcode.AddAsSS)(loc, r, base, property.id);
                break;
            case OpOffset.Scope:
                irs.gen!(Opcode.AddAsSScope)(loc, r, property.id,
                                              property.id.toHash);
                break;
            case OpOffset.V:
                assert(0);
            }

            irs.release(tmp);
        }
    }
}

/************************* BinAssignExp ***********************************/

class BinAssignExp : BinExp
{
    protected Opcode ircode = Opcode.Error;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op, Opcode ircode, Expression e1, Expression e2)
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
        LocalVariables b;
        LocalVariables c;
        idx_t r;
        idx_t base;
        LocalVariables tmp;
        IR property;
        OpOffset opoff;

        //writef("BinExp::binAssignIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        b = irs.alloc(1);
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen!(Opcode.Get)(loc, b[0], base, property.index);
            break;
        case OpOffset.S:
            irs.gen!(Opcode.GetS)(loc, b[0], base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen!(Opcode.GetScope)(loc, b[0], property.id);
            break;
        case OpOffset.V:
            assert(0);
        }
        c = irs.alloc(1);
        e2.toIR(irs, c[0]);
        if (0 < ret)
            r = ret;
        else
        {
            tmp = irs.alloc(1);
            r = tmp[0];
        }
        irs.gen!GenIR3(loc, ircode, r, b[0], c[0]);
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen!(Opcode.Put)(loc, r, base, property.index);
            break;
        case OpOffset.S:
            irs.gen!(Opcode.PutS)(loc, r, base, property.id);
            break;
        case OpOffset.Scope:
            irs.gen!(Opcode.PutScope)(loc, r, property.id);
            break;
        case OpOffset.V:
            assert(0);
        }
        irs.release(tmp);
        irs.lvm.collect(b);
        irs.lvm.collect(c);
    }
}

/************************* AddExp *****************************/

final class AddExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Plus, e1, e2);
    }

    override @safe @nogc pure nothrow
    Expression semantic(Scope* sc)
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
    protected Opcode ircode = Opcode.Error;

    @safe @nogc pure nothrow
    this(line_number loc, Tok op, Opcode ircode, Expression e1, Expression e2)
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

final class OrOrExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Oror, e1, e2);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u;
        idx_t b;
        LocalVariables tmp;

        if(0 < ret)
            b = ret;
        else
        {
            tmp = irs.alloc(1);
            b = tmp[0];
        }

        e1.toIR(irs, b);
        u = irs.getIP;
        irs.gen!(Opcode.JT)(loc, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP);

        irs.release(tmp);
    }
}

/************************* AndAndExp ***********************************/

final class AndAndExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.Andand, e1, e2);
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u;
        idx_t b;
        LocalVariables tmp;

        if(ret)
            b = ret;
        else
        {
            tmp = irs.alloc(1);
            b = tmp[0];
        }

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen!(Opcode.JF)(loc, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP());

        irs.release(tmp);
    }
}

/************************* CmpExp ***********************************/

final class CmpExp : BinExp
{
    private Opcode ircode = Opcode.Error;

    @safe @nogc pure nothrow
    this(line_number loc, Tok tok, Opcode ircode, Expression e1, Expression e2)
    {
        super(loc, tok, e1, e2);
        this.ircode = ircode;
    }

    override bool isBooleanResult() const
    {
        return true;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, ircode);
    }
}

/*************************** InExp **************************/

final class InExp : BinExp
{
    @safe @nogc pure nothrow
    this(line_number loc, Expression e1, Expression e2)
    {
        super(loc, Tok.In, e1, e2);
    }
    override void toIR(IRstate* irs, idx_t ret)
    {
        binIR(irs, ret, Opcode.In);
    }
}

/****************************************************************/

final class CondExp : BinExp
{
    private Expression econd;

    @safe @nogc pure nothrow
    this(line_number loc, Expression econd, Expression e1, Expression e2)
    {
        super(loc, Tok.Question, e1, e2);
        this.econd = econd;
    }

    override void toIR(IRstate* irs, idx_t ret)
    {
        idx_t u1;
        idx_t u2;
        idx_t b;
        LocalVariables tmp;

        if(ret)
            b = ret;
        else
        {
            tmp = irs.alloc(1);
            b = tmp[0];
        }
        econd.toIR(irs, b);
        u1 = irs.getIP;
        irs.gen!(Opcode.JF)(loc, 0, b);
        e1.toIR(irs, ret);
        u2 = irs.getIP();
        irs.gen!(Opcode.Jmp)(loc, 0);
        irs.patchJmp(u1, irs.getIP);
        e2.toIR(irs, ret);
        irs.patchJmp(u2, irs.getIP);

        irs.release(tmp);
    }
}

