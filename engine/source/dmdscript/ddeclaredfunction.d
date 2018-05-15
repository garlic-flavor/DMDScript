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

module dmdscript.ddeclaredfunction;

import dmdscript.dfunction : Dconstructor;
debug import std.stdio;

/* ========================== DdeclaredFunction ================== */
///
class DdeclaredFunction : Dconstructor
{
    import dmdscript.callcontext : CallContext;
    import dmdscript.dobject : Dobject;
    import dmdscript.value : DError, Value;
    import dmdscript.functiondefinition : FunctionDefinition;

    FunctionDefinition fd;

private
    Dobject[] scopex;     // Function object's scope chain per 13.2 step 7

    this(CallContext cc, FunctionDefinition fd, Dobject[] scopex)
    {
        import dmdscript.primitive : Key, PropertyKey;
        import dmdscript.property : Property;

        assert (cc);
        assert (cc.dglobal);
        assert (cc.dglobal.functionPrototype);
        assert (fd !is null);

        auto name = fd.name is null ?
            Key.Function : PropertyKey(fd.name.toString);

        super(cc.dglobal.dObject(), cc.dglobal.functionPrototype,
              name, cast(uint)fd.parameters.length);

        assert(GetPrototypeOf);

        this.fd = fd;
        this.scopex = scopex;

        // ECMA 3 13.2
        auto o = cc.dglobal.dObject();        // step 9
        auto val = Value(o);
        // step 11
        DefineOwnProperty(Key.prototype, val, Property.Attribute.DontEnum);
        // step 10
        val.put(this);
        o.DefineOwnProperty(Key.constructor, val, Property.Attribute.DontEnum);

    }

    override DError* Call(CallContext cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        // 1. Create activation object per ECMA 10.1.6
        // 2. Instantiate function variables as properties of
        //    activation object
        // 3. The 'this' value is the activation object

        import core.sys.posix.stdlib : alloca;
        import dmdscript.primitive : Key;
        import dmdscript.dglobal : undefined;
        import dmdscript.darguments : Darguments;
        import dmdscript.property : Property;
        import dmdscript.primitive : PropertyKey;
        import dmdscript.ir : Opcode;
        import dmdscript.opcodes : IR;
        import dmdscript.value : vundefined;
        import dmdscript.callcontext : DefinedFunctionScope;

        Dobject actobj;         // activation object
        Darguments args;
        Value[] locals;
        uint i;
        DError* result;

        // if it's an empty function, just return
        if(fd.code[0].opcode == Opcode.Ret)
        {
            return null;
        }

        // Generate the activation object
        // ECMA v3 10.1.6
        actobj = cc.dglobal.dObject();

        Value vtmp;//should not be referenced by the end of func
        if(fd.name)
        {
           vtmp.put(this);
           actobj.Set(*fd.name, vtmp, Property.Attribute.DontDelete, cc);
        }
        // Instantiate the parameters
        {
            uint a = 0;
            foreach(p; fd.parameters)
            {
                Value* v = (a < arglist.length) ? &arglist[a++] : &undefined;
                actobj.Set(*p, *v, Property.Attribute.DontDelete, cc);
            }
        }

        // Generate the Arguments Object
        // ECMA v3 10.1.8
        args = new Darguments(cc.dglobal.rootPrototype, cc.caller, this,
                              actobj, fd.parameters, arglist);
        vtmp.put(args);
        actobj.Set(Key.arguments, vtmp, Property.Attribute.DontDelete, cc);

        // The following is not specified by ECMA, but seems to be supported
        // by jscript. The url www.grannymail.com has the following code
        // which looks broken to me but works in jscript:
        //
        //	    function MakeArray() {
        //	      this.length = MakeArray.arguments.length
        //	      for (var i = 0; i < this.length; i++)
        //		  this[i+1] = arguments[i]
        //	    }
        //	    var cardpic = new MakeArray("LL","AP","BA","MB","FH","AW","CW","CV","DZ");
        Set(Key.arguments, vtmp, Property.Attribute.DontDelete, cc);
        // make grannymail bug work

        // auto newCC = CallContext(cc, actobj, this, fd);
        fd.instantiate(cc, Property.Attribute.DontDelete |
                       Property.Attribute.DontConfig);

        auto dfs = new DefinedFunctionScope(scopex, actobj, this, fd, othis);
        cc.push(dfs);

        Value[] p1;
        Value* v;
        if(fd.nlocals < 128)
            v = cast(Value*)alloca(fd.nlocals * Value.sizeof);
        if(v)
            locals = v[0 .. fd.nlocals];
        else
        {
            p1 = new Value[fd.nlocals];
            locals = p1;
        }

        result = IR.call(cc, othis, fd.code, ret, locals.ptr);
        if (result !is null)
        {
            result.addTrace(fd.name !is null ?
                            "function " ~ fd.name.toString
                            : "anonymous");
        }

        cc.pop(dfs);

        p1.destroy; p1 = null;

        // Remove the arguments object
        //Value* v;
        //v=Get(TEXT_arguments);
        vtmp.putVundefined;
        Set(Key.arguments, vtmp, Property.Attribute.None, cc);

        return result;
    }

    override DError* Construct(CallContext cc, out Value ret,
                               Value[] arglist)
    {
        import dmdscript.primitive : Key;

        // ECMA 3 13.2.2
        Dobject othis;
        Dobject proto;
        Value* v;
        DError* result;

        v = Get(Key.prototype, cc);
        if(v.isPrimitive())
            proto = cc.dglobal.rootPrototype;
        else
            proto = v.toObject(cc);
        othis = new Dobject(proto);
        result = Call(cc, othis, ret, arglist);
        if(!result)
        {
            if(ret.isPrimitive())
                ret.put(othis);
        }
        return result;
    }

    override string toString()
    {
        import std.array : Appender;
        Appender!string buf;

        fd.toBuffer(b=>buf.put(b));
        return buf.data;
    }
}



