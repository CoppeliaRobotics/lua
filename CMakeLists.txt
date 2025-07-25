cmake_minimum_required(VERSION 3.12)
project(luaFiles)

if(NOT COPPELIASIM_INCLUDE_DIR)
    if(DEFINED ENV{COPPELIASIM_ROOT_DIR})
        set(COPPELIASIM_INCLUDE_DIR $ENV{COPPELIASIM_ROOT_DIR}/programming/include)
    else()
        set(COPPELIASIM_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../include)
    endif()
endif()
list(APPEND CMAKE_MODULE_PATH ${COPPELIASIM_INCLUDE_DIR}/cmake)
find_package(CoppeliaSim 4.5.0.7 REQUIRED)

file(GLOB LUA_FILES CONFIGURE_DEPENDS *.lua)
foreach(LUA_FILE IN LISTS LUA_FILES)
    coppeliasim_add_lua(${LUA_FILE})
endforeach()
coppeliasim_add_lua_directory("addOns")
coppeliasim_add_lua_directory("models")
coppeliasim_add_lua_directory("deprecated")
coppeliasim_add_lua_directory("utils")
coppeliasim_add_lua_directory("sim")
coppeliasim_add_lua_directory("sha1")

set(PYTHON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../python")
set(LUA_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/sim-2-typewrappers.lua"
    COMMAND ${CMAKE_COMMAND} -E env
        LUA_PATH=${CMAKE_CURRENT_SOURCE_DIR}/?.lua
        PYTHONPATH=${PYTHON_DIR}
        python3 "${LUA_DIR}/tools/generate_typewrappers.py" "${CMAKE_CURRENT_BINARY_DIR}/sim-2-typewrappers.lua"
    DEPENDS
        "${LUA_DIR}/tools/generate_typewrappers.py"
        "${LUA_DIR}/sim-2-ce.lua"
        "${PYTHON_DIR}/calltip.py"
        "${PYTHON_DIR}/calltip.lark"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    COMMENT "Generating sim-2-typewrappers.lua from sim-2-ce.lua"
    VERBATIM
)
add_custom_target(generate_typewrappers ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/sim-2-typewrappers.lua")
coppeliasim_add_lua("${CMAKE_CURRENT_BINARY_DIR}/sim-2-typewrappers.lua")
