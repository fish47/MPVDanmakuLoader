local classlite     = require("src/base/classlite")


local _FILE_FLAG_READABLE   = bit32.lshift(1, 0)
local _FILE_FLAG_WRITEABLE  = bit32.lshift(1, 0)

local _BridgedFile =
{
    _mFlags     = classlite.declareConstantField(0),
    _mPool      = classlite.declareConstantField(nil),
    _mFile      = classlite.declareConstantField(nil),
}

function _BridgedFile:getFile()
    return self._mFile
end

function _BridgedFile:close()
    self._mFile = nil
    self._mFlags = 0
    if self._mPool
    then
        self._mPool:_recycle(self)
        self._mPool = nil
    end
end

function _BridgedFile:read(arg)
    local f = self._mFile
    if f and bit32.btest(self._mFlags, _FILE_FLAG_READABLE)
    then
        return f:read(arg)
    end
end

function _BridgedFile:write(arg)
    local f = self._mFile
    if f and bit32.btest(self._mFlags, _FILE_FLAG_WRITEABLE)
    then
        return f:write(arg)
    end
end

classlite.declareClass(BridgedFile)


local BridgedFilePool =
{}

function BridgedFilePool:_recycle(f)
end

function BridgedFilePool:obtainFileByPath(path)
end

function BridgedFilePool:obtainFileByContent(content)
end

classlite.declareClass(BridgedFilePool)


return
{
    BridgedFilePool     = BridgedFilePool,
}