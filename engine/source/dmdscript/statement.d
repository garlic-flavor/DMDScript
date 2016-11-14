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

module dmdscript.statement;

import dmdscript.script;
import dmdscript.value;
import dmdscript.scopex;
import dmdscript.expression;
import dmdscript.irstate;
import dmdscript.symbol;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.lexer;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.opcodes;

debug import std.stdio;

enum StatementType
{
    TopStatement,
    FunctionDefinition,
    ExpStatement,
    VarStatement,
}

enum Progress
{
    Parsed,
    Semantic,
    toIR,
}

/******************************** TopStatement ***************************/

class TopStatement
{
    enum uint TOPSTATEMENT_SIGNATURE = 0xBA3FE1F3;
    uint signature = TOPSTATEMENT_SIGNATURE;

    Loc loc;
    Progress done;      // 0: parsed
                        // 1: semantic
                        // 2: toIR
    StatementType st;

    @safe @nogc pure nothrow
    this(Loc loc)
    {
        this.loc = loc;
        this.done = Progress.Parsed;
        this.st = StatementType.TopStatement;
    }

    invariant()
    {
        assert(signature == TOPSTATEMENT_SIGNATURE);
    }

    Statement semantic(Scope *sc)
    {
        assert(0, "TopStatement.semantic(" ~ toString ~ ")");
    }

    TopStatement ImpliedReturn()
    {
        return this;
    }

    void toIR(IRstate *irs)
    {
        assert(0, "TopStatement.toIR(" ~ toString ~ ")");
    }

    void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink("TopStatement.toBuffer()\n");
    }

    final
    void error(Scope* sc, ScriptException se)
    {
        assert(sc !is null);
        assert(se !is null);

        if (sc.exception is null)
        {
            d_string sourcename;
            if (sc.funcdef !is null)
            {
                if      (sc.funcdef.isAnonymous)
                    sourcename = "anonymous";
                else if (sc.funcdef.name)
                    sourcename = sc.funcdef.name.toString;
            }

            se.addSource(sourcename, sc.getSource, loc);
            sc.exception = se;
        }
        assert(se !is null);
        debug throw se;
    }
}

/******************************** Statement ***************************/

class Statement : TopStatement
{
    protected LabelSymbol* label;

    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
        this.loc = loc;
    }

    override Statement semantic(Scope *sc)
    {
        assert(0, "Statement.semantic(" ~ toString ~ ")\n");
    }

    override void toIR(IRstate *irs)
    {
        assert(0, "Statement.toIR(" ~ toString ~ ")\n");
    }

    @property @safe @nogc pure nothrow
    size_t getBreak() const
    {
        assert(0);
    }

    @property @safe @nogc pure nothrow
    size_t getContinue() const
    {
        assert(0);
    }

    @property @safe @nogc pure nothrow
    size_t getGoto() const
    {
        assert(0);
    }

    @property @safe @nogc pure nothrow
    size_t getTarget() const
    {
        assert(0);
    }

    @property @safe @nogc pure nothrow
    ScopeStatement getScope()
    { return null; }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    { sink("Statement.toBuffer()\n"); }
}

/******************************** EmptyStatement ***************************/

final class EmptyStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
        this.loc = loc;
    }

    override @safe @nogc pure nothrow
    Statement semantic(Scope* sc)
    {
        //writef("EmptyStatement.semantic(%p)\n", this);
        return this;
    }

    override @safe @nogc pure nothrow
    void toIR(IRstate* irs) const
    {
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    { sink(";\n"); }
}

/******************************** ExpStatement ***************************/

class ExpStatement : Statement
{
    protected Expression exp;

    @safe @nogc pure nothrow
    this(Loc loc, Expression exp)
    {
        //writef("ExpStatement.ExpStatement(this = %x, exp = %x)\n", this, exp);
        super(loc);
        st = StatementType.ExpStatement;
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);
        return this;
    }

    override @safe pure nothrow
    TopStatement ImpliedReturn()
    {
        return new ImpliedReturnStatement(loc, exp);
    }

    override void toIR(IRstate* irs)
    {
        if(exp)
        {
            auto marksave = irs.mark;

            assert(exp);
            exp.toIR(irs, 0);
            irs.release(marksave);

            exp = null;         // release to garbage collector
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        if(exp)
            exp.toBuffer(sink);
        sink(";\n");
    }
}

/****************************** VarDeclaration ******************************/

