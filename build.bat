rem Simple build script that just calls dub for each sub-package
set BUILD=debug
dub build --arch=x86 --build=%BUILD% --force dmdscript:engine
dub build --arch=x86 --build=%BUILD% --force dmdscript:ds
rem dub build --arch=x86 --build=%BUILD% --force dmdscript:ds-ext
copy ds\dmdscript_ds.exe dmdscript.exe
rem copy ds-ext\dmdscript_ds-ext.exe dmdscript-ext.exe
