#!/usr/bin/env python3

import sys
import re

def extract_module_functions(lua_file, module_name):
    if module_name:
        pattern = re.compile(rf'^\s*function\s+{re.escape(module_name)}\.(\w+)\s*\(')
    else:
        pattern = re.compile(rf'^\s*function\s+(\w+)\s*\(')
    functions = set()

    with open(lua_file, 'r', encoding='utf-8') as f:
        for line in f:
            match = pattern.match(line)
            if match:
                function_name = match.group(1)
                if module_name:
                    functions.add(f"{module_name}.{function_name}(")
                else:
                    functions.add(f"{function_name}(")

    return functions

def read_calltips(calltip_file):
    with open(calltip_file, 'r', encoding='utf-8') as f:
        return set(line.strip() for line in f)

def check_calltips(calltip_file, lua_file, module_name=None, print_file_name=True):
    fn = f'{lua_file}: ' if print_file_name else ''

    lua_functions = extract_module_functions(lua_file, module_name)
    calltip_lines = read_calltips(calltip_file)

    missing = [func for func in lua_functions if not any(func in line for line in calltip_lines)]

    if missing:
        print(f"{fn}Missing calltips for the following functions:")
        for func in missing:
            print(f"  {func}")
    else:
        print(f"{fn}All functions have calltips.")

if __name__ == "__main__":
    if len(sys.argv) in (3, 4):
        calltip_file = sys.argv[1]
        lua_file = sys.argv[2]
        module_name = sys.argv[3] if len(sys.argv) >= 4 else None
        check_calltips(calltip_file, lua_file, module_name, print_file_name=False)
    elif len(sys.argv) == 1:
        check_calltips('base-ce.lua', 'base.lua')
        check_calltips('checkargs-ce.lua', 'checkargs.lua', 'checkarg')
        check_calltips('base16-ce.lua', 'base16.lua', 'base16')
        check_calltips('base64-ce.lua', 'base64.lua', 'base64')
        check_calltips('functional-ce.lua', 'functional.lua')
        check_calltips('itertools-ce.lua', 'itertools.lua', 'itertools')
        check_calltips('mathx-ce.lua', 'mathx.lua', 'math')
        check_calltips('sim-1-ce.lua', 'sim-1.lua', 'sim')
        check_calltips('stringx-ce.lua', 'stringx.lua', 'string')
        check_calltips('tablex-ce.lua', 'tablex.lua', 'table')
        check_calltips('var-ce.lua', 'var.lua')
    else:
        print(f"Usage: {sys.executable} check_calltips.py <calltip_file> <lua_file> [module_name]")
        sys.exit(1)


