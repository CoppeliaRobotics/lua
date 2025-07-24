# usage:
#     LUA_PATH="path/to/lua/?.lua" PYTHONPATH="path/to/python" python3 generate_typewrappers.py

if __name__ == '__main__':
    import sys
    from calltip import FuncDef, VarArgs
    from pprint import PrettyPrinter
    import subprocess
    import re
    import os

    if len(sys.argv) != 2:
        print('usage: {argv[0]} <output-lua-file>')

    lua_code = "function registerCodeEditorInfos(m, x) print(x) end; require 'sim-2-ce'"
    proc = subprocess.Popen(["lua", "-e", lua_code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    gen_code = 'return {extend = function(sim)\n\n'
    for line in proc.stdout:
        calltip = line.strip()
        if not calltip: continue
        if re.match(r'^\w+\.\w+$', calltip): continue
        pp = PrettyPrinter(indent=4)
        try:
            f = FuncDef.from_calltip(calltip)
            #pp.pprint(f)
            in_recipes, out_recipes = {}, {}
            for i, arg in enumerate(f.in_args):
                if isinstance(arg, VarArgs): continue
                if arg.type == 'vector3':
                    in_recipes[i] = 'Vector:tovector'
                elif arg.type == 'matrix':
                    in_recipes[i] = 'Matrix:tomatrix'
                elif arg.type == 'quaternion':
                    in_recipes[i] = 'Quaternion:toquaternion'
                elif arg.type == 'pose':
                    in_recipes[i] = 'Pose:topose'
                elif arg.type == 'color':
                    in_recipes[i] = 'Color:tocolor'
                elif arg.type == 'handle':
                    in_recipes[i] = 'sim.Object:toobject'
            for i, ret in enumerate(f.out_args):
                if isinstance(ret, VarArgs): continue
                if ret.type == 'vector3':
                    out_recipes[i] = 'Matrix.data'
                elif ret.type == 'matrix':
                    out_recipes[i] = 'Matrix.data'
                elif ret.type == 'quaternion':
                    out_recipes[i] = 'Quaternion.data'
                elif ret.type == 'pose':
                    out_recipes[i] = 'Pose.data'
                elif ret.type == 'color':
                    out_recipes[i] = 'Color.data'
                elif ret.type == 'handle':
                    out_recipes[i] = '#'
            if not in_recipes and not out_recipes: continue
            gen_code += f"""{f.func_name} = wrap({f.func_name}, function(origFunc)
    return function(...)
        local args = {{...}}
"""
            for i, recipe in in_recipes.items():
                gen_code += f"""        args[{i}] = {recipe}(args[{i}]) -- {f.in_args[i].name} [{f.in_args[i].type}]
"""
            gen_code += f"""        local ret = {origFunc(table.unpack(args))}
"""
            for i, recipe in out_recipes.items():
                gen_code += f"""        ret[{i}] = {recipe}(ret[{i}]) -- {f.out_args[i].name} [{f.out_args[i].type}]
"""
            gen_code += f"""        return table.unpack(ret)
    end
end)

"""
        except Exception as e:
            gen_code += f'--[[\n\nERROR: cannot parse calltip\n\n    {calltip}\n\n    {e!s}\n\n]]--\n'
    gen_code += 'end}\n'

    stderr_output = proc.stderr.read().strip()
    if stderr_output:
        print("Lua stderr:\n", stderr_output, file=sys.stderr)

    with open(sys.argv[1], 'wt') as f:
        f.write(gen_code)
