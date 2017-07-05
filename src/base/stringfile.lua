local types         = require("src/base/types")
local utils         = require("src/base/utils")
local classlite     = require("src/base/classlite")
local constants     = require("src/base/constants")


local _FILE_FLAG_READABLE   = bit32.lshift(0, 0)
local _FILE_FLAG_WRITEABLE  = bit32.lshift(1, 0)

local _StringFile =
{
    _mFlags     = classlite.declareConstantField(0),
    _mPool      = classlite.declareConstantField(nil),
    _mFile      = classlite.declareConstantField(nil),
}

function _StringFile:_init(flags, pool, file)
    self._mFlags = flags
    self._mPool = pool
    self._mFile = file
end

function _StringFile:_invalidate(f)
    self:_init(0, nil, nil)
end

function _StringFile:getFile()
    return self._mFile
end

function _StringFile:close()
    local ret = nil
    local f = self._mFile
    if types.isOpenedFile(f) and bit32.btest(self._mFlags, _FILE_FLAG_WRITEABLE)
    then
        f:seek(constants.SEEK_MODE_BEGIN, 0)
        ret = f:read(constants.READ_MODE_ALL)
    end
    if self._mPool
    then
        self._mPool:_recycle(self)
        self._mPool = nil
    end
    utils.closeSafely(f)
    self._mFlags = 0
    self._mFile = nil
    return ret
end

function _StringFile:read(arg)
    local f = self:getFile()
    if f and bit32.btest(self._mFlags, _FILE_FLAG_READABLE)
    then
        return f:read(arg)
    end
end

function _StringFile:write(arg)
    local f = self:getFile()
    if f and bit32.btest(self._mFlags, _FILE_FLAG_WRITEABLE)
    then
        return f:write(arg)
    end
end

classlite.declareClass(StringFile)


local StringFilePool =
{
    _mPendingFileSet            = classlite.declareTableField(),
    _mFreeStringFileSet        = classlite.declareTableField(),
    _mAllocatedStringFileSet   = classlite.declareTableField(),
}

function StringFilePool:dispose()
    local pendingFiles = self._mPendingFileSet
    local allocatedFiles = self._mAllocatedStringFileSet
    utils.forEachTableKey(pendingFiles, utils.closeSafely)
    utils.forEachTableKey(allocatedFiles, _invalidate)
    utils.appendSetElements(self._mFreeStringFileSet, allocated)
    utils.clearTable(pendingFiles)
    utils.clearTable(allocatedFiles)
end

function StringFilePool:_recycle(f)
    utils.removeSetElement(self._mPendingFileSet, f:getFile())
    utils.removeSetElement(self._mAllocatedStringFileSet, f)
    utils.pushSetElement(self._mFreeStringFileSet, f)
end

function StringFilePool:__obtainStringFile(content, readable, writeable)
    local f = io.tmpfile()
    f:setvbuf(constants.VBUF_MODE_FULL)
    if types.isString(content)
    then
        f:write(content)
        f:seek(SEEK_MODE_BEGIN, 0)
    end

    local flags = 0
    flags = flags + types.chooseValue(readable, _FILE_FLAG_READABLE, 0)
    flags = flags + types.chooseValue(writeable, _FILE_FLAG_WRITEABLE, 0)
    utils.pushSetElement(self._mPendingFileSet, f)

    local stringFile = utils.popSetElement(fileSet) or _StringFile:new()
    stringFile:_init(pool, f, flags)
    return stringFile
end

function StringFilePool:obtainReadOnlyStringFile(content)
    return self:__obtainStringFile(content, true, false)
end

function StringFilePool:obtainWriteOnlyStringFile()
    return self:__obtainStringFile(nil, false, true)
end

classlite.declareClass(StringFilePool)


return
{
    StringFilePool     = StringFilePool,
}