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

class DdeclaredFunction : Dconstructor
{
    import dmdscript.primitive : string_t, StringKey;
    import dmdscript.callcontext : CallContext;
    import dmdscript.dobject : Dobject;
    import dmdscript.value : DError, Value;
    import dmdscript.functiondefinition : FunctionDefinition;

    FunctionDefinition fd;

    this(FunctionDefinition fd)
    {
        import dmdscript.primitive : Key;
        import dmdscript.property : Property;

        super(cast(uint)fd.parameters.length, Dfunction.getPrototype);
        assert(Dfunction.getPrototype);
        assert(GetPrototypeOf);
        this.fd = fd;

        // ECMA 3 13.2
        auto o = new Dobject(Dobject.getPrototype);        // step 9
        CallContext cc;
        Set(Key.prototype, o, Property.Attribute.DontEnum, cc);  // step 11
        // step 10
        o.Set(Key.constructor, this, Property.Attribute.DontEnum, cc);

    }

    override DError* Call(ref CallContext cc, Dobject othis, out Value ret,
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
        import dmdscript.property : Property, PropertyKey;
        import dmdscript.ir : Opcode;
        import dmdscript.opcodes : IR;
        import dmdscript.value : vundefined;
        import dmdscript.callcontext : VariableScope;

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
        actobj = new Dobject(null);

        Value vtmp;//should not be referenced by the end of func
        if(fd.name)
        {
           vtmp.put(this);
           actobj.Set(*fd.name, vtmp, Property.Attribute.DontDelete, cc);
        }
        // Instantiate the parameters
        {
            uint a = 0;
            foreach(StringKey* p; fd.parameters)
            {
                Value* v = (a < arglist.length) ? &arglist[a++] : &undefined;
                actobj.Set(p.toString, *v, Property.Attribute.DontDelete, cc);
            }
        }

        // Generate the Arguments Object
        // ECMA v3 10.1.8
        args = new Darguments(cc.caller, this, actobj, fd.parameters, arglist);

        actobj.Set(Key.arguments, args, Property.Attribute.DontDelete, cc);

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
        Set(Key.arguments, args, Property.Attribute.DontDelete, cc);
        // make grannymail bug work

        // auto newCC = CallContext(cc, actobj, this, fd);
        auto ccs = VariableScope(actobj, this, fd, othis);
        cc.pushFunctionScope(ccs);

        fd.instantiate(cc, Property.Attribute.DontDelete);

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
            result.addTrace(fd.sourcename, fd.name !is null ?
                            "function " ~ fd.name.toString : "anonymous",
                            fd.srctext);
        }

        cc.popVariableScope(ccs);

        delete p1;

        // Remove the arguments object
        //Value* v;
        //v=Get(TEXT_arguments);
        Set(Key.arguments, vundefined, Property.Attribute.None, cc);

        return result;
    }

    override DError* Construct(ref CallContext cc, out Value ret,
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
            proto = Dobject.getPrototype;
        else
            proto = v.toObject();
        othis = new Dobject(proto);
        result = Call(cc, othis, ret, arglist);
        if(!result)
        {
            if(ret.isPrimitive())
                ret.put(othis);
        }
        return result;
    }

    override string_t toString()
    {
        import std.array : Appender;
        Appender!string_t buf;

        fd.toBuffer(b=>buf.put(b));
        return buf.data;
    }
}



