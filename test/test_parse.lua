local lu = require('3rdparties/luaunit')    --= luaunit lu
local parse = require('src/parse')          --= parse parse

local MockFile =
{
    _mContent = nil,

    close = function(self.)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())