final class VarDeclaration
{
    Loc loc;
    Identifier* name;
    Expression init;

    @safe @nogc pure nothrow
    this(Loc loc, Identifier* name, Expression init)
    {
        this.loc = loc;
        this.init = init;
        this.name = name;
    }
}

/******************************** VarStatement ***************************/

final class VarStatement : Statement
{
    VarDeclaration[] vardecls;

    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
        st = StatementType.VarStatement;
    }

    override Statement semantic(Scope* sc)
    {
        FunctionDefinition fd;
        uint i;

        // Collect all the Var statements in order in the function
        // declaration, this is so it is easy to instantiate them
        fd = sc.funcdef;
        //fd.varnames.reserve(vardecls.length);

        for(i = 0; i < vardecls.length; i++)
        {
            auto vd = vardecls[i];
            if(vd.init)
                vd.init = vd.init.semantic(sc);
            fd.varnames ~= vd.name;
        }

        return this;
    }

    override void toIR(IRstate* irs)
    {
        if(vardecls.length)
        {
            auto marksave = irs.mark();
            auto ret = irs.alloc(1);

            for(size_t i = 0; i < vardecls.length; i++)
            {
                auto vd = vardecls[i];

                // This works like assignment statements:
                //	name = init;
                IR property;

                if(vd.init)
                {
                    vd.init.toIR(irs, ret[0]);
                    property.id = Identifier.build(vd.name.toString);
                    irs.gen!(Opcode.PutThis)(loc, ret[0], property.id);
                }
            }
            irs.release(ret);
            irs.release(marksave);
            vardecls[] = null;          // help gc
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        uint i;

        if(vardecls.length)
        {
            sink("var ");

            for(i = 0; i < vardecls.length; i++)
            {
                auto vd = vardecls[i];
                sink(vd.name.toString);
                if(vd.init)
                {
                    sink(" = ");
                    vd.init.toBuffer(sink);
                }
            }
            sink(";\n");
        }
    }
}

/******************************** BlockStatement ***************************/

final class BlockStatement : Statement
{
    TopStatement[] statements;

    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
    }

    override Statement semantic(Scope* sc)
    {
        uint i;

        //writefln("BlockStatement.semantic()");
        for(i = 0; i < statements.length; i++)
        {
            auto s = statements[i];
            assert(s);
            statements[i] = s.semantic(sc);
        }

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(0 < statements.length)
        {
            auto ts = statements[$ - 1];
            ts = ts.ImpliedReturn();
            statements[$ - 1] = cast(Statement)ts;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        foreach(s; statements)
        {
            s.toIR(irs);
        }

        // Release to garbage collector
        statements[] = null;
        statements = null;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink("{\n");
        foreach(s; statements)
            s.toBuffer(sink);
        sink("}\n");
    }
}

/******************************** LabelStatement ***************************/

final class LabelStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Identifier* ident, Statement statement)
    {
        super(loc);
        this.ident = ident;
        this.statement = statement;
        gotoIP = ~0u;
        breakIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        LabelSymbol ls;

        scopeContext = sc.scopeContext;
        whichScope = *sc;
        ls = sc.searchLabel(ident);
        if(ls)
        {
            // Ignore multiple definition errors
            //if (ls.statement)
            //error(sc, "label '%s' is already defined", ident.toString());
            ls.statement = this;
        }
        else
        {
            ls = new LabelSymbol(loc, ident, this);
            sc.insertLabel(ls);
        }
        if(statement)
            statement = statement.semantic(sc);
        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(statement)
            statement = cast(Statement)statement.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        gotoIP = irs.getIP();
        statement.toIR(irs);
        breakIP = irs.getIP();
    }

    override size_t getGoto() const
    {
        return gotoIP;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override size_t getContinue() const
    {
        return statement.getContinue;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink(ident.toString);
        sink(": ");
        if(statement)
            statement.toBuffer(sink);
        else
            sink("\n");
    }

private:
    Identifier* ident;
    Statement statement;
    size_t gotoIP;
    size_t breakIP;
    ScopeStatement scopeContext;
    Scope whichScope;
}

/******************************** IfStatement ***************************/

