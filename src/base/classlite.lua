local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")


local _METATABLE_NAME_INDEX             = "__index"

local _METHOD_NAME_CONSTRUCT            = "new"
local _METHOD_NAME_DECONSTRUCT          = "dispose"
local _METHOD_NAME_CLONE                = "clone"
local _METHOD_NAME_GET_CLASS            = "getClass"
local _METHOD_NAME_INIT_FIELDS          = "__classlite_init_fields"
local _METHOD_NAME_DEINIT_FIELDS        = "__classlite_deinit_fields"

local _FIELD_DECL_TYPE_CONSTANT         = 1
local _FIELD_DECL_TYPE_TABLE            = 2
local _FIELD_DECL_TYPE_CLASS            = 3

local _FIELD_DECL_KEY_ID                = {}
local _FIELD_DECL_KEY_TYPE              = 1
local _FIELD_DECL_KEY_FIRST_ARG         = 2
local _FIELD_DECL_KEY_CLASS_ARGS_START  = 3


local __gIsPlainClass           = {}
local __gMetatables             = {}
local __gParentClasses          = {}
local __gFieldNames             = {}
local __gFieldDeclarations      = {}
local __gFieldDeclartionID      = 0


local function __constructConstantField(obj, name, decl)
    obj[name] = decl[_FIELD_DECL_KEY_FIRST_ARG]
end

local function __constructTableField(obj, name, decl)
    obj[name] = {}
end

local function __constructClassField(obj, name, decl)
    local classType = decl[_FIELD_DECL_KEY_FIRST_ARG]
    local constructor = classType[_METHOD_NAME_CONSTRUCT]
    obj[name] = constructor(classType,
                            select(_FIELD_DECL_KEY_CLASS_ARGS_START,
                                   utils.unpackArray(decl)))
end


local _AUTO_CONSTRUCTORS =
{
    [_FIELD_DECL_TYPE_CONSTANT]     = __constructConstantField,
    [_FIELD_DECL_TYPE_TABLE]        = __constructTableField,
    [_FIELD_DECL_TYPE_CLASS]        = __constructClassField,
}


local _AUTO_DECONSTRUCTORS =
{
    [_FIELD_DECL_TYPE_CONSTANT]     = function(obj, name, decl)
        obj[name] = nil
    end,

    [_FIELD_DECL_TYPE_TABLE]        = function(obj, name, decl)
        utils.clearTable(obj[name])
        obj[name] = nil
    end,

    [_FIELD_DECL_TYPE_CLASS]        = function(obj, name, decl)
        utils.disposeSafely(obj[name])
        obj[name] = nil
    end,
}


local _AUTO_ASSIGNERS =
{
    [_FIELD_DECL_TYPE_CONSTANT]     = function(obj, name, decl, arg)
        if arg ~= nil
        then
            obj[name] = arg
        else
            __constructConstantField(obj, name, decl, arg)
        end
    end,

    [_FIELD_DECL_TYPE_TABLE]        = function(obj, name, decl, arg)
        if types.isTable(arg)
        then
            obj[name] = arg
        else
            __constructTableField(obj, name, decl, arg)
        end
    end,

    [_FIELD_DECL_TYPE_CLASS]        = function(obj, name, decl, arg)
        if types.isTable(arg)
        then
            obj[name] = arg
        else
            __constructClassField(obj, name, decl, arg)
        end
    end,
}



local function __doDeclareField(fieldType, ...)
    local ret = { fieldType, ... }
    ret[_FIELD_DECL_KEY_ID] = __gFieldDeclartionID
    __gFieldDeclartionID = __gFieldDeclartionID + 1
    return ret
end

local function declareConstantField(val)
    return __doDeclareField(_FIELD_DECL_TYPE_CONSTANT, val)
end

local function declareTableField(val)
    return __doDeclareField(_FIELD_DECL_TYPE_TABLE, val)
end

local function declareClassField(classType, ...)
    return __doDeclareField(_FIELD_DECL_TYPE_CLASS, classType, ...)
end


local function _newInstance(obj)
    local mt = obj and __gMetatables[obj]
    if mt ~= nil
    then
        -- 如果以 ClazDefObj:new() 的形式调用，第一个参数就是指向 Class 本身
        local ret = {}
        setmetatable(ret, mt)
        return true, ret
    else
        -- 也有可能是子类间接调用父类的构造方法，此时不应再创建实例
        return false, obj
    end
end

local function _disposeInstance(obj)
    if types.isTable(obj)
    then
        utils.clearTable(obj)
        setmetatable(obj, nil)
    end
end


local function __compareByDeclIDAsc(decl1, decl2)
    return (decl1[_FIELD_DECL_KEY_ID] < decl2[_FIELD_DECL_KEY_ID])
end


local function __createFielesFunction(names,
                                      decls,
                                      needToPassVarags,
                                      functionMap)
    if not names or not decls
    then
        return nil
    end

    local ret = function(self, ...)
        for i, name in ipairs(names)
        do
            local decl = decls[i]
            local declType = decl[_FIELD_DECL_KEY_TYPE]
            local arg = needToPassVarags and select(i, ...) or nil
            functionMap[declType](self, name, decl, arg)
        end
    end

    return ret
end


local function _createFieldsConstructor(clzDef)
    local names = __gFieldNames[clzDef]
    local decls = __gFieldDeclarations[clzDef]
    if names and decls
    then
        -- 简单的结构体允许用构造参数初始化所有字段
        local isPlainClass = __gIsPlainClass[clzDef]
        local funcMap = isPlainClass
                        and _AUTO_ASSIGNERS
                        or _AUTO_CONSTRUCTORS

        return __createFielesFunction(names,
                                      decls,
                                      isPlainClass,
                                      funcMap)
    else
        return constants.FUNC_EMPTY
    end
