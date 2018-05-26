/** test262-harness-d.
Version:    ALPHA(dmd2.080.0)
Date:       2018-May-07 23:27:38
Authors:    KUMA
License:    CC0
 */
import std.stdio;

enum applicationName = "test262-harness-d";
enum _VERSION_ = "ALPHA(dmd2.080.0)";

enum copyrightMessage = q"EOS
Licensed under CC0 2018. Some rights reserved written by KUMA.
EOS";

enum helpMessage = q"EOS
This program runs test262 with dmdscript.

Usage:
>./harness.exe [init|run|check|retry|full|status] (options)

Summary of each command:
  init   -- Make database file, test262.json.
  run    -- Run tests until first failure.
  check  -- Run tests that already passed only.
  retry  -- Run tests that failed only.
  full   -- Run all tests.
  status -- Show current progress.

Show more help:
>./harness.exe [init|run|check|retry|full|status] --help
EOS";

enum helpAboutInit = q"EOS
About init command:
Initialize test262 database. And output to test262.json in cwd.

Usage:
>./harness.exe init (-j test262.json) (-r test) (-t ../test262)

Options:
  --json -j    -- Specify the file path to a database.
                  default value is 'test262.json'

  --test -t    -- Specify the path to test262.
                  default value is '../test262'

  --root -r    -- Specify the root directory name in test262.
                  default value is 'test'

  --harness    -- Specify the root directory name for harnesses in test262.
                  default value is 'harness'

  --include -i -- Specify files to include.
                  default value is ['sta.js', 'assert.js'].

  --engine -e  -- Specify the path to dmdscript.
                  default value is './dmdscript'

  --inherit    -- Inherit results from an existing test262.json
EOS";

enum helpAboutRunningOptions = q"EOS
Options:
  --json -j    -- Specify the file path to a database.
                  default value is 'test262.json'

  --pattern -p -- Specify a part of the path to target scripts.
                  This value is not a regular expression.
                  No wild card can be used.

  --ignore     -- With this switch, Scripts that marked to be ignored will run.

  --tmp        -- Specify temporary filename. default value is 'tmp.ds'

  --nostrict   -- Run with no strict mode only.

  --strict     -- Run with strict mode only.
EOS";

enum helpAboutRun = q"EOS
About run comand:
Do tests until first failure.

Usage:
>./harness.exe run (-p 'a part of path of targeted tests.') (-j test262.json)
EOS" ~ helpAboutRunningOptions;

enum helpAboutCheck = q"EOS
About check command:
Do tests that already passed only.

Usage:
>./harness.exe check
EOS" ~ helpAboutRunningOptions;

enum helpAboutRetry = q"EOS
About retry command:
Do tests that failed only.

Usage:
>./harness.exe retry
EOS" ~ helpAboutRunningOptions;

enum helpAboutFull = q"EOS
About full command:
EOS" ~ helpAboutRunningOptions;

enum helpAboutStatus = q"EOS
Show current progress.
EOS";

enum DEFAULT_ENGINE = ".\\dmdscript.exe";
enum DEFAULT_TEST262_PATH = "..\\test262";
enum DEFAULT_TEST262_ROOT = "test";
enum DEFAULT_DATABASE_FILE = "test262.json";
enum DEFAULT_HARNESS = "harness";
enum DEFAULT_INCLUDES = ["sta.js", "assert.js"];

enum MODULE_TEMPLATE = "import '%s';";
enum TMP_FILENAME = "tmp.ds";

enum RunType
{
    none = "",
    init = "init",
    untilFirstFailure = "run",
    passedOnly = "check",
    failedOnly = "retry",
    full = "full",
    status = "status",
}

struct ArgsInfo
{
    bool needsHelp;
    RunType type;
    bool newEngine = false;
    string engine = DEFAULT_ENGINE;
    string database = DEFAULT_DATABASE_FILE;
    string test262path = DEFAULT_TEST262_PATH;
    string test262root = DEFAULT_TEST262_ROOT;
    string test262harness = DEFAULT_HARNESS;
    string[] includeNames = DEFAULT_INCLUDES;
    string[] includes;
    string test262;
    string harness;
    string pattern;
    bool ignoreComplain;
    bool verbose;
    bool inherit;
    bool nocomplaint;
    string tmp = TMP_FILENAME;
    bool noStrict;
    bool onlyStrict;
}

