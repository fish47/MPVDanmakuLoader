# MPVDanmakuLoader

* [简介](#overview)
* [环境要求](#requirement)
* [使用方法](#usage)
* [配置说明](#configuration)
* [已知问题](#knownissues)

## 简介
TODO

## 环境要求
* Linux
* coreutils
* mpv
* lua 5.2+
* zenity
* curl
* enca

## 使用方法
TODO

## 配置说明
TODO

## 已知问题
* 理论上用 python 重写所有非平台相关的代码，应该可以兼容更多平台，没需求所以没有做。
* mkv 自带字幕不能和弹幕共存，貌似 mpv 对 ...... 支持得并不好，连基本的 srt + ass 播放也是不正确的。
* 据闻 io.popen() 不支持读写方式，项目中也有这样的用例，但暂时没发现死锁。
*