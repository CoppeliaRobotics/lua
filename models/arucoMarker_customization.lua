sim = require 'sim'
simIM = require 'simIM'
require 'configUi'

function sysCall_init()
    self = sim.getObject '.'
end

function generate(config)
    sim.removeReferencedObjects(self)
    local dictType = simIM.dict_type['_' .. configUi.schema.dictType.choices[config.dictType]]
    local dict = simIM.getMarkerDictionary(dictType)
    local pxSize = simIM.getMarkerBitSize(dictType) + 2
    local r, img = pcall(simIM.drawMarker, dict, config.id, pxSize)
    if not r then
        sim.addLog(sim.verbosity_errors, img)
        return
    end
    simIM.gray2rgb(img, true)
    local size = config.size / pxSize
    size = {size, size, config.thickness}
    for i = 0, pxSize - 1 do
        for j = 0, pxSize - 1 do
            local h = sim.createPrimitiveShape(sim.primitiveshape_cuboid, size)
            sim.addReferencedHandle(self, h)
            local c = simIM.get(img, {i, j})
            sim.setShapeColor(h, '', sim.colorcomponent_ambient_diffuse, (Vector(c) / 255):data())
            sim.setObjectParent(h, self, false)
            sim.setObjectPosition(
                h,
                {size[1] * (i - (pxSize - 1) / 2), size[2] * (j - (pxSize - 1) / 2), size[3] / 2},
                sim.handle_parent
            )
        end
    end
    simIM.destroy(img)
    sim.setObjectProperty(self, sim.getObjectProperty(self) | sim.objectproperty_collapsed)
end

configUi = ConfigUI(
    'arucoMarker',
    {
        dictType = {
            name = 'Dictionary type',
            choices = {
                '4X4_50', '4X4_100', '4X4_1000', '4X4_250', '5X5_50', '5X5_100', '5X5_1000',
                '5X5_250', '6X6_50', '6X6_100', '6X6_1000', '6X6_250', '7X7_50', '7X7_100',
                '7X7_1000', '7X7_250', 'APRILTAG_16h5', 'APRILTAG_25h9', 'APRILTAG_36h10',
                'APRILTAG_36h11', 'ARUCO_ORIGINAL',
            },
            default = 1,
            ui = {control = 'combo', group = 0, order = 0},
        },
        id = {
            name = 'Marker ID',
            type = 'int',
            minimum = 0,
            maximum = 999,
            ui = {group = 0, order = 1},
        },
        size = {
            name = 'Size',
            type = 'float',
            default = 0.1,
            minimum = 0.001,
            maximum = 1,
            ui = {control = 'spinbox', group = 1, order = 2},
        },
        thickness = {
            name = 'Thickness',
            type = 'float',
            default = 0.005,
            minimum = 0.001,
            maximum = 1,
            ui = {control = 'spinbox', group = 1, order = 3},
        },
    },
    generate
)
