function setupForLang(lang)
    sim.setNamedStringParam('simCmd.preferredSandboxLang', lang)
    simCmd.setSelectedScript(-1, lang)
    sim.setStringParam(sim.stringparam_sandboxlang, lang)
    simUI.destroy(ui)
    ui = nil
end

function setupForLua()
    setupForLang 'lua'
end

function setupForPython()
    setupForLang 'python'
end

local function main()
    local prefLang = sim.getStringParam(sim.stringparam_sandboxlang)
    if prefLang ~= '' then
        -- already set
        return
    end

    sim = require 'sim'
    simUI = require 'simUI'
    simCmd = require 'simCmd'

    local resourcesDir = sim.getStringParam(sim.stringparam_resourcesdir)
    local imagesDir = resourcesDir .. '/manual/en/images/usedByScripts/'

    local imgStyle =
        'background-color: white; border: 1px solid white; border-radius: 8px; padding-top: 100px;'
    local function imgSize(w, h)
        local platform = sim.getInt32Param(sim.intparam_platform)
        if platform == 1 then
            return ''
        else
            local k = 4
            return string.format('width="%d" height="%d"', w // k, h // k)
        end
    end

    local v = sim.getInt32Param(sim.intparam_program_full_version)
    v = table.join({v // 1000000, v // 10000 % 100, v // 100 % 100}, '.')
    ui = simUI.create(
             [[<ui closeable="true" title="Welcome to CoppeliaSim ]] .. v .. [[" modal="true">
        <label text="This version of CoppeliaSim supports both <b>Lua</b> and <b>Python</b> as the scripting languages for writing child scripts, customization scripts and add-ons. Choosing your preferred language will make it easier to access (e.g. in the sandbox).<br/><br/>Which language do you want to set as the preferred language?" wordwrap="true" />
        <group flat="true" layout="hbox">
            <group>
                <image scaled-contents="true" keep-aspect-ratio="true"
                    file="]] .. imagesDir .. [[lua-logo.png"
                    style="]] .. imgStyle .. [["
                    ]] .. imgSize(512, 512) .. [[
                    />
                <button text="Set up for Lua"
                    on-click="setupForLua" />
            </group>
            <group>
                <image scaled-contents="true" keep-aspect-ratio="true"
                    file="]] .. imagesDir .. [[python-logo.png"
                    style="]] .. imgStyle .. [["
                    ]] .. imgSize(559, 512) .. [[
                    />
                <button text="Set up for Python"
                    on-click="setupForPython" />
            </group>
        </group>
        <label text="Note: you can change it later by modifying <em>preferredSandboxLang</em> in usrset.txt." />
    </ui>]]
         )
end

main()