final class IfStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
    }

    override Statement semantic(Scope* sc)
    {
        assert(condition);
        condition = condition.semantic(sc);
        ifbody = ifbody.semantic(sc);
        if(elsebody)
            elsebody = elsebody.semantic(sc);

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        assert(condition);
        ifbody = cast(Statement)ifbody.ImpliedReturn();
        if(elsebody)
            elsebody = cast(Statement)elsebody.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        LocalVariables c;
        uint u1;
        uint u2;

        assert(condition);
        c = irs.alloc(1);
        condition.toIR(irs, c[0]);
        u1 = irs.getIP();
        if (condition.isBooleanResult)
            irs.gen!(Opcode.JFB)(loc, 0, c[0]);
        else
            irs.gen!(Opcode.JF)(loc, 0, c[0]);
        irs.release(c);
        ifbody.toIR(irs);
        if(elsebody)
        {
            u2 = irs.getIP;
            irs.gen!(Opcode.Jmp)(loc, 0);
            irs.patchJmp(u1, irs.getIP);
            elsebody.toIR(irs);
            irs.patchJmp(u2, irs.getIP);
        }
        else
        {
            irs.patchJmp(u1, irs.getIP);
        }

        // Help GC
        condition = null;
        ifbody = null;
        elsebody = null;
    }

private:
    Expression condition;
    Statement ifbody;
    Statement elsebody;
}

/******************************** SwitchStatement ***************************/

final class SwitchStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression c, Statement b)
    {
        super(loc);
        condition = c;
        bdy = b;
        breakIP = ~0u;
        scopeContext = null;

        swdefault = null;
        cases = null;
    }

    override Statement semantic(Scope* sc)
    {
        condition = condition.semantic(sc);

        SwitchStatement switchSave = sc.switchTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.switchTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.switchTarget = switchSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override void toIR(IRstate* irs)
    {
        uint udefault;

        //writef("SwitchStatement.toIR()\n");
        auto marksave = irs.mark();
        auto c = irs.alloc(1);
        condition.toIR(irs, c[0]);

        // Generate a sequence of cmp-jt
        // Not the most efficient, but we await a more formal
        // specification of switch before we attempt to optimize

        if(cases.length)
        {
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// Is a next line needed?
            auto x = irs.alloc(1);
//
            for(uint i = 0; i < cases.length; i++)
            {
                CaseStatement cs;

                x = irs.alloc(1);
                cs = cases[i];
                cs.exp.toIR(irs, x[0]);
                irs.gen!(Opcode.CID)(loc, x[0], c[0], x[0]);
                cs.patchIP = irs.getIP;
                irs.gen!(Opcode.JT)(loc, 0, x[0]);
            }
        }
        udefault = irs.getIP;
        irs.gen!(Opcode.Jmp)(loc, 0);

        Statement breakSave = irs.breakTarget;
        irs.breakTarget = this;
        bdy.toIR(irs);

        irs.breakTarget = breakSave;
        breakIP = irs.getIP();

        // Patch jump addresses
        if(cases.length)
        {
            for(size_t i = 0; i < cases.length; i++)
            {
                auto cs = cases[i];
                irs.patchJmp(cs.patchIP, cs.caseIP);
            }
        }
        if(swdefault)
            irs.patchJmp(udefault, swdefault.defaultIP);
        else
            irs.patchJmp(udefault, breakIP);
        irs.release(c);
        irs.release(marksave);

        // Help gc
        condition = null;
        bdy = null;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }

private:
    Expression condition;
    Statement bdy;
    size_t breakIP;
    ScopeStatement scopeContext;

    DefaultStatement swdefault;
    CaseStatement[] cases;
}


/******************************** CaseStatement ***************************/

final class CaseStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
        caseIP = ~0u;
        patchIP = ~0u;
    }

    override Statement semantic(Scope* sc)
    {
        //writef("CaseStatement.semantic(%p)\n", sc);
        exp = exp.semantic(sc);
        if(sc.switchTarget)
        {
            SwitchStatement sw = sc.switchTarget;
            uint i;

            // Look for duplicate
            for(i = 0; i < sw.cases.length; i++)
            {
                CaseStatement cs = sw.cases[i];

                if(exp == cs.exp)
                {
                    error(sc, SwitchRedundantCaseError(exp.toString));
                    return null;
                }
            }
            sw.cases ~= this;
        }
        else
        {
            error(sc, MisplacedSwitchCaseError(exp.toString));
            return null;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        caseIP = irs.getIP();
    }

private:
    Expression exp;
    size_t caseIP;
    size_t patchIP;
}

/******************************** DefaultStatement ***************************/

