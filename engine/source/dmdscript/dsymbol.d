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

module dmdscript.dsymbol;

import dmdscript.dobject: Dobject;
import dmdscript.dfunction: Dconstructor;
import dmdscript.dnative: DnativeFunction, DFD = DnativeFunctionDescriptor;
import dmdscript.value: DError, Value;
import dmdscript.drealm: Drealm;
import dmdscript.callcontext: CallContext;


//==============================================================================
///
class Dsymbol : Dobject
{
    import dmdscript.primitive: Key, PropertyKey;
    import dmdscript.RandAA: RandAA;

private:
    this(Dobject prototype, string desc)
    {
        super(prototype, Key.Symbol);
        value.putVsymbol(get(PropertyKey(desc)));
    }

    this(Dobject prototype, ref Value desc)
    {
        assert (desc.type == Value.Type.Symbol);
        super(prototype, Key.Symbol);
        value = desc;
    }

static public:

    static void init()
    {
        if (_table is null)
            _table = new Table;
    }

    PropertyKey get(PropertyKey key)
    {
        assert (!key.isSymbol);
        assert (_table !is null);
        auto symbol = key in _table;
        if (symbol !is null)
            return *symbol;
        auto ns = PropertyKey.symbol(key);
        _table.insertAlt(key, ns, key.hash);
        return ns;
    }

static private:
    alias Table = RandAA!(PropertyKey, PropertyKey, false);
    Table _table;
}


//
class DsymbolConstructor : Dconstructor
{
    import dmdscript.dfunction : Dfunction;
    import dmdscript.primitive : Key;

    this(Dobject superClassPrototype, Dobject functionPrototype)
    {
        import dmdscript.primitive: PropertyKey;
        import dmdscript.property: Property;
        alias PA = Property.Attribute;
        enum ATTR = PA.ReadOnly | PA.DontDelete | PA.DontConfig;

        super(new Dobject(superClassPrototype), functionPrototype,
              Key.Symbol, 1);

        install(functionPrototype);

        // propagete well known symbols.
        Value v;
        PropertyKey pk;
        foreach (one; [Key.toPrimitive])
        {
            pk = Dsymbol.get(one);
            v.putVsymbol(pk);
            DefineOwnProperty(one, v, ATTR );
        }


    }

    Dsymbol opCall(ARGS...)(ARGS args)
    {
        return new Dsymbol(classPrototype, args);
    }

    override DError* Construct(CallContext* cc, out Value ret,
                               Value[] arglist)
    {
        assert (0);
    }

    override DError* Call(CallContext* cc, Dobject othis, out Value ret,
                          Value[] arglist)
    {
        import dmdscript.primitive: PropertyKey;
        ret.putVsymbol(0 < arglist.length ?
                       Dsymbol.get(PropertyKey(arglist[0].toString(cc))) :
                       Dsymbol.get(Key.undefined));
        return null;
    }
}

//==============================================================================
private:

//
@DFD(1, DFD.Type.Static, "for")
DError* _for(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    assert(0);
}

@DFD(0)
DError* valueOf(
    DnativeFunction pthis, CallContext* cc, Dobject othis, out Value ret,
    Value[] arglist)
{
    import dmdscript.primitive: Key;
    import dmdscript.errmsgs: FunctionWantsStringError;

    if (auto ds = cast(Dsymbol)othis)
    {
        ret = ds.value;
    }
    else
    {
        ret.putVundefined;
        return FunctionWantsStringError(cc, Key.valueOf, othis.classname);
    }
    return null;
}
