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
    import dmdscript.primitive : string_t, Identifier, PropertyKey;
    import dmdscript.callcontext : CallContext;
    import dmdscript.value : Value, DError;
    import dmdscript.property : Property;

    Dobject actobj;             // activation object
    Identifier[] parameters;

    this(Dobject caller, Dobject callee, Dobject actobj,
         Identifier[] parameters, Value[] arglist)

    {
        import dmdscript.primitive : Key;

        super(Dobject.getPrototype());

        this.actobj = actobj;
        this.parameters = parameters;

        CallContext cc;
        if(caller)
            Set(Key.caller, caller, Property.Attribute.DontEnum, cc);
        else
            Set(Key.caller, Value.Type.Null, Property.Attribute.DontEnum, cc);

        Set(Key.callee, callee, Property.Attribute.DontEnum, cc);
        Set(Key.length, arglist.length, Property.Attribute.DontEnum, cc);

        for(uint a = 0; a < arglist.length; a++)
        {
            Set(a, arglist[a], Property.Attribute.DontEnum, cc);
        }
    }

    override protected
    Value* GetImpl(in ref PropertyKey PropertyName, ref CallContext cc)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (StringToIndex(PropertyName.toString, index)
                && index < parameters.length)
            ? actobj.GetImpl(index, cc)
            : super.GetImpl(PropertyName, cc);
    }

    override Value* GetImpl(in uint index, ref CallContext cc)
    {
        return (index < parameters.length)
            ? actobj.GetImpl(index, cc)
            : super.GetImpl(index, cc);
    }

    override
    DError* SetImpl(in ref PropertyKey PropertyName, ref Value value,
                    in Property.Attribute attributes, ref CallContext cc)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        if(StringToIndex(PropertyName.toString, index)
           && index < parameters.length)
            return actobj.SetImpl(PropertyName, value, attributes, cc);
        else
            return Dobject.SetImpl(PropertyName, value, attributes, cc);
    }

    override
    DError* SetImpl(in uint index, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        if(index < parameters.length)
            return actobj.SetImpl(index, value, attributes, cc);
        else
            return Dobject.SetImpl(index, value, attributes, cc);
    }

    override int CanPut(in string_t PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.CanPut(PropertyName)
               : Dobject.CanPut(PropertyName);
    }

    override bool HasProperty(in ref PropertyKey PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (PropertyName.isArrayIndex(index) && index < parameters.length)
               ? actobj.HasProperty(PropertyName)
               : Dobject.HasProperty(PropertyName);
    }

    override bool Delete(in ref PropertyKey PropertyName)
    {
        import dmdscript.primitive : StringToIndex;

        uint index;

        return (StringToIndex(PropertyName.toString, index)
                && index < parameters.length)
               ? actobj.Delete(PropertyName)
               : Dobject.Delete(PropertyName);
    }
}

