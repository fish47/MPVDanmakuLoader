# MPVDanmakuLoader

* [ScreenShot](#sceenshot)
* [Features](#features)
* [Requirements](#requirements)
* [Installation](#installation)
* [SearchSyntax](#searchsyntax)
* [Configuration](#configuration)
* [KnownIssues](#knownissues)


## ScreenShot
![screenshot](https://raw.githubusercontent.com/fish47/MPVDanmakuLoader/resources/screenshots.gif)

## Features
* BiliBili / DanDanPlay 弹幕解释
* 多弹幕源同屏显示
* 分P弹幕源合并
* 离线弹幕源管理


## Requirements
* mpv
* lua 5.2+
* coreutils
* zenity
* curl
* enca


## Installation
下载源码并安装脚本
```bash
_PROJECT_PATH=/tmp/MPVDanmakuLoader
git clone --single-branch https://github.com/fish47/MPVDanmakuLoader.git "$_PROJECT_PATH"

pushd "$_PROJECT_PATH"
mkdir -p  ~/.config/mpv/scripts/
lua tool/mergefiles.lua > ~/.config/mpv/scripts/mpvdanmakuloader.lua
popd
```
建议通过`~/.config/mpv/input.conf`来修改快捷键，例如
```
Ctrl+d script-binding mpvdanmakuloader/load
```


## SearchSyntax
* 输入视频网址，目前只支持 BiliBili
* 根据视频ID搜索，如 `bili:avXXX` `bili:cidXXX`
* 根据关键字搜索，如 `ddp:XXX`


## Configuration
配置文件是视频目录下的`.mpvdanmakuloader/cfg.lua`，如果没有需要自行创建，下面是例子
```lua
local cfg = ...

-- 其他字段详见 MPVDanmakuLoaderApp._initConfiguration()@src/shell/application.lua
cfg.danmakuReservedBottomHeight = 30
cfg.subtitleReservedBottomHeight = 10

-- 修改或过滤弹幕，参数类型是 DanmakuData@src/core/danmaku.lua ，返回 true 过滤此弹幕
cfg.modifyDanmakuDataHook = function(data)
    if data.danmakuText:match("小埋色")
    then
        return true
    end
end

-- 修改弹幕样式，样式定义详见 _ASS_PAIRS_STYLE_DEFINITIONS@src/base/_ass.lua
cfg.modifyDanmakuStyleHook = function(styleData)
    styleData["Underline"] = true
end

-- 比较弹幕来源是否相同，参数类型是 DanmakuSourceID@src/core/danmaku.lua
cfg.compareSourceIDHook = function(sourceID1, sourceID2)
    -- 例如某个目录下，保存了不同时期的弹幕 xml 文件，为了去除重复弹幕，可以认为弹幕来源是相同的
    local dir1, fileName1 = mp.utils.split_path(sourceID1.filePath)
    local dir2, fileName2 = mp.utils.split_path(sourceID2.filePath)
    if dir1 == dir2 and fileName1 and fileName2
    then
        return fileName1:match(".*%.xml") and fileName2:match(".*%.xml")
    end
end
```


## KnownIssues
* mkv 自带字幕不能和弹幕共存，貌似 mpv 对 `--secondary-sid` 支持不好，连基本的 SRT + ASS 播放也不正确
* `io.popen()` 不支持读写方式，[官方邮件列表](http://lua-users.org/lists/lua-l/2007-10/msg00189.html)甚至有解释过。项目中有这样的用例，但暂时没发现死锁