end


local function _createFieldsDeconstructor(clzDef)
    local names = __gFieldNames[clzDef]
    local decls = __gFieldDeclarations[clzDef]
    if names and decls
    then
        return __createFielesFunction(names,
                                      decls,
                                      false,
                                      _AUTO_DECONSTRUCTORS)
    else
        return constants.FUNC_EMPTY
    end
end


local function _createConstructor(clzDef, names, decls)
    local isPlainClass = __gIsPlainClass[clzDef]
    local baseClz = __gParentClasses[clzDef]
    local baseConstructor = baseClz and baseClz[_METHOD_NAME_CONSTRUCT]
    local constructor = clzDef[_METHOD_NAME_CONSTRUCT] or baseConstructor

    local ret = function(self, ...)
        local isNewlyAllocated, obj = _newInstance(self)

        -- 在执行构造方法前，将继承链上所有声明的字段都初始化，只执行一次
        if isNewlyAllocated
        then
            obj[_METHOD_NAME_INIT_FIELDS](obj, ...)
        end

        -- 如果没有明确构造方法，允许用参数按顺序初始化字段
        if not isPlainClass and constructor
        then
            constructor(obj, ...)
        end

        return obj
    end

    return ret
end


local function _createCloneConstructor(clzDef)
    local fieldNames = __gFieldNames[clzDef]
    local baseClz = __gParentClasses[clzDef]
    local baseCloneConstructor = baseClz and baseClz[_METHOD_NAME_CLONE]
    local cloneConstructor = clzDef[_METHOD_NAME_CLONE] or baseCloneConstructor

    -- 外部调用时，不要用第二个参数
    local ret = function(self, cloneObj)
        if not cloneObj
        then
            -- 深克隆要自己实现
            cloneObj = select(2, _newInstance(clzDef))
            if fieldNames
            then
                for _, name in ipairs(fieldNames)
                do
                    cloneObj[name] =self[name]
                end
            end
        end

        if cloneConstructor
        then
            cloneConstructor(self, cloneObj)
        end

        return cloneObj
    end

    return ret
end


local function _createDeconstructor(clzDef)
    local baseClz = __gParentClasses[clzDef]
    local baseDeconstructor = baseClz and baseClz[_METHOD_NAME_DECONSTRUCT]
    local deconstructor = clzDef[_METHOD_NAME_DECONSTRUCT] or baseDeconstructor

    local ret = function(self)
        -- 有可能没有父类而且没有明确的析构方法
        if deconstructor
        then
            deconstructor(self)
        end

        -- 在父类析构方法体中执行最后的操作
        if not baseClz
        then
            -- 销毁所有字段
            self[_METHOD_NAME_DEINIT_FIELDS](self)

            -- 销毁整个对象
            _disposeInstance(self)
        end
    end

    return ret
end



local function _createGetClassMethod(clzDef)
    local ret = function(self)
        return clzDef
    end

    return ret
end


local function __collectAutoFields(clzDef)
    local names = nil
    local decls = nil
    for name, decl in pairs(clzDef)
    do
        if types.isTable(decl) and decl[_FIELD_DECL_KEY_ID]
        then
            names = names or {}
            decls = decls or {}
            table.insert(names, name)
            table.insert(decls, decl)

            -- 清除标记
            clzDef[name] = nil
        end
    end

    -- 合并父类字体
    local parentClz = __gParentClasses[clzDef]
    local parentFieldNames = parentClz and __gFieldNames[parentClz]
    local parentFieldDecls = parentClz and __gFieldDeclarations[parentClz]
    if parentFieldNames and parentFieldDecls
    then
        names = names or {}
        decls = decls or {}
        utils.appendArray(names, parentFieldNames)
        utils.appendArray(decls, parentFieldDecls)
    end

    -- 保证初始化序列与定义顺序相同
    utils.sortParallelArrays(__compareByDeclIDAsc, decls, names)
    return names, decls
end


local function _initClassMetaData(clzDef, baseClz)
    -- 绑定父类
    __gParentClasses[clzDef] = baseClz

    -- 是否需要合成构造方法
    local isPlainClass = (not clzDef[_METHOD_NAME_CONSTRUCT])
    if baseClz
    then
        isPlainClass = isPlainClass and __gIsPlainClass[baseClz]
    end
    __gIsPlainClass[clzDef] = isPlainClass

    -- 所有声明的字段
    local names, decls = __collectAutoFields(clzDef)
    if names and decls
    then
        __gFieldNames[clzDef] = names
        __gFieldDeclarations[clzDef] = decls
    end
end


local function _createClassMetatable(clzDef)
    local metatable = {}
    metatable[_METATABLE_NAME_INDEX] = clzDef
    __gMetatables[clzDef] = metatable
end


local function declareClass(clzDef, baseClz)
    _initClassMetaData(clzDef, baseClz)

    clzDef[_METHOD_NAME_INIT_FIELDS]    = _createFieldsConstructor(clzDef)
    clzDef[_METHOD_NAME_DEINIT_FIELDS]  = _createFieldsDeconstructor(clzDef)
    clzDef[_METHOD_NAME_CONSTRUCT]      = _createConstructor(clzDef)
    clzDef[_METHOD_NAME_CLONE]          = _createCloneConstructor(clzDef)
    clzDef[_METHOD_NAME_DECONSTRUCT]    = _createDeconstructor(clzDef)
    clzDef[_METHOD_NAME_GET_CLASS]      = _createGetClassMethod(clzDef)

    utils.mergeTable(clzDef, baseClz, true)
    _createClassMetatable(clzDef)
end


return
{
    declareClass            = declareClass,
    declareConstantField    = declareConstantField,
    declareTableField       = declareTableField,
    declareClassField       = declareClassField,
}