//==============================================================================
void main(string[] args)
{
    import std.file : exists, isDir, isFile;
    import std.path : buildPath;

    auto info = args.getInfo;

    if (info.needsHelp)
    {
        showHelp(info.type);
        return;
    }

    if      (!info.test262path.exists || !info.test262path.isDir)
        throw new Exception (info.test262path ~ " is not found.");
    else if (info.verbose)
        writeln (info.test262path, " is found.");

    info.test262 = info.test262path.buildPath(info.test262root);
    if      (!info.test262.exists || !info.test262.isDir)
        throw new Exception (info.test262 ~ " is not found.");
    else if (info.verbose)
        writeln (info.test262, " is found.");

    if      (!info.engine.exists || !info.engine.isFile)
        throw new Exception (info.engine ~ " is not found.");
    else if (info.verbose)
        writeln (info.engine, " is found.");

    info.harness = info.test262path.buildPath(info.test262harness);
    if      (!info.harness.exists || !info.harness.isDir)
        throw new Exception (info.harness ~ " is not found.");
    else if (info.verbose)
        writeln (info.harness, " is found.");

    info.includes = new string[info.includeNames.length];
    for (size_t i = 0; i < info.includeNames.length; ++i)
    {
        info.includes[i] = info.harness.buildPath(info.includeNames[i]);
        if      (!info.includes[i].exists || !info.includes[i].isFile)
            throw new Exception (info.includes[i] ~ " is not found.");
        else if (info.verbose)
            writeln (info.includes[i], " is found.");
    }

    if (info.verbose)
        writeln ("ready.");

    if      (info.type == RunType.init)
        doInit(info);
    else if (info.type == RunType.status)
        showStatus(info);
    else
        runTest(info);
}

//------------------------------------------------------------------------------
ArgsInfo getInfo(string[] args)
{
    import std.array : replace;
    import std.getopt : getopt;

    ArgsInfo info;
    auto result = getopt (
        args,
        "json|j", "A path to database file.", &info.database,
        "test|t", "A path to test262.", &info.test262path,
        "root|r", "A name of root directory in test262.", &info.test262root,
        "engine|e", "An ECMAScript interpreter to test.",
        (string opt, string value)
        {
            info.newEngine = true;
            info.engine = value;
        },
        "pattern|p", "A pattern to filter tests.", &info.pattern,
        "harness", "A root directory of harnesses.", &info.test262harness,
        "include|i", "File names to include.", &info.includeNames,
        "ignore", "Ignore the ignore mark.", &info.ignoreComplain,
        "verbose|v", "Make harness.d verbose.", &info.verbose,
        "inherit", "Inherit results from an existing database.", &info.inherit,
        "nocomplaint", "Run without any compiants", &info.nocomplaint,
        "tmp", "Temporary filename.", &info.tmp,
        "nostrict", "Run with no strict mode only.", &info.noStrict,
        "strict", "Run with strict mode only.", &info.onlyStrict,
        );

    if (0 < info.pattern.length)
        info.pattern = info.pattern.replace("/", "\\");

    info.needsHelp = result.helpWanted;

    for (size_t i = 1; i < args.length; ++i)
    {
        switch (args[i])
        {
        case RunType.init:
            info.type = RunType.init;
            break;
        case RunType.untilFirstFailure:
            info.type = RunType.untilFirstFailure;
            break;
        case RunType.passedOnly:
            info.type = RunType.passedOnly;
            break;
        case RunType.failedOnly:
            info.type = RunType.failedOnly;
            break;
        case RunType.full:
            info.type = RunType.full;
            break;
        case RunType.status:
            info.type = RunType.status;
            break;
        default:
            info.needsHelp = true;
        }
    }

    if (info.type == RunType.none)
        info.needsHelp = true;

    if (info.verbose)
        writeln("getopt succeeded.");

    return info;
}

