local simIM={}

function simIM.numActiveHandles()
    local h=simIM.handles()
    return #h
end

--@fun dataURL Encode image data according to "data" URL scheme (RFC 2397)
--@arg string imgHandle Handle to the image
--@arg {type=string,default='BMP'} format Image format (BMP, JPG, or PNG)
--@ret string output Buffer with encoded data
function simIM.dataURL(imgHandle,fmt)
    local mime={BMP='image/bmp',PNG='image/png',JPG='image/jpeg'}
    if not mime[fmt] then error('invalid format: '..fmt) end
    local buf=simIM.encode(imgHandle,fmt)
    return 'data:'..mime[fmt]..';base64,'..sim.transformBuffer(buf,sim.buffer_uint8,1,0,sim.buffer_base64)
end

return simIM
