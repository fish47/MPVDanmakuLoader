local constants     = require("src/base/constants")
local classlite     = require("src/base/classlite")
local utils         = require("src/base/utils")
local unportable    = require("src/base/unportable")
local application   = require("src/shell/application")
local mocks         = require("test/mocks")


local MockApplicationWithBuiltinPlugins =
{
    _mNetworkConnection     = classlite.declareClassField(unportable.CURLNetworkConnection),

    _initDanmakuSourcePlugins = application.MPVDanmakuLoaderApp._initDanmakuSourcePlugins,
}

classlite.declareClass(MockApplicationWithBuiltinPlugins, mocks.MockApplication)


