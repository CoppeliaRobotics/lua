local textUtils = {}

function textUtils.generateTextShape(txt, color, height, centered, alphabetModel, parentDummy)
    height = height or 0.1
    color = color or {1, 1, 1}
    alphabetModel = alphabetModel or sim.getStringParam(sim.stringparam_systemdir) ..
                        "/alphabet.ttm"
    local h = sim.loadModel(alphabetModel)
    local allChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local allLetters = {}
    local maxHeight = 0
    for i = 1, #allChars, 1 do
        local char = string.sub(allChars, i, i)
        local m = sim.getObject('./' .. char, {proxy = h})
        sim.setModelProperty(m, 0)
        allLetters[char] = sim.saveModel(m)
        local s = sim.getShapeBB(m)
        if char == 'o' then spaceWidth = s[1] end
        if s[2] > maxHeight then maxHeight = s[2] end
    end
    sim.removeModel(h)

    local off = 0
    local voff = 0
    local shapes = {}
    local lines = {{}}
    local linesW = {0}
    local scaling = height / 0.1
    for i = 1, #txt, 1 do
        local char = string.sub(txt, i, i)
        if allLetters[char] then
            local h = sim.loadModel(allLetters[char])
            local size = sim.getShapeBB(h)
            local p = sim.getObjectPosition(h)
            off = off + size[1] * 0.5 + height * 0.03
            sim.setObjectPosition(h, {off, p[2] - voff, 0})
            off = off + size[1] * 0.5 + height * 0.03
            shapes[#shapes + 1] = h
            lines[#lines][#lines[#lines] + 1] = h
            linesW[#linesW] = off
        else
            if char == "\n" then
                off = 0
                voff = voff + maxHeight * 1.1
                lines[#lines + 1] = {}
                linesW[#linesW + 1] = 0
            else
                off = off + spaceWidth
            end
        end
    end

    if centered then
        for i = 1, #linesW, 1 do
            for j = 1, #lines[i], 1 do
                local s = lines[i][j]
                local p = sim.getObjectPosition(s)
                sim.setObjectPosition(s, {p[1] - linesW[i] / 2, p[2], p[3]})
            end
        end
    end
    local s
    if #shapes > 0 then
        if #shapes > 1 then
            s = sim.groupShapes(shapes, true)
        else
            s = shapes[1]
        end
        local p = sim.getObjectPosition(s)
        sim.setObjectPosition(s, {p[1], p[2] + voff, p[3]})
        sim.setModelProperty(s, sim.modelproperty_not_model)
        sim.alignShapeBB(s, {0, 0, 0, 0, 0, 0, 1})
        sim.relocateShapeFrame(s, {0, 0, 0, 0, 0, 0, 0})
        sim.setObjectProperty(s, sim.objectproperty_selectable | sim.objectproperty_selectmodelbaseinstead)
        sim.setObjectAlias(s, 'text')
        sim.scaleObjects({s}, scaling, true)
        sim.setShapeColor(s, nil, sim.colorcomponent_ambient_diffuse, color)
    end
    if parentDummy == nil then
        retVal = sim.createDummy(0.005)
    else
        while true do
            local c = sim.getObjectChild(parentDummy, 0)
            if c == -1 then break end
            sim.removeObjects({c})
        end
        retVal = parentDummy
    end
    if #shapes > 0 then sim.setObjectParent(s, retVal, false) end
    sim.setModelProperty(retVal, 0)
    sim.setObjectProperty(retVal, sim.objectproperty_selectable | sim.objectproperty_collapsed)
    sim.setObjectInt32Param(retVal, sim.objintparam_visibility_layer, 1024)
    if #txt == 0 then txt = "txt" end
    sim.setObjectAlias(retVal, txt)
    sim.setObjectSelection({retVal})
    return retVal
end

return textUtils
