local types     = require("src/base/types")
local utils     = require("src/base/utils")
local constants = require("src/base/constants")


local _METATABLE_NAME_INDEX             = "__index"

local _METHOD_NAME_CONSTRUCT            = "new"
local _METHOD_NAME_DECONSTRUCT          = "dispose"
local _METHOD_NAME_CLONE                = "clone"
local _METHOD_NAME_RESET                = "reset"
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

local _CLASS_INHERIT_LEVEL_START        = 1


local __gMetatables             = {}
local __gParentClasses          = {}
local __gClassInheritLevels     = {}
local __gFieldNames             = {}
local __gFieldDeclarations      = {}
local __gFieldDeclartionID      = 0


local function __invokeInstanceMethod(obj, methodName, ...)
    return utils.invokeSafely(obj[methodName], obj, ...)
end


local function isInstanceOf(obj, clz)
    -- 空指针总会返回 false
    if not types.isTable(obj) or not types.isTable(clz)
    then
        return false
    end

    local objClz = __invokeInstanceMethod(obj, _METHOD_NAME_GET_CLASS)
    if not objClz
    then
        return false
    end

    local objLv = __gClassInheritLevels[objClz]
    local clzLv = __gClassInheritLevels[clz]
    if not objLv or not clzLv
    then
        return false
    end

    local function __traceBackToSameLevel(parentMap, clz1, level1, clz2, level2)
        if level1 > level2
        then
            return __traceBackToSameLevel(parentMap, clz2, level2, clz1, level1)
        end

        while level2 ~= level1
        do
            level2 = level2 - 1
            clz2 = parentMap[clz2]
        end
        return clz1, clz2
    end

    local clz1, clz2 = __traceBackToSameLevel(__gParentClasses, objClz, objLv, clz, clzLv)
    while clz1 and clz2
    do
        if clz1 == clz2
        then
            return true
        end

        clz1 = __gParentClasses[clz1]
        clz2 = __gParentClasses[clz2]
    end
    return false
end


local function __constructConstantField(obj, name, decl)
    local field = decl[_FIELD_DECL_KEY_FIRST_ARG]
    obj[name] = field
    return field
end

local function __constructTableField(obj, name, decl)
    local field = {}
    obj[name] = field
    return field
end

local function __constructClassField(obj, name, decl)
    local classType = decl[_FIELD_DECL_KEY_FIRST_ARG]
    local constructor = classType[_METHOD_NAME_CONSTRUCT]
    local field = constructor(classType,
                              select(_FIELD_DECL_KEY_CLASS_ARGS_START,
                                     utils.unpackArray(decl)))
    obj[name] = field
    return field
end


local _FUNCS_CONSTRUCT =
{
    [_FIELD_DECL_TYPE_CONSTANT] = __constructConstantField,
    [_FIELD_DECL_TYPE_TABLE]    = __constructTableField,
    [_FIELD_DECL_TYPE_CLASS]    = __constructClassField,
}


local _FUNCS_DECONSTRUCT =
{
    [_FIELD_DECL_TYPE_CONSTANT] = function(obj, name, decl)
        obj[name] = nil
    end,

    [_FIELD_DECL_TYPE_TABLE]    = function(obj, name, decl)
        utils.clearTable(obj[name])
        obj[name] = nil
    end,

    [_FIELD_DECL_TYPE_CLASS]    = function(obj, name, decl)
        utils.disposeSafely(obj[name])
        obj[name] = nil
    end,
}


local _FUNCS_CLONE =
{
    [_FIELD_DECL_TYPE_CONSTANT] = function(obj, name, decl, arg)
        obj[name] = arg
    end,

    [_FIELD_DECL_TYPE_TABLE]    = function(obj, name, decl, arg)
        local field = utils.clearTable(obj[name])
        if not field
        then
            field = {}
            obj[name] = field
        end
        utils.appendArrayElements(field, arg)
    end,

    [_FIELD_DECL_TYPE_CLASS]    = function(obj, name, decl, arg)
        local field = obj[name]
        if not field
        then
            field = __constructClassField(obj, name, decl)
        end
        if isInstanceOf(arg, __invokeInstanceMethod(field, _METHOD_NAME_GET_CLASS))
        then
            __invokeInstanceMethod(arg, _METHOD_NAME_CLONE, field)
        end
    end,
}