final class DefaultStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
        defaultIP = ~0u;
    }

    override Statement semantic(Scope* sc)
    {
        if(sc.switchTarget)
        {
            SwitchStatement sw = sc.switchTarget;

            if(sw.swdefault)
            {
                error(sc, SwitchRedundantDefaultError);
                return null;
            }
            sw.swdefault = this;
        }
        else
        {
            error(sc, MisplacedSwitchDefaultError);
            return null;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        defaultIP = irs.getIP();
    }

private:
    uint defaultIP;
}

/******************************** DoStatement ***************************/

final class DoStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Statement b, Expression c)
    {
        super(loc);
        bdy = b;
        condition = c;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);
        condition = condition.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        LocalVariables c;
        uint u1;
        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;

        irs.continueTarget = this;
        irs.breakTarget = this;

        auto marksave = irs.mark();
        u1 = irs.getIP;
        bdy.toIR(irs);
        c = irs.alloc(1);
        continueIP = irs.getIP();
        condition.toIR(irs, c[0]);
        if (condition.isBooleanResult)
            irs.gen!(Opcode.JTB)(loc, u1 - irs.getIP, c[0]);
        else
            irs.gen!(Opcode.JT)(loc, u1 - irs.getIP, c[0]);
        breakIP = irs.getIP;
        irs.release(c);
        irs.release(marksave);

        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        condition = null;
        bdy = null;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override size_t getContinue() const
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }

private:
    Statement bdy;
    Expression condition;
    size_t breakIP;
    size_t continueIP;
    ScopeStatement scopeContext;
}

/******************************** WhileStatement ***************************/

final class WhileStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression c, Statement b)
    {
        super(loc);
        condition = c;
        bdy = b;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        condition = condition.semantic(sc);
        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        LocalVariables c;
        uint u1;
        uint u2;

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;
        auto marksave = irs.mark();

        irs.continueTarget = this;
        irs.breakTarget = this;

        u1 = irs.getIP();
        continueIP = u1;
        c = irs.alloc(1);
        condition.toIR(irs, c[0]);
        u2 = irs.getIP();
        if (condition.isBooleanResult)
            irs.gen!(Opcode.JFB)(loc, 0, c[0]);
        else
            irs.gen!(Opcode.JF)(loc, 0, c[0]);
        bdy.toIR(irs);
        irs.gen!(Opcode.Jmp)(loc, u1 - irs.getIP);
        irs.patchJmp(u2, irs.getIP);
        breakIP = irs.getIP();

        irs.release(c);
        irs.release(marksave);
        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        condition = null;
        bdy = null;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override size_t getContinue() const
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }

private:
    Expression condition;
    Statement bdy;
    size_t breakIP;
    size_t continueIP;
    ScopeStatement scopeContext;
}

/******************************** ForStatement ***************************/

final class ForStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Statement init, Expression condition, Expression increment,
         Statement bdy)
    {
        super(loc);
        this.init = init;
        this.condition = condition;
        this.increment = increment;
        this.bdy = bdy;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        if(init)
            init = init.semantic(sc);
        if(condition)
            condition = condition.semantic(sc);
        if(increment)
            increment = increment.semantic(sc);

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        if(bdy)
            bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        import std.math : isNaN;

        uint u1;
        uint u2 = 0;    // unneeded initialization keeps lint happy

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;
        auto marksave = irs.mark();

        irs.continueTarget = this;
        irs.breakTarget = this;

        if(init)
            init.toIR(irs);
        u1 = irs.getIP;
        if(condition)
        {
            if(condition.op == Tok.Less || condition.op == Tok.Lessequal)
            {
                BinExp be = cast(BinExp)condition;
                RealExpression re;
                LocalVariables b;
                LocalVariables c;

                b = irs.alloc(1);
                be.e1.toIR(irs, b[0]);
                re = cast(RealExpression)be.e2;
                if(be.e2.op == Tok.Real && !isNaN(re.value))
                {
                    u2 = irs.getIP();
                    if (condition.op == Tok.Less)
                        irs.gen!(Opcode.JLTC)(loc, 0, b[0], re.value);
                    else
                        irs.gen!(Opcode.JLEC)(loc, 0, b[0], re.value);
                }
                else
                {
                    c = irs.alloc(1);
                    be.e2.toIR(irs, c[0]);
                    u2 = irs.getIP;
                    if (condition.op == Tok.Less)
                        irs.gen!(Opcode.JLT)(loc, 0, b[0], c[0]);
                    else
                        irs.gen!(Opcode.JLE)(loc, 0, b[0], c[0]);
                }
            }
            else
            {
                LocalVariables c;

                c = irs.alloc(1);
                condition.toIR(irs, c[0]);
                u2 = irs.getIP;
                if (condition.isBooleanResult)
                    irs.gen!(Opcode.JFB)(loc, 0, c[0]);
                else
                    irs.gen!(Opcode.JF)(loc, 0, c[0]);
            }
        }
        bdy.toIR(irs);
        continueIP = irs.getIP;
        if(increment)
            increment.toIR(irs, 0);
        irs.gen!(Opcode.Jmp)(loc, u1 - irs.getIP);
        if(condition)
            irs.patchJmp(u2, irs.getIP);

        breakIP = irs.getIP;

        irs.release(marksave);
        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;

        // Help GC
        init = null;
        condition = null;
        bdy = null;
        increment = null;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override size_t getContinue() const
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
private:
    Statement init;
    Expression condition;
    Expression increment;
    Statement bdy;
    size_t breakIP;
    size_t continueIP;
    ScopeStatement scopeContext;

}

