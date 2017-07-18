local lu            = require("lib/luaunit")
local mock          = require("common/mock")
local testutils     = require("common/testutils")
local types         = require("src/base/types")
local utils         = require("src/base/utils")
local constants     = require("src/base/constants")
local unportable    = require("src/base/unportable")


local function __writeFile(fs, fullPath, content)
    local dir, fileName = unportable.splitPath(fullPath)
    fs:createDir(dir)

    local f = fs:writeFile(fullPath)
    f:write(content)
    f:close()
end


local function __readFile(fs, fullPath)
    local content = nil
    local f = fs:readFile(fullPath)
    if f
    then
        content = f:read(constants.READ_MODE_ALL)
        f:close()
    end
    return content
end


TestMockFileSystem =
{
    _mFileSystem        = nil,
    _mPathsAndContents  = nil,
}

function TestMockFileSystem:setUp()
    local fs = mock.MockFileSystem:new()
    self._mFileSystem = fs

    local pathsAndContents =
    {
        "/a/1.txt",     "1111",
        "/a/2.txt",     "2222",
        "/a/c/3.txt",   "3333",
        "/a/c/4.txt",   "4444",
        "/a/c/5.txt",   "55555",
        "/a/b/6.txt",   "66666",
        "/a/b/7.txt",   "77777",
        "/b/8.txt",     "88888",
    }
    for _, path, content in utils.iteratePairsArray(pathsAndContents)
    do
        __writeFile(fs, path, content)
    end
    self._mPathsAndContents = pathsAndContents
end

function TestMockFileSystem:tearDown()
    utils.disposeSafely(self._mFileSystem)
    utils.clearTable(self._mPathsAndContents)
end


function TestMockFileSystem:testRead()
    local fs = self._mFileSystem
    local pathsAndContents = self._mPathsAndContents
    for _, path, content in utils.iteratePairsArray(pathsAndContents)
    do
        lu.assertTrue(fs:isExistedFile(path))
        lu.assertEquals(__readFile(fs, path), content)
    end
end


function TestMockFileSystem:testListFiles()
    local assertDirsAndFilePaths =
    {
        "/a",       { "/a/1.txt", "/a/2.txt" },
        "/a/c",     { "/a/c/3.txt", "/a/c/4.txt", "/a/c/5.txt" },
        "/a/b",     { "/a/b/6.txt", "/a/b/7.txt" },
        "/b/",      { "/b/8.txt" },
    }

    local fs = self._mFileSystem
    local filePaths = {}
    for _, dir, assertFilePaths in utils.iteratePairsArray(assertDirsAndFilePaths)
    do
        fs:listFiles(dir, filePaths)
        table.sort(filePaths)
        table.sort(assertFilePaths)
        lu.assertEquals(filePaths, assertFilePaths)
    end
end


function TestMockFileSystem:testDeletePath()
    local fs = self._mFileSystem
    local filePaths = {}
    local assertEmptyDirs = { "/a/c", "/a/b", "/b", "/a" }
    for _, dir in ipairs(assertEmptyDirs)
    do
        fs:deletePath(dir)
        fs:listFiles(dir, filePaths)
        lu.assertTrue(types.isEmptyTable(filePaths))
    end
end


function TestMockFileSystem:testClosePenddingFiles()
    local fs = self._mFileSystem
    local f1 = fs:writeFile("/1.txt")
    f1:write("1234")
    f1:close()
    lu.assertTrue(types.isClosedFile(f1))

    local f2 = fs:readFile("/1.txt")
    local f3 = fs:writeFile("/2.txt")
    fs:dispose()
    lu.assertTrue(types.isClosedFile(f2))
    lu.assertTrue(types.isClosedFile(f3))
end


function TestMockFileSystem:testReadWriteSameFile()
    local fs = self._mFileSystem
    local path1 = "/1/2/3.txt"
    __writeFile(fs, path1, "1234")
    local f1 = fs:readFile(path1)
    local f2 = fs:readFile(path1)
    local f3 = fs:writeFile(path1)
    lu.assertTrue(types.isOpenedFile(f1))
    lu.assertIsNil(f2)
    lu.assertIsNil(f3)
    f1:close()

    local path2 = "/4/5/6.txt"
    fs:createDir(unportable.splitPath(path2))
    local f4 = fs:writeFile(path2)
    local f5 = fs:readFile(path2)
    local f6 = fs:writeFile(path2)
    lu.assertTrue(types.isOpenedFile(f4))
    lu.assertIsNil(f5)
    lu.assertIsNil(f6)
    f4:close()

    local path3 = self._mPathsAndContents[1]
    local f7 = fs:readFile(path3)
    lu.assertNotNil(f7:read(constants.READ_MODE_ALL))
    f7:close()
    local f8 = fs:readFile(path3)
    lu.assertNotNil(f8)
    f8:close()
end


function TestMockFileSystem:testWriteAppend()
    local fs = self._mFileSystem
    local line1 = "--> 11111"
    local line2 = "--> 22222"
    local line3 = "--> 33333"
    local path1 = self._mPathsAndContents[1]
    local content = self._mPathsAndContents[2]
    local f1 = fs:writeFile(path1, true)
    f1:write(line1)
    f1:write(line2)
    f1:write(line3)
    f1:close()
    lu.assertEquals(__readFile(fs, path1), content .. line1 .. line2 .. line3)
end


testutils.runTestCases()