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


module dmdscript.parse;

import dmdscript.lexer : Lexer, Mode;
debug import std.stdio;

class Parser(Mode MODE) : Lexer!MODE
{
    import dmdscript.functiondefinition : FunctionDefinition;
    import dmdscript.primitive : string_t, Identifier;
    import dmdscript.exception : ScriptException;
    import dmdscript.lexer : IdTable, Tok;
    import dmdscript.statement : TopStatement, Statement;
    import dmdscript.expression;
    import dmdscript.errmsgs;
    import dmdscript.ir : Opcode;
    import dmdscript.statement;

    FunctionDefinition lastnamedfunc;

    this(string_t sourcename, string_t base, IdTable baseTable = null)
    {
        //writefln("Parser.this(base = '%s')", base);
        super(sourcename, base, baseTable);
        nextToken();            // start up the scanner
    }


    /**********************************************
     */
    static ScriptException parseFunctionDefinition(
        out FunctionDefinition pfd, string_t params, string_t bdy)
    {
        import std.array : Appender;
        import dmdscript.property : PropertyKey;

        Appender!(Identifier[]) parameters;
        Appender!(TopStatement[]) topstatements;
        FunctionDefinition fd = null;

        auto p = new Parser!(Mode.None)("anonymous", params);

        // Parse FormalParameterList
        while(p.token != Tok.Eof)
        {
            if(p.token != Tok.Identifier)
            {
                p.error(FplExpectedIdentifierError(p.token.toString));
                goto Lreturn;
            }
            parameters.put(p.token.ident);
            p.nextToken();
            if(p.token == Tok.Comma)
                p.nextToken();
            else if(p.token == Tok.Eof)
                break;
            else
            {
                p.error(FplExpectedCommaError(p.token.toString));
                goto Lreturn;
            }
        }
        if(p.exception !is null)
            goto Lreturn;

        // Parse StatementList
        p = new Parser!(Mode.None)("anonymous", bdy);
        for(;; )
        {
            if(p.token == Tok.Eof)
                break;
            topstatements.put(p.parseStatement());
        }

        fd = new FunctionDefinition(bdy, 0, 0, null, null, parameters.data,
                                    topstatements.data);

        Lreturn:
        pfd = fd;
        return p.exception;
    }

    /**********************************************
     */
    nothrow
    ScriptException parseProgram(out TopStatement[] topstatements)
    {
        try
        {
            topstatements = parseTopStatements();
            check(Tok.Eof);
            //writef("parseProgram done\n");
            //clearstack();
        }
        catch(ScriptException se)
        {
            exception = se;
        }
        catch(Throwable t)
        {
            import dmdscript.protoerror : syntaxerror;
            exception = new ScriptException(syntaxerror.Text,
                                            "Unexpected exception.", t);
        }
        return exception;
    }

private:
    enum Flag : uint
    {
        normal          = 0,
        initial         = 1,

        allowIn         = 0,
        noIn            = 2,

        // Flag if we're in the for statement header, as
        // automatic semicolon insertion is suppressed inside it.
        inForHeader     = 4,

        isModule        = 8,
    }
    Flag flags;

