local mock          = require("common/mock")
local utils         = require("src/base/utils")
local types         = require("src/base/types")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")
local pluginbase    = require("src/plugins/pluginbase")
local logic         = require("src/shell/logic")


local MockShell =
{
    _mDanmakuSourceManager  = classlite.declareClassField(mock.MockDanmakuSourceManager),
}

function MockShell:setApplication(app)
    local function _ensurePlugin(app, name, func)
        if not app:getPluginByName(name)
        then
            local plugin = mock.MockRemoteDanmakuSourcePlugin:new(name)
            func(plugin)
            app:_addDanmakuSourcePlugin(plugin)
        end
    end

    local function __initPlugin1(plugin)
        plugin:addSearchResult("a", { "Title1", "Title2", "Title3", "Title4" })
        plugin:addSearchResult("b",
                               { "Title1", "Subtitle1", "Title2", "Subtitle2" },
                               2)
    end

    local function __initPlugin2(plugin)
        plugin:addSearchResult("c", { "Title1", "Title2" })
    end

    logic.MPVDanmakuLoaderShell.setApplication(self, app)
    _ensurePlugin(app, "Plugin1", __initPlugin1)
    _ensurePlugin(app, "Plugin2", __initPlugin2)
end


function MockShell:_showSelectFiles(outPaths)
    -- 控件选中的是实际文件系统的路径，在虚拟文件系统是不存在的，这里也顺道创建空文件
    local ret = logic.MPVDanmakuLoaderShell._showSelectFiles(self, outPaths)
    local app = self._mApplication
    for _, path in ipairs(outPaths)
    do
        if not app:isExistedFile(path)
        then
            app:createDir(unportable.splitPath(path))
            local f = app:writeFile(path)
            f:write(constants.STR_EMPTY)
            app:closeFile(f)
        end
    end
    return ret
end

classlite.declareClass(MockShell, logic.MPVDanmakuLoaderShell)


local shell = MockShell:new()
local app = mock.DemoApplication:new()
app:setLogFunction(print)
app:init()
app:updateConfiguration()
shell:setApplication(app)
shell:showMainWindow()
shell:dispose()
app:dispose()