local _FUNCS_RESET =
{
    [_FIELD_DECL_TYPE_CONSTANT] = __constructConstantField,

    [_FIELD_DECL_TYPE_TABLE]    = function(obj, name, decl)
        local field = obj[name]
        if types.isTable(field)
        then
            utils.clearTable(field)
        else
            __constructTableField(obj, name, decl)
        end
    end,

    [_FIELD_DECL_TYPE_CLASS]    = function(obj, name, decl)
        local field = obj[name]
        local fieldClz = __invokeInstanceMethod(field, _METHOD_NAME_GET_CLASS)
        if isInstanceOf(field, fieldClz)
        then
            __invokeInstanceMethod(field, _METHOD_NAME_RESET)
        else
            __constructClassField(obj, name, decl)
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
    if types.isTable(mt)
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


local function __createFielesFunction(names, decls, functionMap)
    if not names or not decls
    then
        return nil
    end

    local ret = function(self, ...)
        for i, name in ipairs(names)
        do
            local decl = decls[i]
            local declType = decl[_FIELD_DECL_KEY_TYPE]
            functionMap[declType](self, name, decl)
        end
    end

    return ret
end


local function _createFieldsConstructor(clzDef)
    local names = __gFieldNames[clzDef]
    local decls = __gFieldDeclarations[clzDef]
    if names and decls
    then
        return __createFielesFunction(names, decls, _FUNCS_CONSTRUCT)
    else
        return constants.FUNC_EMPTY
    end
end


local function _createFieldsDeconstructor(clzDef)
    local names = __gFieldNames[clzDef]
    local decls = __gFieldDeclarations[clzDef]
    if names and decls
    then
        return __createFielesFunction(names, decls, _FUNCS_DECONSTRUCT)
    else
        return constants.FUNC_EMPTY
    end
end


local function _createConstructor(clzDef, names, decls)
    local baseClz = __gParentClasses[clzDef]
    local baseConstructor = baseClz and baseClz[_METHOD_NAME_CONSTRUCT]
    local constructor = clzDef[_METHOD_NAME_CONSTRUCT] or baseConstructor

    local ret = function(self, ...)
        local isNewlyAllocated, obj = _newInstance(self)

        -- 在执行构造方法前，将继承链上所有声明的字段都初始化，只执行一次
        if isNewlyAllocated
        then
            __invokeInstanceMethod(obj, _METHOD_NAME_INIT_FIELDS, ...)
        end

        if constructor
        then
            constructor(obj, ...)
        end

        return obj
    end

    return ret
end


local function _createCloneConstructor(clzDef)
    local fieldNames = __gFieldNames[clzDef]
    local fieldDecls = __gFieldDeclarations[clzDef]
    local baseClz = __gParentClasses[clzDef]
    local baseCloneConstructor = baseClz and baseClz[_METHOD_NAME_CLONE]
    local cloneConstructor = clzDef[_METHOD_NAME_CLONE] or baseCloneConstructor

    local ret = function(self, cloneObj)
        if self == cloneObj
        then
            return self
        end

        local shouldCloneFields = false
        if not cloneObj
        then
            local _, newObj = _newInstance(clzDef)
            cloneObj = newObj
            shouldCloneFields = true
        elseif __invokeInstanceMethod(cloneObj, _METHOD_NAME_GET_CLASS) == clzDef
        then
            shouldCloneFields = true
        end

        -- 深克隆要自己实现
        if shouldCloneFields and fieldNames
        then
            for i = 1, #fieldNames
            do
                local fieldName = fieldNames[i]
                local fieldDecl = fieldDecls[i]
                local declType = fieldDecl[_FIELD_DECL_KEY_TYPE]
                local func = _FUNCS_CLONE[declType]
                if func
                then
                    func(cloneObj, fieldName, fieldDecl, self[fieldName])
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
    local childDeconstructor = clzDef[_METHOD_NAME_DECONSTRUCT]

    local ret = function(self)
        -- 析构当前类
        if childDeconstructor
        then
            childDeconstructor(self)
        end

        -- 析构上一级父类
        if baseDeconstructor
        then
            baseDeconstructor(self)
        end

        -- 在最顶层父类析构方法体中执行最后的操作
        if not baseClz
        then
            -- 析构所有字段
            __invokeInstanceMethod(self, _METHOD_NAME_DEINIT_FIELDS)

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


local function _createFieldsResetMethod(clzDef)
    local names = __gFieldNames[clzDef]
    local decls = __gFieldDeclarations[clzDef]
    if names and decls
    then
        return __createFielesFunction(names, decls, _FUNCS_RESET)
    else
        return constants.FUNC_EMPTY
    end
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

        -- 注意被覆盖的父类字段
        for i, parentFieldName in ipairs(parentFieldNames)
        do
            if not utils.linearSearchArray(names, parentFieldName)
            then
                table.insert(names, parentFieldName)
                table.insert(decls, parentFieldDecls[i])
            end
        end
    end

    -- 保证初始化序列与定义顺序相同
    local function __cmp(decl1, decl2)
        return (decl1[_FIELD_DECL_KEY_ID] < decl2[_FIELD_DECL_KEY_ID])
    end
    utils.sortParallelArrays(__cmp, decls, names)
    return names, decls
end


local function _initClassMetaData(clzDef, baseClz)
    -- 绑定父类
    __gParentClasses[clzDef] = baseClz

    -- 继承深度
    local parentLevel = baseClz and __gClassInheritLevels[baseClz] or _CLASS_INHERIT_LEVEL_START
    __gClassInheritLevels[clzDef] = 1 + parentLevel

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
    clzDef[_METHOD_NAME_RESET]          = _createFieldsResetMethod(clzDef)
    clzDef[_METHOD_NAME_DECONSTRUCT]    = _createDeconstructor(clzDef)
    clzDef[_METHOD_NAME_GET_CLASS]      = _createGetClassMethod(clzDef)

    utils.mergeTable(clzDef, baseClz, true)
    _createClassMetatable(clzDef)
end


return
{
    declareClass                = declareClass,
    declareConstantField        = declareConstantField,
    declareTableField           = declareTableField,
    declareClassField           = declareClassField,
    isInstanceOf                = isInstanceOf,
}
