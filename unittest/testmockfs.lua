local lu            = require("unittest/luaunit")    --= luaunit lu
local mockfs        = require("unittest/mockfs")
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
    __mFileSystem           = nil,

    __mPathsAndContents     = nil,


    setUp = function(self)
        local fs = mockfs.MockFileSystem:new()
        fs:setup()
        self.__mFileSystem = fs

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
        self.__mPathsAndContents = pathsAndContents
    end,

    tearDown = function(self)
        self.__mFileSystem:unsetup()
        self.__mFileSystem:dispose()
    end,


    testRead = function(self)
        local fs = self.__mFileSystem
        local pathsAndContents = self.__mPathsAndContents
        for _, path, content in utils.iteratePairsArray(pathsAndContents)
        do
            lu.assertTrue(fs:doesFileExist(path))
            lu.assertEquals(__readFile(fs, path), content)
        end
    end,


    testListFiles = function(self)
        local assertDirsAndFilePaths =
        {
            "/a",       { "/a/1.txt", "/a/2.txt" },
            "/a/c",     { "/a/c/3.txt", "/a/c/4.txt", "/a/c/5.txt" },
            "/a/b",     { "/a/b/6.txt", "/a/b/7.txt" },
            "/b/",      { "/b/8.txt" },
        }

        local fs = self.__mFileSystem
        local filePaths = {}
        for _, dir, assertFilePaths in utils.iteratePairsArray(assertDirsAndFilePaths)
        do
            fs:listFiles(dir, filePaths)
            table.sort(filePaths)
            table.sort(assertFilePaths)
            lu.assertEquals(filePaths, assertFilePaths)
        end
    end,


    testDeleteTree = function(self)
        local fs = self.__mFileSystem
        local filePaths = {}
        local assertEmptyDirs = { "/a/c", "/a/b", "/b", "/a" }
        for _, dir in ipairs(assertEmptyDirs)
        do
            fs:deleteTree(dir)
            fs:listFiles(dir, filePaths)
            lu.assertTrue(types.isEmptyTable(filePaths))
        end
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())