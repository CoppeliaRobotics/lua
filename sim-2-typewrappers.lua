-- file generated automatically - do not edit

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

        sim.initScript = wrap(sim.initScript, function(origFunc)
            return function(...)
                local args = {...}
                args[1] = read_handle(args[1], sim.handle_self) -- scriptHandle [handle]
                return origFunc(table.unpack(args))
            end
        end)

        sim.readForceSensor = wrap(sim.readForceSensor, function(origFunc)
            return function(...)
                local args = {...}
                args[1] = read_handle(args[1], nil) -- objectHandle [handle]
                local ret = {origFunc(table.unpack(args))}
                ret[1] = write_vector3(ret[1]) -- forceVector [vector3]
                ret[2] = write_vector3(ret[2]) -- torqueVector [vector3]
                return table.unpack(ret)
            end
        end)

        sim.addForce = wrap(sim.addForce, function(origFunc)
            return function(...)
                local args = {...}
                args[1] = read_handle(args[1], nil) -- shapeHandle [handle]
                args[2] = read_vector3(args[2], nil) -- position [vector3]
                args[3] = read_vector3(args[3], nil) -- force [vector3]
                return origFunc(table.unpack(args))
            end
        end)

        sim.addForceAndTorque = wrap(sim.addForceAndTorque, function(origFunc)
            return function(...)
                local args = {...}
                args[1] = read_handle(args[1], nil) -- shapeHandle [handle]
                args[2] = read_vector3(args[2], {0.0, 0.0, 0.0}) -- force [vector3]
                args[3] = read_vector3(args[3], {0.0, 0.0, 0.0}) -- torque [vector3]
                return origFunc(table.unpack(args))
            end
        end)
    end
}