/******************************** ForInStatement ***************************/

final class ForInStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Statement init, Expression inexp, Statement bdy)
    {
        super(loc);
        this.init = init;
        this.inexp = inexp;
        this.bdy = bdy;
        breakIP = ~0u;
        continueIP = ~0u;
        scopeContext = null;
    }

    override Statement semantic(Scope* sc)
    {
        Statement continueSave = sc.continueTarget;
        Statement breakSave = sc.breakTarget;

        init = init.semantic(sc);

        if(init.st == StatementType.ExpStatement)
        {
            ExpStatement es;

            es = cast(ExpStatement)(init);
            es.exp.checkLvalue(sc);
        }
        else if(init.st == StatementType.VarStatement)
        {
        }
        else
        {
            error(sc, InitNotExpressionError);
            return null;
        }

        inexp = inexp.semantic(sc);

        scopeContext = sc.scopeContext;
        sc.continueTarget = this;
        sc.breakTarget = this;

        bdy = bdy.semantic(sc);

        sc.continueTarget = continueSave;
        sc.breakTarget = breakSave;

        return this;
    }

    override TopStatement ImpliedReturn()
    {
        bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        LocalVariables e;
        LocalVariables iter;
        ExpStatement es;
        VarStatement vs;
        idx_t base;
        IR property;
        OpOffset opoff;
        auto marksave = irs.mark();

        e = irs.alloc(1);
        inexp.toIR(irs, e[0]);
        iter = irs.alloc(1);
        irs.gen!(Opcode.Iter)(loc, iter[0], e[0]);

        Statement continueSave = irs.continueTarget;
        Statement breakSave = irs.breakTarget;

        irs.continueTarget = this;
        irs.breakTarget = this;

        if(init.st == StatementType.ExpStatement)
        {
            es = cast(ExpStatement)(init);
            es.exp.toLvalue(irs, base, &property, opoff);
        }
        else if(init.st == StatementType.VarStatement)
        {
            VarDeclaration vd;

            vs = cast(VarStatement)(init);
            assert(vs.vardecls.length == 1);
            vd = vs.vardecls[0];

            property.id = Identifier.build(vd.name.toString);
            opoff = OpOffset.Scope;
            base = ~0u;
        }
        else
        {   // Error already reported by semantic()
            return;
        }

        continueIP = irs.getIP;
        final switch (opoff)
        {
        case OpOffset.None:
            irs.gen!(Opcode.Next)(loc, 0, base, property.index, iter[0]);
            break;
        case OpOffset.S:
            irs.gen!(Opcode.NextS)(loc, 0, base, property.id, iter[0]);
            break;
        case OpOffset.Scope:
            irs.gen!(Opcode.NextScope)(loc, 0, property.id, iter[0]);
            break;
        case OpOffset.V:
            assert(0);
        }
        bdy.toIR(irs);
        irs.gen!(Opcode.Jmp)(loc, continueIP - irs.getIP);
        irs.patchJmp(continueIP, irs.getIP);

        breakIP = irs.getIP();

        irs.continueTarget = continueSave;
        irs.breakTarget = breakSave;
        irs.release(marksave);

        // Help GC
        init = null;
        inexp = null;
        bdy = null;
    }

    override size_t getBreak() const
    {
        return breakIP;
    }

    override size_t getContinue() const
    {
        return continueIP;
    }

    override ScopeStatement getScope()
    {
        return scopeContext;
    }
