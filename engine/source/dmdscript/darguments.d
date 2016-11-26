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

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.identifier;
import dmdscript.value;
import dmdscript.text;
import dmdscript.property;

// The purpose of Darguments is to implement "value sharing"
// per ECMA 10.1.8 between the activation object and the
// arguments object.
// We implement it by forwarding the property calls from the
// arguments object to the activation object.

class Darguments : Dobject
{
    Dobject actobj;             // activation object
    Identifier*[] parameters;

    override int isDarguments() const
    {
        return true;
    }

    this(Dobject caller, Dobject callee, Dobject actobj,
         Identifier*[] parameters, Value[] arglist)

    {
        super(Dobject.getPrototype());

        this.actobj = actobj;
        this.parameters = parameters;

        CallContext cc;
        if(caller)
            Put(Text.caller, caller, Property.Attribute.DontEnum, cc);
        else
            Put(Text.caller, vnull, Property.Attribute.DontEnum, cc);

        Put(Text.callee, callee, Property.Attribute.DontEnum, cc);
        Put(Text.length, arglist.length, Property.Attribute.DontEnum, cc);

        for(uint a = 0; a < arglist.length; a++)
        {
            Put(a, arglist[a], Property.Attribute.DontEnum, cc);
        }
    }

    override Value* Get(in d_string PropertyName, ref CallContext cc)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.Get(index, cc)
            : Dobject.Get(PropertyName, cc);
    }

    override Value* Get(in d_uint32 index, ref CallContext cc)
    {
        return (index < parameters.length)
            ? actobj.Get(index, cc)
            : Dobject.Get(index, cc);
    }

    override Value* Get(in d_uint32 index, ref Value vindex, ref CallContext cc)
    {
        return (index < parameters.length)
            ? actobj.Get(index, vindex, cc)
            : Dobject.Get(index, vindex, cc);
    }

    override
    DError* Put(in d_string PropertyName, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, value, attributes, cc);
        else
            return Dobject.Put(PropertyName, value, attributes, cc);
    }

    override
    DError* Put(ref Identifier key, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        d_uint32 index;

        if(StringToIndex(key.value.text, index) && index < parameters.length)
            return actobj.Put(key, value, attributes, cc);
        else
            return Dobject.Put(key, value, attributes, cc);
    }

    override
    DError* Put(in d_string PropertyName, Dobject o,
                in Property.Attribute attributes, ref CallContext cc)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, o, attributes, cc);
        else
            return Dobject.Put(PropertyName, o, attributes, cc);
    }

    override
    DError* Put(in d_string PropertyName, in d_number n,
                in Property.Attribute attributes, ref CallContext cc)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, n, attributes, cc);
        else
            return Dobject.Put(PropertyName, n, attributes, cc);
    }

    override
    DError* Put(in d_uint32 index, ref Value vindex, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        if(index < parameters.length)
            return actobj.Put(index, vindex, value, attributes, cc);
        else
            return Dobject.Put(index, vindex, value, attributes, cc);
    }

    override
    DError* Put(in d_uint32 index, ref Value value,
                in Property.Attribute attributes, ref CallContext cc)
    {
        if(index < parameters.length)
            return actobj.Put(index, value, attributes, cc);
        else
            return Dobject.Put(index, value, attributes, cc);
    }

    override int CanPut(in d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.CanPut(PropertyName)
               : Dobject.CanPut(PropertyName);
    }

    override int HasProperty(in d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.HasProperty(PropertyName)
               : Dobject.HasProperty(PropertyName);
    }

    override int Delete(in d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.Delete(PropertyName)
               : Dobject.Delete(PropertyName);
    }
}