//==============================================================================
void showHelp(RunType about)
{
    switch (about)
    {
    case RunType.init:
        helpAboutInit.writeln;
        break;
    case RunType.untilFirstFailure:
        helpAboutRun.writeln;
        break;
    case RunType.passedOnly:
        helpAboutCheck.writeln;
        break;
    case RunType.failedOnly:
        helpAboutRetry.writeln;
        break;
    case RunType.full:
        helpAboutFull.writeln;
        break;
    case RunType.status:
        helpAboutStatus.writeln;
        break;
    default:
        applicationName.writeln(" v", _VERSION_);
        copyrightMessage.writeln;
        helpMessage.writeln;
    }
}

//==============================================================================
void doInit(in ref ArgsInfo info)
{
    import std.array : array;
    import std.algorithm : filter, endsWith, map, sort, fold, startsWith;
    import std.conv : to;
    import std.file : dirEntries, SpanMode, DirEntry, write, exists, isFile,
        read;
    import std.json : toJSON, JSONValue, parseJSON;

    if (info.inherit)
    {
        if      (!info.database.exists || !info.database.isFile)
            throw new Exception (info.database ~ " is not found.");
        else if (info.verbose)
            writeln (info.database, " is found.");
    }

    writeln ("Do initialization process. this may take while...");

    JSONValue data;
    if (info.inherit)
    {
        if (info.verbose)
            writeln ("Results will be inherited from ", info.database, ".");

        auto old = info.database.read.to!string.parseJSON.object["tests"]
            .array.map!(a=>a.MetaData).array.sort;

        data = info.test262.dirEntries(SpanMode.depth)
            .filter!(f=>f.name.endsWith(".js"))
            .map!(
                (a)
                {
                    auto md = a.name.toMetaData;
                    auto eq = old.equalRange(md.path);
                    if (!eq.empty)
                    {
                        md.result = eq.front.result;
                        if (info.verbose && md.result != MetaData.Result.none)
                            writeln ("The result of ", md.path,
                                     " is inherited as ", md.result, ".");
                        md.complaint = eq.front.complaint;
                        if (info.verbose && 0 < md.complaint.length)
                            writeln ("The complaint of ", md.path,
                                     " is inherited as \"", md.complaint,
                                     "\".");
                    }
                    else if (info.verbose)
                        writeln (md.path, " is not found in an old database.");
                    return md.toJSONValue;
                })
            .array.JSONValue;
    }
    else
    {
        data = info.test262.dirEntries(SpanMode.depth)
            .filter!(f=>f.name.endsWith(".js"))
            .map!(a=>a.name.toMetaData.toJSONValue)
            .array.JSONValue;
    }

    JSONValue[string] table;
    table["engine"] = info.engine.JSONValue;
    table["includes"] = info.includes.JSONValue;
    table["tests"] = data;
    auto cont = table.JSONValue;

    info.database.write(cont.toJSON(true));
}

//------------------------------------------------------------------------------
struct MetaData
{
    import std.json : JSONValue;

    struct NegativeInfo
    {
        enum Phase
        {
            parse,
            early,
            resolution,
            runtime,
        }
        bool yes;
        Phase phase;
        string type;
    }

    struct FlagsInfo
    {
        bool onlyStrict;
        bool noStrict;
        bool moduleCode;
        bool raw;
        bool async;
        bool generated;
    }

    struct ESID
    {
        string className;
        float section = 0;
    }

    enum Result
    {
        none,
        failed,
        passed,
    }

    string path;
    NegativeInfo negative;
    string[] includes;
    FlagsInfo flags;
    string esid;
    string es5id;
    string es6id;
    string[] features;
    Result result;
    Result resultOfStrict;
    bool ignore;
    string complaint;

    alias path this;

    JSONValue toJSONValue() const
    {
        import std.conv : to;
        JSONValue[string] v;
        v["path"] = JSONValue(path);
        if (negative.yes)
        {
            v["negative"] = JSONValue(
                [
                    "phase": JSONValue(negative.phase.to!string),
                    "type": JSONValue(negative.type),
                ]);
        }
        if (0 < includes.length)
            v["includes"] = JSONValue(includes);
        if (flags.onlyStrict)
            v["onlyStrict"] = JSONValue(true);
        if (flags.noStrict)
            v["noStrict"] = JSONValue(true);
        if (flags.moduleCode)
            v["module"] = JSONValue(true);
        if (flags.raw)
            v["raw"] = JSONValue(true);
        if (flags.async)
            v["async"] = JSONValue(true);
        if (flags.generated)
            v["generated"] = JSONValue(true);
        if (0 < esid.length)
            v["esid"] = JSONValue(esid);
        if (0 < es5id.length)
            v["es5id"] = JSONValue(es5id);
        if (0 < es6id.length)
            v["es6id"] = JSONValue(es6id);
        if (0 < features.length)
            v["features"] = JSONValue(features);
        if (Result.none != result)
            v["result"] = JSONValue(result == Result.passed);
        if (Result.none != resultOfStrict)
            v["resultOfStrict"] = JSONValue(resultOfStrict == Result.passed);
        if (0 < complaint.length)
            v["complaint"] = complaint.JSONValue;

        return JSONValue(v);
    }

