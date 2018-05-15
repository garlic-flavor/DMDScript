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


module dmdscript.darguments;

import dmdscript.dobject : Dobject;

// The purpose of Darguments is to implement "value sharing"
// per ECMA 10.1.8 between the activation object and the
// arguments object.
// We implement it by forwarding the property calls from the
// arguments object to the activation object.

class Darguments : Dobject
{
    import dmdscript.primitive : Identifier, PropertyKey;
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value, DError;
    import dmdscript.property : Property;

    Dobject actobj;             // activation object
    Identifier[] parameters;

    this(Dobject prototype, Dobject caller, Dobject callee,
         Dobject actobj, Identifier[] parameters, Value[] arglist)

    {
        import dmdscript.primitive : Key;

        super(prototype);

        this.actobj = actobj;
        this.parameters = parameters;

        CallContext cc;
        Value v;
        if(caller)
        {
            v.put(caller);
            Set(Key.caller, v, Property.Attribute.DontEnum, cc);
        }
        else
        {
            v.put(Value.Type.Null);
            Set(Key.caller, v, Property.Attribute.DontEnum, cc);
        }

        v.put(callee);
        Set(Key.callee, v, Property.Attribute.DontEnum, cc);
        v.put(arglist.length);
        Set(Key.length, v, Property.Attribute.DontEnum, cc);

        for(uint a = 0; a < arglist.length; a++)
        {
            v.put(arglist[a]);
            Set(PropertyKey(a), v, Property.Attribute.DontEnum, cc);
        }
    }

    override protected
    Value* Get(in PropertyKey PropertyName, CallContext cc)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;
        return (PropertyName.isArrayIndex(index) && index < parameters.length)
            ? actobj.Get(PropertyKey(index), cc)
            : super.Get(PropertyName, cc);
    }

    override
    DError* Set(in PropertyKey PropertyName, ref Value value,
                in Property.Attribute attributes, CallContext cc)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        if(PropertyName.isArrayIndex(index) && index < parameters.length)
            return actobj.Set(PropertyKey(index), value, attributes, cc);
        else
            return Dobject.Set(PropertyName, value, attributes, cc);
    }

    override int CanPut(in string PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.CanPut(PropertyKey(index))
            : Dobject.CanPut(PropertyName);
    }

    override bool HasProperty(in PropertyKey PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (PropertyName.isArrayIndex(index) && index < parameters.length)
            ? actobj.HasProperty(PropertyKey(index))
            : Dobject.HasProperty(PropertyName);
    }

    override bool Delete(in PropertyKey PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (PropertyName.isArrayIndex(index) && index < parameters.length)
            ? actobj.Delete(PropertyKey(index))
            : Dobject.Delete(PropertyName);
    }
}

