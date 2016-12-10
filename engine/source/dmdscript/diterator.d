module dmdscript.diterator;

import dmdscript.dobject : Dobject;
import dmdscript.dfunction : Dconstructor;

//------------------------------------------------------------------------------
class DiteratorConstructor : Dconstructor
{
    import dmdscript.primitive : Text;
    import dmdscript.script : CallContext;
    import dmdscript.value : DError, Value;
    import dmdscript.dfunction : Dfunction;

    this()
    {
        super(Text.Iterator, 1, Dfunction.getPrototype);
    }

    override DError* Construct(ref CallContext cc, out Value ret,
                               Value[] arglist)
    {
        return null;
    }
}

//------------------------------------------------------------------------------
class DiteratorPrototype : Diterator
{
    import dmdscript.dfunction : Dfunction;

    this()
    {
        super(Dobject.getPrototype);
        auto f = Dfunction.getPrototype;

    }
}

//------------------------------------------------------------------------------
class Diterator : Dobject
{
    import dmdscript.primitive : Text;
    import dmdscript.dfunction : Dfunction;
    import dmdscript.iterator : Iterator;

    this()
    {
        this(getPrototype);
    }

    this(Dobject prototype)
    {
        super(prototype, Text.Iterator);
    }

private:
    Iterator _iterator;

public static:

    @property @safe @nogc nothrow
    Dfunction getConstructor()
    {
        return _constructor;
    }

    @property @safe @nogc nothrow
    Dobject getPrototype()
    {
        return _prototype;
    }

    void initialize()
    {
        import dmdscript.key : Key;
        import dmdscript.property : Property;

        _constructor = new DiteratorConstructor();
        _prototype = new DiteratorPrototype();

        _constructor.DefineOwnProperty(Key.prototype, _prototype,
                                       Property.Attribute.DontEnum |
                                       Property.Attribute.ReadOnly);
    }

private static:
    Dfunction _constructor;
    Dobject _prototype;
}
