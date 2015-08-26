local utils = require('src/utils')          --= utils utils


local __MPVBuiltinMixin =
{
    setSubtitle = function(self, path)
        --
    end,

    splitPath = function(self, path)
        return mp.utils.split_path(path)
    end,

    joinPath = function(self, p1, p2)
        return mp.utils.join_path(p1, p2)
    end,

    listFiles = function(self, dir)
        return mp.utils.readdir(dir, "files")
    end,

    getVideoFilePath = function(self)
        return mp.get_property("path", nil)
    end,

    getVideoFileName = function(self)
        return mp.get_property("filename", nil)
    end,

    getVideoByteCount = function(self)
        return mp.get_property_number("file-size", nil)
    end,

    getVideoDuration = function(self)
        local seconds = mp.get_property_number("duration", nil)
        return seconds and utils.convertHHMMSSToTime(0, 0, seconds, 0)
    end,

    getVideoWidth = function(self)
        local width = mp.get_property("width", nil)
        return width and tonumber(width)
    end,

    getVideoHeight = function(self)
        local height = mp.get_property("height", nil)
        return height and tonumber(height)
    end,
}

utils.declareClass(__MPVBuiltinMixin)