    this(in ref JSONValue jv)
    {
        import std.conv : to;
        import std.algorithm : map;
        import std.array : array;
        import std.json : JSON_TYPE;

        foreach (key, val; jv.object)
        {
            switch (key)
            {
            case "path":
                path = val.str;
                break;
            case "negative":
                auto table = val.object;
                negative.yes = true;
                foreach (k, v; table)
                {
                    switch (k)
                    {
                    case "phase":
                        negative.phase = v.str.to!(NegativeInfo.Phase);
                        break;
                    case "type":
                        negative.type = v.str;
                        break;
                    default:
                        throw new Exception (key ~ " is not expected.");
                    }
                }
                break;
            case "includes":
                includes = val.array.map!(a=>a.str).array;
                break;
            case "onlyStrict":
                flags.onlyStrict = true;
                break;
            case "noStrict":
                flags.noStrict = true;
                break;
            case "module":
                flags.moduleCode = true;
                break;
            case "raw":
                flags.raw = true;
                break;
            case "async":
                flags.async = true;
                break;
            case "generated":
                flags.generated = true;
                break;
            case "esid":
                esid = val.str;
                break;
            case "es5id":
                es5id = val.str;
                break;
            case "es6id":
                es6id = val.str;
                break;
            case "features":
                features = val.array.map!(a=>a.str).array;
                break;
            case "result":
                result = (val.type == JSON_TYPE.TRUE) ?
                    Result.passed : Result.failed;
                break;
            case "resultOfStrict":
                resultOfStrict = (val.type == JSON_TYPE.TRUE) ?
                    Result.passed : Result.failed;
                break;
            case "ignore":
                ignore = true;
                break;
            case "complaint":
                complaint = val.str;
                break;
            default:
                throw new Exception(key ~ " is not expected.");
            }
        }
    }
}

//------------------------------------------------------------------------------
MetaData toMetaData(string path)
{
    import std.conv : to;
    import std.file : exists, isFile, read;

    assert (path.exists && path.isFile);

    MetaData meta;
    meta.path = path;

    try
    {
        path.read.to!string.takeMetaSection.parseYAML.toMetaData(meta);
    }
    catch (Throwable t)
    {
        throw new Exception ("An error occured about " ~ path, t);
    }
    return meta;
}

auto takeMetaSection(string script)
{
    import std.algorithm : findSplit;
    import std.array : Appender;
    import std.typecons : tuple;

    Appender!string buf;
    for (auto result = tuple("", "", script);;)
    {
        result = result[2].findSplit("/*---");
        if (result[2].length == 0)
            break;

        result = result[2].findSplit("---*/");
        buf.put(result[0]);
        if (result[2].length == 0)
            break;
    }

    return buf.data;
}

struct YAML
{
    import std.variant : Algebraic;
    alias Value = Algebraic!(string, string[], YAML[]);

    string key;
    Value value;
}

auto parseYAML(string metaSection)
{
    import std.string : splitLines;

    size_t i;
    return metaSection.splitLines.parseYAML(-1, i);
}