private:
    Statement init;
    Expression inexp;
    Statement bdy;
    size_t breakIP;
    size_t continueIP;
    ScopeStatement scopeContext;
}

/******************************** ScopeStatement ***************************/

class ScopeStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc)
    {
        super(loc);
        enclosingScope = null;
        depth = 1;
        npops = 1;
    }

protected:
    ScopeStatement enclosingScope;
    int depth;                  // syntactical nesting level of ScopeStatement's
    int npops;                  // how many items added to scope chain
}

/******************************** WithStatement ***************************/

final class WithStatement : ScopeStatement
{
    @nogc pure nothrow
    this(Loc loc, Expression exp, Statement bdy)
    {
        super(loc);
        this.exp = exp;
        this.bdy = bdy;
    }

    override Statement semantic(Scope* sc)
    {
        exp = exp.semantic(sc);

        enclosingScope = sc.scopeContext;
        sc.scopeContext = this;

        // So enclosing FunctionDeclaration knows how deep the With's
        // can nest
        if(enclosingScope)
            depth = enclosingScope.depth + 1;
        if(depth > sc.funcdef.withdepth)
            sc.funcdef.withdepth = depth;

        sc.nestDepth++;
        bdy = bdy.semantic(sc);
        sc.nestDepth--;

        sc.scopeContext = enclosingScope;
        return this;
    }

    override TopStatement ImpliedReturn()
    {
        bdy = cast(Statement)bdy.ImpliedReturn();
        return this;
    }

    override void toIR(IRstate* irs)
    {
        LocalVariables c;
        auto marksave = irs.mark;

        irs.scopeContext = this;

        c = irs.alloc(1);
        exp.toIR(irs, c[0]);
        irs.gen!(Opcode.Push)(loc, c[0]);
        bdy.toIR(irs);
        irs.gen!(Opcode.Pop)(loc);

        irs.scopeContext = enclosingScope;
        irs.release(c);
        irs.release(marksave);

        // Help GC
        exp = null;
        bdy = null;
    }

private:
    Expression exp;
    Statement bdy;
}

/******************************** ContinueStatement ***************************/

final class ContinueStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Identifier* ident)
    {
        super(loc);
        this.ident = ident;
        target = null;
    }

    override Statement semantic(Scope* sc)
    {
        if(ident == null)
        {
            target = sc.continueTarget;
            if(!target)
            {
                error(sc, MisplacedContinueError);
                return null;
            }
        }
        else
        {
            LabelSymbol ls;

            ls = sc.searchLabel(ident);
            if(!ls || !ls.statement)
            {
                error(sc, UndefinedStatementLabelError(ident.toString));
                return null;
            }
            else
                target = ls.statement;
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        ScopeStatement tw;

        tw = target.getScope;
        for(w = irs.scopeContext; !(w is tw); w = w.enclosingScope)
        {
            assert(w);
            irs.pops(w.npops);
        }
        irs.addFixup(irs.getIP());
        irs.gen!IRJmpToStatement(loc, this);
    }

    override @safe @nogc pure nothrow
    uint getTarget() const
    {
        assert(target);
        return target.getContinue;
    }
private:
    Identifier* ident;
    Statement target;
}

/******************************** BreakStatement ***************************/

final class BreakStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Identifier* ident)
    {
        super(loc);
        this.ident = ident;
        target = null;
    }

    override Statement semantic(Scope* sc)
    {
//      writef("BreakStatement.semantic(%p)\n", sc);
        if(ident == null)
        {
            target = sc.breakTarget;
            if(!target)
            {
                error(sc, MisplacedBreakError);
                return null;
            }
        }
        else
        {
            LabelSymbol ls;

            ls = sc.searchLabel(ident);
            if(!ls || !ls.statement)
            {
                error(sc, UndefinedStatementLabelError(ident.toString));
                return null;
            }
            else if(!sc.breakTarget)
            {
                error(sc, MisplacedBreakError);
            }
            else{
                //Scope* s;
                //for(s = sc; s && s != ls.statement.whichScope; s = s.enclosing){ }
                if(ls.statement.whichScope == *sc)
                    error(sc, CantBreakInternalError(ls.ident.value.text));
                target = ls.statement;
            }
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        ScopeStatement tw;

        assert(target);
        tw = target.getScope;
        for(w = irs.scopeContext; !(w is tw); w = w.enclosingScope)
        {
            assert(w);
            irs.pops(w.npops);
        }

        irs.addFixup(irs.getIP());
        irs.gen!IRJmpToStatement(loc, this);
    }

    override uint getTarget() const
    {
        assert(target);
        return target.getBreak;
    }

private:
    Identifier* ident;
    Statement target;
}