    TopStatement[] parseTopStatements()
    {
        import std.array : Appender;
        Appender!(TopStatement[]) topstatements;

        //writefln("parseTopStatements()");
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Function:
                topstatements.put(parseFunction!(FunctionFlag.statement));
                break;

            case Tok.Eof:
                return topstatements.data;

            case Tok.Rbrace:
                return topstatements.data;

            default:
                topstatements.put(parseStatement());
                break;
            }
        }
        assert(0);
    }

    /***************************
     * flag:
     *	0	Function statement
     *	1	Function literal
     */

    enum FunctionFlag
    {
        statement = 0,
        literal   = 1,
        property  = 2,
    }

    auto parseFunction(FunctionFlag flag)()
    {
        import std.array : Appender;
        import dmdscript.property : PropertyKey;

        Identifier name;
        Appender!(Identifier[]) parameters;
        TopStatement[] topstatements;
        FunctionDefinition f;
        Expression e = null;
        uint linnum;

        linnum = currentline;
        nextToken();
        name = null;

        static if (flag == FunctionFlag.property)
            name = getPropertyName;
        else
        {
            if (token == Tok.Identifier)
                name = token.ident;
        }

        if(name !is null)
        {
            nextToken();

            static if (flag == FunctionFlag.statement)
            {
                if(token == Tok.Dot)
                {
                    // Regard:
                    //	function A.B() { }
                    // as:
                    //	A.B = function() { }
                    // This is not ECMA, but a jscript feature

                    e = new IdentifierExpression(linnum, name);
                    name = null;

                    while(token == Tok.Dot)
                    {
                        nextToken();
                        if(token == Tok.Identifier)
                        {
                            e = new DotExp(linnum, e, token.ident);
                            nextToken();
                        }
                        else
                        {
                            error(ExpectedIdentifier2paramError(
                                      ".", token.toString));
                            break;
                        }
                    }
                }
            }
        }

        check(Tok.Lparen);
        if(token == Tok.Rparen)
            nextToken();
        else
        {
            for(;; )
            {
                if(token == Tok.Identifier)
                {
                    parameters.put(token.ident);
                    nextToken();
                    if(token == Tok.Comma)
                    {
                        nextToken();
                        continue;
                    }
                    if(!check(Tok.Rparen))
                        break;
                }
                else
                    error(ExpectedIdentifierError);
                break;
            }
        }

        check(Tok.Lbrace);
        topstatements = parseTopStatements();
        check(Tok.Rbrace);

        f = new FunctionDefinition(base, linnum, 0, name, sourcename,
                                   parameters.data, topstatements);
        static if (flag == FunctionFlag.literal ||
                   flag == FunctionFlag.property)
        {
            f.isliteral = true;
            return f;
        }
        else
        {
            f.isliteral = false;

            lastnamedfunc = f;

            assert (f !is null);
            if(e is null)
                return cast(TopStatement)f;

            // Construct:
            //	A.B = function() { }

            auto e2 = new FunctionLiteral(linnum, f);

            e = new AssignExp(linnum, e, e2);

            auto s = new ExpStatement(linnum, e);

            return cast(TopStatement)s;
        }
    }

    /*****************************************
     */

    Statement parseStatement()
    {
        import dmdscript.property : PropertyKey;
        import dmdscript.lexer : Token;

        Statement s;
        Token* t;
        uint linnum;

        //writefln("parseStatement()");
        linnum = currentline;
        switch(token.value)
        {
        case Tok.Identifier:
        case Tok.This:
            // Need to look ahead to see if it is a declaration, label, or expression
            t = peek(&token);
            if(t.value == Tok.Colon && token == Tok.Identifier)
            {       // It's a label
                auto ident = token.ident;
                nextToken();
                nextToken();
                s = parseStatement();
                s = new LabelStatement(linnum, ident, s);
            }
            else if(t.value == Tok.Assign ||
                    t.value == Tok.Dot ||
                    t.value == Tok.Lbracket)
            {
                auto exp = parseExpression();
                parseOptionalSemi();
                s = new ExpStatement(linnum, exp);
            }
            else
            {
                auto exp = parseExpression(Flag.initial);
                parseOptionalSemi();
                s = new ExpStatement(linnum, exp);
            }
            break;

        case Tok.Real:
        case Tok.String:
        case Tok.Delete:
        case Tok.Lparen:
        case Tok.Plusplus:
        case Tok.Minusminus:
        case Tok.Plus:
        case Tok.Minus:
        case Tok.Not:
        case Tok.Tilde:
        case Tok.Typeof:
        case Tok.Null:
        case Tok.New:
        case Tok.True:
        case Tok.False:
        case Tok.Void:
        case Tok.Lbracket:
        {
          auto exp = parseExpression(Flag.initial);
          parseOptionalSemi();
          s = new ExpStatement(linnum, exp);
          break;
        }
        case Tok.Var:
        {
            Identifier ident;
            Expression init;
            VarDeclaration v;
            VarStatement vs;

            vs = new VarStatement(linnum);
            s = vs;

            nextToken();
            for(;; )
            {
                linnum = currentline;

                ident = getIdentifierName;
                if(ident is null)
                {
                    error(ExpectedIdentifierParamError(token.toString));
                    break;
                }
                init = null;
                nextToken();
                if(token == Tok.Assign)
                {
                    Flag flags_save;

                    nextToken();
                    flags_save = flags;
                    flags &= ~Flag.initial;
                    init = parseAssignExp();
                    flags = flags_save;
                }
                v = new VarDeclaration(linnum, ident, init);
                vs.vardecls ~= v;
                if(token != Tok.Comma)
                    break;
                nextToken();
            }
            if(!(flags & Flag.inForHeader))
                parseOptionalSemi();
            break;
        }

        case Tok.Lbrace:
        {
          nextToken();
          auto bs = new BlockStatement(linnum);
          /*while(token.value != Tok.Rbrace)
          {
              if(token.value == Tok.Eof)
              {         
                  error(ERR_UNTERMINATED_BLOCK);
                  break;
              }
              bs.statements ~= parseStatement();
          }*/
          bs.statements ~= parseTopStatements();
          s = bs;
          nextToken();

          // The following is to accommodate the jscript bug:
          //	if (i) {return(0);}; else ...
          /*if(token.value == Tok.Semicolon)
              nextToken();*/

          break;
        }
        case Tok.If:
        {
            Expression condition;
            Statement ifbody;
            Statement elsebody;

            nextToken();
            condition = parseParenExp();
            ifbody = parseStatement();
            if(token == Tok.Else)
            {
                nextToken();
                elsebody = parseStatement();
            }
            else
                elsebody = null;
            s = new IfStatement(linnum, condition, ifbody, elsebody);
            break;
        }
        case Tok.Switch:
        {
            nextToken();
            auto condition = parseParenExp();
            auto bdy = parseStatement();
            s = new SwitchStatement(linnum, condition, bdy);
            break;
        }
        case Tok.Case:
        {
            nextToken();
            auto exp = parseExpression();
            check(Tok.Colon);
            s = new CaseStatement(linnum, exp);
            break;
        }
        case Tok.Default:
            nextToken();
            check(Tok.Colon);
            s = new DefaultStatement(linnum);
            break;

        case Tok.While:
        {
          nextToken();
          auto condition = parseParenExp();
          auto bdy = parseStatement();
          s = new WhileStatement(linnum, condition, bdy);
          break;
        }
        case Tok.Semicolon:
            nextToken();
            s = new EmptyStatement(linnum);
            break;

        case Tok.Do:
        {
            nextToken();
            auto bdy = parseStatement();
            check(Tok.While);
            auto condition = parseParenExp();
            //We do what most browsers now do, ie allow missing ';' 
            //like " do{ statement; }while(e) statement; " and that even w/o linebreak
            if(token == Tok.Semicolon)
                nextToken();
            //parseOptionalSemi();
            s = new DoStatement(linnum, bdy, condition);
            break;
        }
        case Tok.For:
        {
            Statement init;
            Statement bdy;

            nextToken();
            flags |= Flag.inForHeader;
            check(Tok.Lparen);
            if(token == Tok.Var)
            {
                init = parseStatement();
            }
            else
            {
                auto e = parseOptionalExpression(Flag.noIn);
                init = e ? new ExpStatement(linnum, e) : null;
            }

            if(token == Tok.Semicolon)
            {
                nextToken();
                auto condition = parseOptionalExpression();
                check(Tok.Semicolon);
                auto increment = parseOptionalExpression();
                check(Tok.Rparen);
                flags &= ~Flag.inForHeader;

                bdy = parseStatement();
                s = new ForStatement(linnum, init, condition, increment, bdy);
            }
            else if(token == Tok.In)
            {
                Expression inexp;
                VarStatement vs;

                // Check that there's only one VarDeclaration
                // in init.
                if(init.st == StatementType.VarStatement)
                {
                    vs = cast(VarStatement)init;
                    if(vs.vardecls.length != 1)
                        error(TooManyInVarsError(vs.vardecls.length));
                }

                nextToken();
                inexp = parseExpression();
                check(Tok.Rparen);
                flags &= ~Flag.inForHeader;
                bdy = parseStatement();
                s = new ForInStatement(linnum, init, inexp, bdy);
            }
            else
            {
                error(InExpectedError(token.toString));
                s = null;
            }
            break;
        }

        case Tok.With:
        {
            nextToken();
            auto exp = parseParenExp();
            auto bdy = parseStatement();
            s = new WithStatement(linnum, exp, bdy);
            break;
        }
        case Tok.Break:
        {
            Identifier ident;

            nextToken();
            if(token.sawLineTerminator && token != Tok.Semicolon)
            {         // Assume we saw a semicolon
                ident = null;
            }
            else
            {
                if(token == Tok.Identifier)
                {
                    ident = token.ident;
                    nextToken();
                }
                else
                    ident = null;
                parseOptionalSemi();
            }
            s = new BreakStatement(linnum, ident);
            break;
        }
        case Tok.Continue:
        {
            Identifier ident;

            nextToken();
            if(token.sawLineTerminator && token != Tok.Semicolon)
            {         // Assume we saw a semicolon
                ident = null;
            }
            else
            {
                if(token == Tok.Identifier)
                {
                    ident = token.ident;
                    nextToken();
                }
                else
                    ident = null;
                parseOptionalSemi();
            }
            s = new ContinueStatement(linnum, ident);
            break;
        }
        case Tok.Goto:
        {
            Identifier ident;

            nextToken();
            if(token != Tok.Identifier)
            {
                error(GotoLabelExpectedError(token.toString));
                s = null;
                break;
            }
            ident = token.ident;
            nextToken();
            parseOptionalSemi();
            s = new GotoStatement(linnum, ident);
            break;
        }
        case Tok.Return:
        {
            nextToken();
            if(token.sawLineTerminator && token != Tok.Semicolon)
            {         // Assume we saw a semicolon
                s = new ReturnStatement(linnum, null);
            }
            else
            {
                auto exp = parseOptionalExpression();
                parseOptionalSemi();
                s = new ReturnStatement(linnum, exp);
            }
            break;
        }
        case Tok.Throw:
        {
            auto nt = peek(&token);
            if (linnum != currentline)
            {
                error(ExpectedGenericError("newline", "Expression"));
                break;
            }

            nextToken();
            auto exp = parseExpression();
            parseOptionalSemi();
            s = new ThrowStatement(linnum, exp);
            break;
        }
        case Tok.Try:
        {
            Statement bdy;
            Identifier catchident;
            Statement catchbody;
            Statement finalbody;

            nextToken();
            bdy = parseStatement();
            if(token == Tok.Catch)
            {
                nextToken();
                check(Tok.Lparen);
                catchident = null;
                if(token.value == Tok.Identifier)
                    catchident = token.ident;
                check(Tok.Identifier);
                check(Tok.Rparen);
                catchbody = parseStatement();
            }
            else
            {
                catchident = null;
                catchbody = null;
            }

            if(token == Tok.Finally)
            {
                nextToken();
                finalbody = parseStatement();
            }
            else
                finalbody = null;

            if(!catchbody && !finalbody)
            {
                error(TryCatchExpectedError);
                s = null;
            }
            else
            {
                s = new TryStatement(linnum, bdy, catchident, catchbody,
                                     finalbody);
            }
            break;
        }
        default:
            error(StatementExpectedError(token.toString));
            nextToken();
            s = null;
            break;
        }

        //writefln("parseStatement() done");
        return s;
    }



    Expression parseOptionalExpression(Flag flags = Flag.normal)
    {
        Expression e;

        if(token == Tok.Semicolon || token == Tok.Rparen)
            e = null;
        else
            e = parseExpression(flags);
        return e;
    }

    // Follow ECMA 7.8.1 rules for inserting semicolons
    void parseOptionalSemi()
    {
        if(token != Tok.Eof && token != Tok.Rbrace &&
           !(token.sawLineTerminator && (flags & Flag.inForHeader) == 0))
            check(Tok.Semicolon);
    }

    int check(Tok value)
    {
        import dmdscript.lexer : Token;
        if(token != value)
        {
            error(ExpectedGenericError(token.toString, Token.toString(value)));
            return 0;
        }
        nextToken();
        return 1;
    }

    //--------------------------------------------------------------------
    // Expression Parser
    Expression parseParenExp()
    {
        Expression e;

        check(Tok.Lparen);
        e = parseExpression();
        check(Tok.Rparen);
        return e;
    }

    Expression parsePrimaryExp(int innew)
    {
        Expression e;
        uint linnum;

        linnum = currentline;
        switch(token.value)
        {
        case Tok.This:
            e = new ThisExpression(linnum);
            nextToken();
            break;

        case Tok.Null:
            e = new NullExpression(linnum);
            nextToken();
            break;
        case Tok.True:
            e = new BooleanExpression(linnum, true);
            nextToken();
            break;

        case Tok.False:
            e = new BooleanExpression(linnum, false);
            nextToken();
            break;

        case Tok.Real:
            e = new RealExpression(linnum, token.realvalue);
            nextToken();
            break;

        case Tok.String:
            e = new StringExpression(linnum, token.str);
            token.str = null;        // release to gc
            nextToken();
            break;

        case Tok.Regexp:
            e = new RegExpLiteral(linnum, token.str);
            token.str = null;        // release to gc
            nextToken();
            break;

        case Tok.Identifier:
            e = new IdentifierExpression(linnum, token.ident);
            token.ident = null;                 // release to gc
            nextToken();
            break;

        case Tok.Lparen:
            e = parseParenExp();
            break;

        case Tok.Lbracket:
            e = parseArrayLiteral();
            break;

        case Tok.Lbrace:
            /*if(flags & initial)
            {
                error(ERR_OBJ_LITERAL_IN_INITIALIZER);
                nextToken();
                return null;
            }*/
            e = parseObjectLiteral();
            break;

        case Tok.Function:
            //	    if (flags & initial)
            //		goto Lerror;
            e = parseFunctionLiteral();
            break;

        case Tok.New:
        {
            Expression newarg;
            Expression[] arguments;

            nextToken();
            newarg = parsePrimaryExp(1);
            arguments = parseArguments();
            e = new NewExp(linnum, newarg, arguments);
            break;
        }
        default:
            //	Lerror:
            error(ExpectedExpressionError(token.toString));
            nextToken();
            return null;
        }
        return parsePostExp(e, innew);
    }

    Expression[] parseArguments()
    {
        import std.array : Appender;
        Appender!(Expression[]) arguments;

        if(token == Tok.Lparen)
        {
            nextToken();
            if(token != Tok.Rparen)
            {
                for(;; )
                {
                    arguments.put(parseAssignExp);
                    if(token == Tok.Rparen)
                        break;
                    if(!check(Tok.Comma))
                        break;
                }
            }
            nextToken();
        }
        return arguments.data;
    }

    Expression parseArrayLiteral()
    {
        import std.array : Appender;

        Expression e;
        Appender!(Expression[]) elements;
        uint linnum;

        //writef("parseArrayLiteral()\n");
        linnum = currentline;
        check(Tok.Lbracket);
        if(token != Tok.Rbracket)
        {
            for(;; )
            {
                if(token == Tok.Comma)
                    // Allow things like [1,2,,,3,]
                    // Like Explorer 4, and unlike Netscape, the
                    // trailing , indicates another null element.
                    //Netscape was right - FIXED
                    elements.put(cast(Expression)null);
                else if(token == Tok.Rbracket)
                {
                    //elements ~= cast(Expression)null;
                    break;
                }
                else
                {
                    e = parseAssignExp();
                    elements.put(e);
                    if(token != Tok.Comma)
                        break;
                }
                nextToken();
            }
        }
        check(Tok.Rbracket);
        e = new ArrayLiteral(linnum, elements.data);
        return e;
    }

    Expression parseObjectLiteral()
    {
        import std.array : Appender;

        Expression e;
        Appender!(Field[]) fields;
        uint linnum;

        linnum = currentline;
        check(Tok.Lbrace);
        if(token.value == Tok.Rbrace)
            nextToken();
        else
        {
            for(;; )
            {
                if      (Tok.Set == token)
                {
                    auto fe = parseFunctionLiteral!(FunctionFlag.property);
                    if (fe is null)
                    {
                        error(ExpectedIdentifierError);
                        break;
                    }
                    fields.put(new Field(fe.func.name, fe, Field.Type.Setter));
                    if (token != Tok.Comma)
                        break;
                    nextToken();
                    if (token == Tok.Rbrace)
                        break;

                }
                else if (Tok.Get == token)
                {
                    auto fe = parseFunctionLiteral!(FunctionFlag.property);
                    if (fe is null)
                    {
                        error(ExpectedIdentifierError);
                        break;
                    }
                    fields.put(new Field(fe.func.name, fe, Field.Type.Getter));
                    if (token != Tok.Comma)
                        break;
                    nextToken();
                    if (token == Tok.Rbrace)
                        break;
                }
                else
                {
                    auto ident = getPropertyName;

                    if (ident is null)
                    {
                        error(ExpectedIdentifierError);
                        break;
                    }
                    nextToken();
                    check(Tok.Colon);
                    fields.put(new Field(ident, parseAssignExp()));
                    if(token != Tok.Comma)
                        break;
                    nextToken();
                    if(token == Tok.Rbrace)//allow trailing comma
                        break;
                }
            }
            check(Tok.Rbrace);
        }
        e = new ObjectLiteral(linnum, fields.data);
        return e;
    }

    FunctionLiteral parseFunctionLiteral(
        FunctionFlag FLAG = FunctionFlag.literal)()
    {
        FunctionDefinition f;
        uint linnum;

        linnum = currentline;
        f = parseFunction!FLAG;
        assert (f !is null);
        return new FunctionLiteral(linnum, f);
    }

    Expression parsePostExp(Expression e, int innew)
    {
        uint linnum;

        for(;; )
        {
            linnum = currentline;
            //loc = (line_number)token.ptr;
            switch(token.value)
            {
            case Tok.Dot:
                nextToken();

                if (auto ident = getPropertyName)
                {
                    e = new DotExp(linnum, e, ident);
                }
                else
                {
                    error(ExpectedIdentifier2paramError(".", token.toString));
                    return e;
                }
                break;

            case Tok.Plusplus:
                if(token.sawLineTerminator && !(flags & Flag.inForHeader))
                    goto Linsert;
                e = new PostIncExp(linnum, e);
                break;

            case Tok.Minusminus:
                if(token.sawLineTerminator && !(flags & Flag.inForHeader))
                {
                    Linsert:
                    // insert automatic semicolon
                    insertSemicolon(token.sawLineTerminator);
                    return e;
                }
                e = new PostDecExp(linnum, e);
                break;

            case Tok.Lparen:
            {       // function call
                Expression[] arguments;

                if(innew)
                    return e;
                arguments = parseArguments();
                e = new CallExp(linnum, e, arguments);
                continue;
            }

            case Tok.Lbracket:
            {       // array dereference
                Expression index;
                nextToken();
                index = parseExpression();
                check(Tok.Rbracket);
                e = new ArrayExp(linnum, e, index);
                continue;
            }

            default:
                return e;
            }
            nextToken();
        }
        assert(0);
    }

    Expression parseUnaryExp()
    {
        Expression e;
        uint linnum;

        linnum = currentline;
        switch(token.value)
        {
        case Tok.Plusplus:
            nextToken();
            e = parseUnaryExp();
            e = new PreExp(linnum, Opcode.PreInc, e);
            break;

        case Tok.Minusminus:
            nextToken();
            e = parseUnaryExp();
            e = new PreExp(linnum, Opcode.PreDec, e);
            break;

        case Tok.Minus:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(linnum, Tok.Neg, Opcode.Neg, e);
            break;

        case Tok.Plus:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(linnum, Tok.Pos, Opcode.Pos, e);
            break;

        case Tok.Not:
            nextToken();
            e = parseUnaryExp();
            e = new NotExp(linnum, e);
            break;

        case Tok.Tilde:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(linnum, Tok.Tilde, Opcode.Com, e);
            break;

        case Tok.Delete:
            nextToken();
            e = parsePrimaryExp(0);
            e = new DeleteExp(linnum, e);
            break;

        case Tok.Typeof:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(linnum, Tok.Typeof, Opcode.Typeof, e);
            break;

        case Tok.Void:
            nextToken();
            e = parseUnaryExp();
            e = new XUnaExp(linnum, Tok.Void, Opcode.Undefined, e);
            break;

        default:
            e = parsePrimaryExp(0);
            break;
        }
        return e;
    }

    Expression parseMulExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseUnaryExp();
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Multiply:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(linnum, Tok.Multiply, Opcode.Mul, e, e2);
                continue;

            case Tok.Regexp:
                // Rescan as if it was a "/"
                rescan();
                goto case;
            case Tok.Divide:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(linnum, Tok.Divide, Opcode.Div, e, e2);
                continue;

            case Tok.Percent:
                nextToken();
                e2 = parseUnaryExp();
                e = new XBinExp(linnum, Tok.Percent, Opcode.Mod, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseAddExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseMulExp();
        for(;; )
        {
            switch(token.value)
            {
            case Tok.Plus:
                nextToken();
                e2 = parseMulExp();
                e = new AddExp(linnum, e, e2);
                continue;

            case Tok.Minus:
                nextToken();
                e2 = parseMulExp();
                e = new XBinExp(linnum, Tok.Minus, Opcode.Sub, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseShiftExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseAddExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Shiftleft:      ircode = Opcode.ShL;         goto L1;
            case Tok.Shiftright:     ircode = Opcode.ShR;         goto L1;
            case Tok.Ushiftright:    ircode = Opcode.UShR;        goto L1;

            L1:
                nextToken();
                e2 = parseAddExp();
                e = new XBinExp(linnum, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseRelExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseShiftExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Less:           ircode = Opcode.CLT; goto L1;
            case Tok.Lessequal:      ircode = Opcode.CLE; goto L1;
            case Tok.Greater:        ircode = Opcode.CGT; goto L1;
            case Tok.Greaterequal:   ircode = Opcode.CGE; goto L1;

                L1:
                nextToken();
                e2 = parseShiftExp();
                e = new CmpExp(linnum, op, ircode, e, e2);
                continue;

            case Tok.Instanceof:
                nextToken();
                e2 = parseShiftExp();
                e = new XBinExp(linnum, Tok.Instanceof, Opcode.Instance, e, e2);
                continue;

            case Tok.In:
                if(flags & Flag.noIn)
                    break;              // disallow
                nextToken();
                e2 = parseShiftExp();
                e = new InExp(linnum, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseEqualExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseRelExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Equal:       ircode = Opcode.CEq;        goto L1;
            case Tok.Notequal:    ircode = Opcode.CNE;        goto L1;
            case Tok.Identity:    ircode = Opcode.CID;        goto L1;
            case Tok.Nonidentity: ircode = Opcode.CNID;       goto L1;

                L1:
                nextToken();
                e2 = parseRelExp();
                e = new CmpExp(linnum, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseAndExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseEqualExp();
        while(token == Tok.And)
        {
            nextToken();
            e2 = parseEqualExp();
            e = new XBinExp(linnum, Tok.And, Opcode.And, e, e2);
        }
        return e;
    }

    Expression parseXorExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseAndExp();
        while(token == Tok.Xor)
        {
            nextToken();
            e2 = parseAndExp();
            e = new XBinExp(linnum, Tok.Xor, Opcode.Xor, e, e2);
        }
        return e;
    }

    Expression parseOrExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseXorExp();
        while(token == Tok.Or)
        {
            nextToken();
            e2 = parseXorExp();
            e = new XBinExp(linnum, Tok.Or, Opcode.Or, e, e2);
        }
        return e;
    }

    Expression parseAndAndExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseOrExp();
        while(token == Tok.Andand)
        {
            nextToken();
            e2 = parseOrExp();
            e = new AndAndExp(linnum, e, e2);
        }
        return e;
    }

    Expression parseOrOrExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseAndAndExp();
        while(token == Tok.Oror)
        {
            nextToken();
            e2 = parseAndAndExp();
            e = new OrOrExp(linnum, e, e2);
        }
        return e;
    }

    Expression parseCondExp()
    {
        Expression e;
        Expression e1;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseOrOrExp();
        if(token == Tok.Question)
        {
            nextToken();
            e1 = parseAssignExp();
            check(Tok.Colon);
            e2 = parseAssignExp();
            e = new CondExp(linnum, e, e1, e2);
        }
        return e;
    }

    Expression parseAssignExp()
    {
        Expression e;
        Expression e2;
        uint linnum;

        linnum = currentline;
        e = parseCondExp();
        for(;; )
        {
            Opcode ircode;
            auto op = token.value;

            switch(op)
            {
            case Tok.Assign:
                nextToken();
                e2 = parseAssignExp();
                e = new AssignExp(linnum, e, e2);
                continue;

            case Tok.Plusass:
                nextToken();
                e2 = parseAssignExp();
                e = new AddAssignExp(linnum, e, e2);
                continue;

            case Tok.Minusass:       ircode = Opcode.Sub;  goto L1;
            case Tok.Multiplyass:    ircode = Opcode.Mul;  goto L1;
            case Tok.Divideass:      ircode = Opcode.Div;  goto L1;
            case Tok.Percentass:     ircode = Opcode.Mod;  goto L1;
            case Tok.Andass:         ircode = Opcode.And;  goto L1;
            case Tok.Orass:          ircode = Opcode.Or;   goto L1;
            case Tok.Xorass:         ircode = Opcode.Xor;  goto L1;
            case Tok.Shiftleftass:   ircode = Opcode.ShL;  goto L1;
            case Tok.Shiftrightass:  ircode = Opcode.ShR;  goto L1;
            case Tok.Ushiftrightass: ircode = Opcode.UShR; goto L1;

                L1: nextToken();
                e2 = parseAssignExp();
                e = new BinAssignExp(linnum, op, ircode, e, e2);
                continue;

            default:
                break;
            }
            break;
        }
        return e;
    }

    Expression parseExpression(Flag flags = Flag.normal)
    {
        Expression e;
        Expression e2;
        uint linnum;
        Flag flags_save;

        flags_save = this.flags;
        this.flags = flags;
        linnum = currentline;
        e = parseAssignExp();
        while(token == Tok.Comma)
        {
            nextToken();
            e2 = parseAssignExp();
            e = new CommaExp(linnum, e, e2);
        }
        this.flags = flags_save;
        return e;
    }
}

/********************************* ***************************/