YAML[] parseYAML(string[] lines, in int baseIndent, ref size_t i)
{
    import std.ascii : isWhite;
    import std.string : splitLines, strip, stripRight, stripLeft;
    import std.algorithm : until, findSplit, countUntil, joiner,
        startsWith, endsWith, splitter, map;
    import std.array : Appender, array;
    import std.range : drop;
    import std.conv : to;

    Appender!(string[]) buf;
    Appender!(YAML[]) yamls;

    for (; i < lines.length;)
    {
        if (0 == lines[i].stripRight.length)
        {
            ++i;
            continue;
        }
        auto indent = lines[i].countUntil!(a=>!a.isWhite);
        if (indent <= baseIndent)
            break;

        auto result = lines[i].until("#").findSplit(":");
        if (result[1].empty)
        {
            ++i;
            continue;
        }

        auto key = result[0].to!string.strip;
        auto value = result[2].to!string.strip;
        if      (value == ">" || value == "|")
        {
            buf.shrinkTo(0);

            for (++i; i < lines.length; ++i)
            {
                if (lines[i].strip.length == 0)
                {
                    buf.put("");
                    continue;
                }

                auto idt = lines[i].countUntil!(a=>!a.isWhite);
                if (idt <= indent)
                    break;

                if (value == ">")
                    buf.put(lines[i].strip);
                else
                    buf.put(lines[i].drop(indent));
            }
            if (value == ">")
                yamls.put(YAML(key,
                               YAML.Value(buf.data.joiner(" ").to!string)));
            else
                yamls.put(YAML(key,
                               YAML.Value(buf.data.joiner("\n").to!string)));
        }
        else if (value == "")
        {
            ++i;
            if (i < lines.length && lines[i].stripLeft.startsWith('-'))
            {
                buf.shrinkTo(0);
                for (; i < lines.length; ++i)
                {
                    auto idt = lines[i].countUntil!(a=>!a.isWhite);
                    if (idt <= indent)
                        break;
                    auto l = lines[i][idt..$];
                    if (!l.startsWith('-'))
                        break;

                    buf.put(l[1..$].strip);
                }
                yamls.put(YAML(key, YAML.Value(buf.data)));
            }
            else
                yamls.put(YAML(key, YAML.Value(parseYAML(lines, indent, i))));
        }
        else
        {
            if (value.startsWith('[') && value.endsWith(']'))
            {
                yamls.put(YAML(key, YAML.Value(value[1..$-1]
                                               .splitter(',')
                                               .map!(a=>a.strip).array)));
            }
            else
                yamls.put(YAML(key, YAML.Value(value)));
            ++i;
        }
    }

    return yamls.data;
}


void toMetaData(YAML[] yamls, ref MetaData meta)
{
    foreach (yaml; yamls)
    {
        switch (yaml.key)
        {
        case "esid":
            meta.esid = yaml.value.get!string;
            break;
        case "es5id":
            meta.es5id = yaml.value.get!string;
            break;
        case "es6id":
            meta.es6id = yaml.value.get!string;
            break;
        case "negative":
            meta.negative.yes = true;
            foreach (sub; yaml.value.get!(YAML[]))
            {
                switch (sub.key)
                {
                case "phase":
                    alias P = MetaData.NegativeInfo.Phase;
                    switch (sub.value.get!string)
                    {
                    case "parse":
                        meta.negative.phase = P.parse;
                        break;
                    case "early":
                        meta.negative.phase = P.early;
                        break;
                    case "resolution":
                        meta.negative.phase = P.resolution;
                        break;
                    case "runtime":
                        meta.negative.phase = P.runtime;
                        break;
                    default:
                        throw new Exception (sub.value.get!string ~
                                             " is Unknown phase.");
                    }
                    break;
                case "type":
                    meta.negative.type = sub.value.get!string;
                    break;
                default:
                }
            }
            break;
        case "flags":
            foreach (one; yaml.value.get!(string[]))
            {
                switch (one)
                {
                case "onlyStrict":
                    meta.flags.onlyStrict = true;
                    break;
                case "noStrict":
                    meta.flags.noStrict = true;
                    break;
                case "module":
                    meta.flags.moduleCode = true;
                    break;
                case "raw":
                    meta.flags.raw = true;
                    break;
                case "async":
                    meta.flags.async = true;
                    break;
                case "generated":
                    meta.flags.generated = true;
                    break;
                case "CanBlockIsFalse": /// what's this?
                    break;
                default:
                    throw new Exception (one ~ " is an unknown flag.");
                }
            }
            break;
        case "features":
            meta.features = yaml.value.get!(string[]);
            break;
        default:
        }
    }
}


