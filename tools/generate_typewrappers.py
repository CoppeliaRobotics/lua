# usage:
#     LUA_PATH="path/to/lua/?.lua" PYTHONPATH="path/to/python" python3 generate_typewrappers.py

if __name__ == '__main__':
    import sys
    from calltip import FuncDef
    from pprint import PrettyPrinter
    import subprocess
    import re
    import os

    lua_code = "function registerCodeEditorInfos(m, x) print(x) end; require 'sim-2-ce'"
    proc = subprocess.Popen(["lua", "-e", lua_code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    for line in proc.stdout:
        calltip = line.strip()
        if not calltip: continue
        if re.match(r'^\w+\.\w+$', calltip): continue
        pp = PrettyPrinter(indent=4)
        try:
            f = FuncDef.from_calltip(calltip)
            #pp.pprint(f)
            print(f"""{f.func_name} = wrap({f.func_name}, function(origFunc)
    return function(...)
        local args = {{...}}""")
            for arg in f.in_args:
                if arg.type == 'vector3':
                    print(f"""        -- TODO: convert arg {arg.name}""")
            print(f"""        local ret = origFunc(table.unpack(args))""")
            for ret in f.out_args:
                if arg.type == 'vector3':
                    print(f"""        -- TODO: convert ret {arg.name}""")
            print(f"""        return table.unpack(ret)
    end
end)

""")
        except Exception as e:
            print(f'--[[\n\nERROR: cannot parse calltip\n\n    {calltip}\n\n    {e!s}\n\n]]--\n')

    stderr_output = proc.stderr.read().strip()
    if stderr_output:
        print("Lua stderr:\n", stderr_output, file=sys.stderr)
