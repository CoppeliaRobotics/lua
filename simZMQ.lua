local simZMQ={}

function simZMQ.__init()
    -- wrap blocking functions with busy-wait loop:
    for func_name,flags_idx in pairs{msg_send=3,msg_recv=3,send=3,recv=2} do
        if not simZMQ['__'..func_name] then
            simZMQ['__'..func_name]=simZMQ[func_name]
            simZMQ[func_name]=function(...)
                local args={...}
                if sim.boolAnd32(args[flags_idx],simZMQ.DONTWAIT)>0 then
                    return simZMQ['__'..func_name](...)
                end
                args[flags_idx]=sim.boolOr32(args[flags_idx],simZMQ.DONTWAIT)
                while true do
                    local ret={simZMQ['__'..func_name](unpack(args))}
                    if ret[1]==-1 and simZMQ.errnum()==simZMQ.EAGAIN then
                        sim.switchThread()
                    else
                        return unpack(ret)
                    end
                end
            end
        end
    end

    simZMQ.__init=nil
end

__initFunctions=__initFunctions or {}
table.insert(__initFunctions,simZMQ.__init)

return simZMQ