//==============================================================================
void runTest(in ref ArgsInfo info)
{
    import std.stdio: stdout, stdin;
    import std.file: exists, isFile, read, write;
    import std.conv: to;
    import std.json: JSONValue, parseJSON, toJSON;
    import std.algorithm: filter, map, find;
    import std.range: empty;
    import std.process: pipeProcess, Redirect, wait;
    import std.string: strip;
    import std.array: array, Appender, join, replace;
    import std.format: format;
    import std.datetime: Clock;

    if (!info.database.exists)
        doInit(info);

    if      (!info.database.exists || !info.database.isFile)
        throw new Exception (info.database ~ " is not found.");
    else if (info.verbose)
        writeln (info.database, " is found.");

    string engine = info.engine;
    auto table = info.database.read.to!string.parseJSON.object;
    if (!info.newEngine)
    {
        engine = table["engine"].str;
        if      (!engine.exists || !engine.isFile)
            throw new Exception (engine ~ " is not found.");
        else if (info.verbose)
            writeln (info.engine, " is found.");
    }

    auto baseCommand = [engine];
    foreach (one; info.includes)
        baseCommand ~= "-i" ~ one;

    size_t ranCount;
    size_t passedCount;
    size_t failedCount;
    size_t ignoredCount;
    bool aborting = false;
    string inputs;
    Appender!(string[]) outputs;
    Appender!(string[]) errouts;

    if (info.verbose)
        writeln ("protocol start...");

    auto startTime = Clock.currTime;
    table["tests"] = table["tests"].array.map!( // リストを巡回する。
        (jv){
            if (aborting) // このグループで失敗が出たからやめたい。
                return jv;

            // コマンドラインから与えたパターンでフィルタする。
            if (0 < info.pattern.length &&
                jv["path"].str.find(info.pattern).empty)
                return jv;

            //
            auto meta = jv.MetaData;

            // strictモードが合わない
            if ((info.noStrict && meta.flags.onlyStrict) ||
                (info.onlyStrict && meta.flags.noStrict))
            {
                return jv;
            }

            // スクリプトを実行する。
            bool editedJv = false;
            auto strictMode = info.onlyStrict || meta.flags.onlyStrict;
            int exitcode = 0;
        execute:

            // 以前に失敗してたやつだけ
            if      (info.type == RunType.failedOnly)
            {
                if (strictMode)
                {
                    if (meta.resultOfStrict != MetaData.Result.failed)
                        goto next;
                }
                else
                {
                    if (meta.result != MetaData.Result.failed)
                        goto next;
                }
            }
            // 以前に成功してるやつだけに絞る。
            else if (info.type == RunType.passedOnly)
            {
                if (strictMode)
                {
                    if (meta.resultOfStrict != MetaData.Result.passed)
                        goto next;
                }
                else
                {
                    if (meta.result != MetaData.Result.passed)
                        goto next;
                }
            }
            else if (info.type != RunType.full)
            {
                // 以前に成功したやつはもういい。
                if (strictMode)
                {
                    if (meta.resultOfStrict == MetaData.Result.passed)
                    {
                        ++passedCount;
                        goto next;
                    }
                }
                else
                {
                    if (meta.result == MetaData.Result.passed)
                    {
                        ++passedCount;
                        goto next;
                    }

                }

                // 無視するとマークされてるから飛ばす。
                if (strictMode)
                {
                    if (meta.resultOfStrict == MetaData.Result.failed &&
                        0 < meta.complaint.length && !info.ignoreComplain)
                    {
                        ++ignoredCount;
                        goto next;
                    }
                }
                else
                {
                    if (meta.result == MetaData.Result.failed &&
                        0 < meta.complaint.length && !info.ignoreComplain)
                    {
                        ++ignoredCount;
                        goto next;
                    }
                }
            }

            ++ranCount;
            editedJv = true;

            {
                // モジュールとして実行すべきファイル
                string path = meta.path;
                if (meta.flags.moduleCode)
                {
                    info.tmp.write (MODULE_TEMPLATE.format (
                                        path.replace("\\", "\\\\")));
                    path = info.tmp;
                }

                // 実行
                string[] command;
                if (strictMode)
                    command = baseCommand ~ "-s" ~ path;
                else
                    command = baseCommand ~ path;
                if (info.verbose)
                    writeln (command.join(" "));
                auto pipes = pipeProcess(command,
                                         Redirect.stdout | Redirect.stderr);

                // 出力を収集
                errouts.shrinkTo(0);
                foreach (one; pipes.stderr.byLine)
                    errouts.put(one.idup);

                outputs.shrinkTo(0);
                foreach (one; pipes.stdout.byLine)
                    outputs.put(one.idup);

                exitcode = wait(pipes.pid);
            }

            if (info.verbose)
                writeln ("exit code: ", exitcode);

            if (exitcode == 0) // スクリプトが正常終了した。
            {
                if (meta.negative.yes) // 異常終了すべきだった。
                {
                    writeln(meta.path, " should failure with ",
                            meta.negative.type, ", but success on ",
                            strictMode ? "" : "non ", "strict mode.");
                    goto failed;
                }
                writeln (meta.path, " passed on ",
                         strictMode ? "" : "non ", "strict mode.");
                goto succeeded;
            }
            else // スクリプトが異常終了した。
            {
                if (meta.negative.yes) // 異常終了すべきだった。
                {
                    // 期待されたエラーが出ているか
                    // 1行目に期待される文字列が出てるかを見てるだけ。
                    if (0 < errouts.data.length &&
                        !errouts.data[0].find(meta.negative.type).empty)
                    {
                        writeln(meta.path, " failed as expected on ",
                                strictMode ? "" : "non ", "strict mode.");
                        goto succeeded;
                    }

                    // 出てなかった。
                    writeln(meta.path, " should failure with ",
                            meta.negative.type, ", on ",
                            strictMode ? "" : "non ", "strict mode.");
                    goto failed;
                }
                writeln(meta.path, " failed on ",
                        strictMode ? "" : "non ", "strict mode.");
                goto failed;
            }

            void printOutputs()
            {
                // 標準出力の表示
                stdout.flush;
                writeln;
                writeln("-- stdout ----------------------------------------");

                foreach (line; outputs.data)
                    line.writeln;

                writeln;
                writeln("-- stderr ----------------------------------------");

                foreach (line; errouts.data)
                    line.writeln;
            }

        succeeded:
            if (strictMode)
                meta.resultOfStrict = MetaData.Result.passed;
            else
                meta.result = MetaData.Result.passed;

            if (info.verbose)
                printOutputs;

            ++passedCount;

            goto next;

        failed:
            if (strictMode)
                meta.resultOfStrict = MetaData.Result.failed;
            else
                meta.result = MetaData.Result.failed;

            printOutputs;

            writeln;
            writeln (strictMode ? "STRICT MODE" : "NON STRICT MODE");
            writeln("-- Source ----------------------------------------");


            // スクリプトのメタ情報の表示
            // foreach (one; meta.path.read.to!string
            //          .takeMetaSection.parseYAML)
            // {
            //     writeln("[", one.key, "]:");
            //     writeln(one.value);
            // }
            import std.string: splitLines;
            import std.format: format;
            foreach (i, one; meta.path.read.to!string.splitLines)
                writefln("%4d:%s", i+1, one);

            if (0 < meta.complaint.length)
            {
                writeln;
                writeln("[complaint]:");
                writeln(meta.complaint);
            }

            writeln;
            writeln("--------------------------------------------------");

            // 言い訳するか
            if (info.nocomplaint)
            {
                ++failedCount;
            }
            else
            {
                stdout.write("complain to this?>");
                inputs = stdin.readln.to!string.strip;

                if      (0 < inputs.length)
                {
                    ++ignoredCount;
                    meta.complaint = inputs;
                }
                else if (0 < meta.complaint.length)
                    ++ignoredCount;
                else
                    ++failedCount;
            }

            // 続行するかどうか。
            if (meta.complaint.length == 0 && info.type != RunType.full &&
                info.type != RunType.failedOnly)
                aborting = true;

        next:
            if (!strictMode && !info.noStrict && !meta.flags.noStrict &&
                !aborting)
            {
                strictMode = true;
                goto execute;
            }

            return editedJv ? meta.toJSONValue : jv;

        }).array.JSONValue;

    auto cont = table.JSONValue;

    info.database.write(cont.toJSON(true));

    auto endTime = Clock.currTime;
    int m, s;
    (endTime - startTime).split!("minutes", "seconds")(m, s);

    writeln ("Ran ", ranCount, " tests, took ",
             format("%02d:%02d", m, s), ".");
    writeln("Passed ", passedCount);
    writeln("Failed ", failedCount);
    writeln("Ignored ", ignoredCount);
}