/******************************** GotoStatement ***************************/

final class GotoStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Identifier * ident)
    {
        super(loc);
        this.ident = ident;
        label = null;
    }

    override Statement semantic(Scope* sc)
    {
        LabelSymbol ls;

        ls = sc.searchLabel(ident);
        if(!ls)
        {
            ls = new LabelSymbol(loc, ident, null);
            sc.insertLabel(ls);
        }
        label = ls;
        return this;
    }

    override void toIR(IRstate* irs)
    {
        assert(label);

        // Determine how many with pops we need to do
        for(ScopeStatement w = irs.scopeContext;; w = w.enclosingScope)
        {
            if(!w)
            {
                if(label.statement.scopeContext)
                {
                    assert(0); // BUG: should do next statement instead
                    //script.error(errmsgtbl[ERR_GOTO_INTO_WITH]);
                }
                break;
            }
            if(w is label.statement.scopeContext)
                break;
            irs.pops(w.npops);
        }

        irs.addFixup(irs.getIP());
        irs.gen!IRJmpToStatement(loc, this);
    }

    override @safe @nogc pure nothrow
    uint getTarget() const
    {
        return label.statement.getGoto;
    }

private:
    Identifier* ident;
    LabelSymbol label;
}

/******************************** ReturnStatement ***************************/

final class ReturnStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);

        // Don't allow return from eval functions or global function
        if(sc.funcdef.iseval || sc.funcdef.isglobal)
            error(sc, MisplacedReturnError);

        return this;
    }

    override void toIR(IRstate* irs)
    {
        ScopeStatement w;
        int npops;

        npops = 0;
        for(w = irs.scopeContext; w; w = w.enclosingScope)
            npops += w.npops;

        if(exp)
        {
            auto e = irs.alloc(1);
            exp.toIR(irs, e[0]);
            if(npops)
            {
                irs.gen!(Opcode.ImpRet)(loc, e[0]);
                irs.pops(npops);
                irs.gen!(Opcode.Ret)(loc);
            }
            else
                irs.gen!(Opcode.RetExp)(loc, e[0]);
            irs.release(e);
        }
        else
        {
            if(npops)
                irs.pops(npops);
            irs.gen!(Opcode.Ret)(loc);
        }

        // Help GC
        exp = null;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        //writef("ReturnStatement.toBuffer()\n");
        sink("return ");
        if(exp)
            exp.toBuffer(sink);
        sink(";\n");
    }

private:
    Expression exp;
}

/******************************** ImpliedReturnStatement ***************************/

// Same as ReturnStatement, except that the return value is set but the
// function does not actually return. Useful for setting the return
// value for loop bodies.

final class ImpliedReturnStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);
        return this;
    }

    override void toIR(IRstate* irs)
    {
        if(exp)
        {
            auto e = irs.alloc(1);
            exp.toIR(irs, e[0]);
            irs.gen!(Opcode.ImpRet)(loc, e[0]);
            irs.release(e);

            // Help GC
            exp = null;
        }
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        if(exp)
            exp.toBuffer(sink);
        sink(";\n");
    }

private:
    Expression exp;
}

/******************************** ThrowStatement ***************************/

final class ThrowStatement : Statement
{
    @safe @nogc pure nothrow
    this(Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement semantic(Scope* sc)
    {
        if(exp)
            exp = exp.semantic(sc);
        else
        {
            error(sc, NoThrowExpressionError);
            return new EmptyStatement(loc);
        }
        return this;
    }

    override void toIR(IRstate* irs)
    {
        assert(exp);
        auto e = irs.alloc(1);
        exp.toIR(irs, e[0]);
        irs.gen!(Opcode.Throw)(loc, e[0]);
        irs.release(e);

        // Help GC
        exp = null;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink("throw ");
        if(exp)
            exp.toBuffer(sink);
        sink(";\n");
    }

private:
    Expression exp;
}

/******************************** TryStatement ***************************/

final class TryStatement : ScopeStatement
{
    @safe @nogc pure nothrow
    this(Loc loc, Statement bdy, Identifier* catchident, Statement catchbdy,
         Statement finalbdy)
    {
        super(loc);
        this.bdy = bdy;
        this.catchident = catchident;
        this.catchbdy = catchbdy;
        this.finalbdy = finalbdy;
        if(catchbdy && finalbdy)
            npops = 2;          // 2 items in scope chain
    }

