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

    gen_code = """-- file generated automatically - do not edit

return {
    extend = function(sim)
        local simEigen = require 'simEigen'
        local Color = require 'Color'

        local function write_vector3(v)
            return simEigen.Vector(v)
        end

        local function write_matrix(v)
            return simEigen.Matrix(v)
        end

        local function write_quaternion(v)
            return simEigen.Quaternion(v)
        end

        local function write_pose(v)
            return simEigen.Pose(v)
        end

        local function write_color(v)
            return Color(v)
        end

        local function write_handle(v)
            return sim.Object(v)
        end

        local function read_vector3(v, def)
            if v == nil then v = def end
            if simEigen.Vector:isvector(v) then v = v:data() end
            return v
        end

        local function read_matrix(v, def)
            if v == nil then v = def end
            if simEigen.Matrix:ismatrix(v) then v = v:data() end
            return v
        end

        local function read_quaternion(v, def)
            if v == nil then v = def end
            if simEigen.Quaternion:isquaternion(v) then v = v:data() end
            return v
        end

        local function read_pose(v, def)
            if v == nil then v = def end
            if simEigen.Pose:ispose(v) then v = v:data() end
            return v
        end

        local function read_color(v, def)
            if v == nil then v = def end
            if Color:iscolor(v) then v = v:data() end
            return v
        end

        local function read_handle(v, def)
            if v == nil then v = def end
            if sim.Object:isobject(v) then v = #v end
            return v
        end
"""
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
                if arg.type in ('vector3', 'matrix', 'quaternion', 'pose', 'color', 'handle'):
                    in_recipes[i] = arg.type
            for i, ret in enumerate(f.out_args):
                if isinstance(ret, VarArgs): continue
                if ret.type in ('vector3', 'matrix', 'quaternion', 'pose', 'color', 'handle'):
                    out_recipes[i] = ret.type
            if not in_recipes and not out_recipes: continue
            gen_code += f"""
        {f.func_name} = wrap({f.func_name}, function(origFunc)
            return function(...)
                local args = {{...}}
"""
            for i, recipe in in_recipes.items():
                var = f'args[{i+1}]'
                dv = 'nil'
                if hasattr(f.in_args[i], 'default'):
                    dv = str(f.in_args[i].default)
                    dv = dv.replace('[', '{').replace(']', '}')
                gen_code += f"""                {var} = read_{recipe}({var}, {dv}) -- {f.in_args[i].name} [{f.in_args[i].type}]
"""
            if out_recipes:
                gen_code += f"""                local ret = {{origFunc(table.unpack(args))}}
"""
                for i, recipe in out_recipes.items():
                    var = f'ret[{i+1}]'
                    gen_code += f"""                {var} = write_{recipe}({var}) -- {f.out_args[i].name} [{f.out_args[i].type}]
"""
                gen_code += f"""                return table.unpack(ret)
"""
            else:
                gen_code += f"""                return origFunc(table.unpack(args))
"""
            gen_code += f"""            end
        end)
"""
        except Exception as e:
            gen_code += f"""        --[[
            ERROR: cannot parse calltip: {calltip}
            {e!s}
        ]]--
"""
    gen_code += '    end\n}\n'

    stderr_output = proc.stderr.read().strip()
    if stderr_output:
        print("Lua stderr:\n", stderr_output, file=sys.stderr)

    with open(sys.argv[1], 'wt') as f:
        f.write(gen_code)