//==============================================================================
void showStatus(in ref ArgsInfo info)
{
    import std.file: exists, isFile, read;
    import std.conv: to;
    import std.array: Appender;
    import std.json: parseJSON, JSON_TYPE;
    import std.path: dirName;

    if (!info.database.exists || !info.database.isFile)
        throw new Exception (info.database ~ " is not found.");

    auto table = info.database.read.to!string.parseJSON.object;

    writeln("Target engine: ", table["engine"].str);

    size_t allCount, passedCount, failedCount, ignoredCount,
        passedCountStrict, failedCountStrict, ignoredCountStrict;
    Appender!(string[]) buf;

    enum DirStatus
    {
        None,
        Progressing,
        Failed,
        Passed,
    }
    alias S = DirStatus;
    S[string] passedDir;

    foreach (one; table["tests"].array)
    {
        auto t = one.object;
        auto path = t["path"].str;
        auto dir = path.dirName;

        allCount += ("onlyStrict" in t || "noStrict" in t) ? 1 : 2;

        if ("onlyStrict" !in t)
        {
            if (auto p = "result" in t)
            {
                if      ((*p).type == JSON_TYPE.TRUE)
                {
                    ++passedCount;
                    passedDir[dir] = passedDir.get(dir, S.Passed);
                }
                else if (auto p2 = "complaint" in t)
                {
                    ++ignoredCount;
                    buf.put("* " ~ path ~ " on non strict mode.");
                    buf.put("  " ~ (*p2).str);
                    passedDir[dir] = passedDir.get(dir, S.Passed);
                }
                else
                {
                    ++failedCount;
                    buf.put("* " ~ path ~ " on non strict mode.");
                    buf.put("  failed.");
                    passedDir[dir] = S.Failed;
                }
            }
            else if (S.None != passedDir.get(dir, S.None))
                passedDir[dir] = S.Progressing;
        }
        if ("noStrict" !in t)
        {
            if (auto p = "resultOfStrict" in t)
            {
                if      ((*p).type == JSON_TYPE.TRUE)
                {
                    ++passedCountStrict;
                    passedDir[dir] = passedDir.get(dir, S.Passed);
                }
                else if (auto p2 = "complaint" in t)
                {
                    ++ignoredCountStrict;
                    buf.put("* " ~ path ~ " on strict mode.");
                    buf.put("  " ~ (*p2).str);
                    passedDir[dir] = passedDir.get(dir, S.Passed);
                }
                else
                {
                    ++failedCountStrict;
                    buf.put("* " ~ path ~ " on strict mode.");
                    buf.put("  failed.");
                    passedDir[dir] = S.Failed;
                }
            }
            else if (S.None != passedDir.get(dir, S.None))
                passedDir[dir] = S.Progressing;
        }
    }
    writeln ("In ", allCount, " tests, ");
    writeln (passedCount, " passed on non strict mode,");
    writeln (failedCount, " failed on non strict mode,");
    writeln (ignoredCount, " ignored on non strict mode.");
    writeln (passedCountStrict, " passed on strict mode");
    writeln (failedCountStrict, " failed on strict mode,");
    writeln (ignoredCountStrict, " ignored on strict mode.");
    writeln("Current progress is ",
            (passedCount + ignoredCount +
             passedCountStrict + ignoredCountStrict) * 100 / allCount, "%(",
            passedCount + ignoredCount + passedCountStrict + ignoredCountStrict,
            "/", allCount, ")");
    writeln;

    writeln ("Passed directories:");
    foreach (key, val; passedDir)
        if (val == S.Passed) writeln(key);
    writeln;

    writeln ("Failed directories:");
    foreach (key, val; passedDir)
        if (val == S.Failed) writeln(key);
    writeln;

    writeln ("Progressing directories:");
    foreach (key, val; passedDir)
        if (val == S.Progressing) writeln(key);
    writeln;

    writeln("Complaints:");
    foreach (one; buf.data)
        one.writeln;
}