    override Statement semantic(Scope* sc)
    {
        enclosingScope = sc.scopeContext;
        sc.scopeContext = this;

        // So enclosing FunctionDeclaration knows how deep the With's
        // can nest
        if(enclosingScope)
            depth = enclosingScope.depth + 1;
        if(depth > sc.funcdef.withdepth)
            sc.funcdef.withdepth = depth;

        bdy.semantic(sc);
        if(catchbdy)
            catchbdy.semantic(sc);
        if(finalbdy)
            finalbdy.semantic(sc);

        sc.scopeContext = enclosingScope;
        return this;
    }

    override void toIR(IRstate* irs)
    {
        size_t f;
        size_t c;
        size_t e;
        size_t e2;
        auto marksave = irs.mark();

        irs.scopeContext = this;
        if(finalbdy)
        {
            f = irs.getIP();
            irs.gen!(Opcode.TryFinally)(loc, 0);
            if(catchbdy)
            {
                c = irs.getIP;
                irs.gen!(Opcode.TryCatch)(
                    loc, 0, Identifier.build(catchident.toString));
                bdy.toIR(irs);
                irs.gen!(Opcode.Pop)(loc);           // remove catch clause
                irs.gen!(Opcode.Pop)(loc);           // call finalbdy

                e = irs.getIP;
                irs.gen!(Opcode.Jmp)(loc, 0);
                irs.patchJmp(c, irs.getIP);
                catchbdy.toIR(irs);
                irs.gen!(Opcode.Pop)(loc);           // remove catch object
                irs.gen!(Opcode.Pop)(loc);           // call finalbdy code
                e2 = irs.getIP;
                irs.gen!(Opcode.Jmp)(loc, 0);        // jmp past finalbdy

                irs.patchJmp(f, irs.getIP);
                irs.scopeContext = enclosingScope;
                finalbdy.toIR(irs);
                irs.gen!(Opcode.FinallyRet)(loc);
                irs.patchJmp(e, irs.getIP);
                irs.patchJmp(e2, irs.getIP);
            }
            else // finalbdy only
            {
                bdy.toIR(irs);
                irs.gen!(Opcode.Pop)(loc);
                e = irs.getIP;
                irs.gen!(Opcode.Jmp)(loc, 0);
                irs.patchJmp(f, irs.getIP);
                irs.scopeContext = enclosingScope;
                finalbdy.toIR(irs);
                irs.gen!(Opcode.FinallyRet)(loc);
                irs.patchJmp(e, irs.getIP);
            }
        }
        else // catchbdy only
        {
            c = irs.getIP;
            irs.gen!(Opcode.TryCatch)(
                loc, 0, Identifier.build(catchident.toString));
            bdy.toIR(irs);
            irs.gen!(Opcode.Pop)(loc);
            e = irs.getIP;
            irs.gen!(Opcode.Jmp)(loc, 0);
            irs.patchJmp(c, irs.getIP);
            catchbdy.toIR(irs);
            irs.gen!(Opcode.Pop)(loc);
            irs.patchJmp(e, irs.getIP);
        }
        irs.scopeContext = enclosingScope;
        irs.release(marksave);

        // Help GC
        bdy = null;
        catchident = null;
        catchbdy = null;
        finalbdy = null;
    }

    override void toBuffer(scope void delegate(in tchar[]) sink) const
    {
        sink("try\n");
        bdy.toBuffer(sink);
        if(catchident)
        {
            sink("catch (");
            sink(catchident.toString);
            sink(")\n");
        }
        if(catchbdy)
            catchbdy.toBuffer(sink);
        if(finalbdy)
        {
            sink("finally\n");
            finalbdy.toBuffer(sink);
        }
    }

private:
    Statement bdy;
    Identifier* catchident;
    Statement catchbdy;
    Statement finalbdy;
}
