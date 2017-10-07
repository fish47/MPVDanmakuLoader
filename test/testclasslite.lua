local lu        = require("lib/luaunit")
local testutils = require("common/testutils")
local types     = require("src/base/types")
local utils     = require("src/base/utils")
local classlite = require("src/base/classlite")


local function __assertIsDisposed(obj)
    lu.assertNotNil(obj)
    lu.assertTrue(types.isEmptyTable(obj))
    lu.assertNil(getmetatable(obj))
end


TestClassLite = {}

function TestClassLite:testCustomConstructor()
    local FooClass =
    {
        str = classlite.declareConstantField("abc"),

        new = function(self, val)
            self.val = val
        end
    }
    classlite.declareClass(FooClass)

    local val = { 1, 2, 3 }
    local foo = FooClass:new(val)
    lu.assertIs(foo.val, val)
    lu.assertEquals(foo.str, "abc")

    foo:dispose()
    __assertIsDisposed(foo)
end


function TestClassLite:testDisposeAutoFields()
    local fooDisposeCount = 0
    local barDisposeCount = 0

    local FooClass =
    {
        fieldA  = classlite.declareConstantField(nil),
        fieldB  = classlite.declareConstantField(1),
        fieldC  = classlite.declareTableField(),

        dispose = function(self)
            fooDisposeCount = fooDisposeCount + 1
        end
    }
    classlite.declareClass(FooClass)

    local BarClass =
    {
        fieldA  = classlite.declareClassField(FooClass),

        dispose = function(self)
            barDisposeCount = barDisposeCount + 1
        end
    }
    classlite.declareClass(BarClass)

    local bar = BarClass:new()
    local foo = bar.fieldA
    lu.assertNil(foo.fieldA)
    lu.assertEquals(foo.fieldB, 1)
    lu.assertTrue(types.isEmptyTable(foo.fieldC))

    -- 析构后会清字段
    local tableField = foo.fieldC
    table.insert(tableField, 1)
    bar:dispose()
    __assertIsDisposed(foo)
    __assertIsDisposed(bar)

    lu.assertEquals(fooDisposeCount, 1)
    lu.assertEquals(barDisposeCount, 1)
end


function TestClassLite:testInherentDispose()
    local isBaseDisposed = false
    local isChildDisposed = false
    local fieldValueA = { "1", "2", "3" }
    local fieldValueB = { "A", "B", "C" }

    local function __assertDispose(obj,
                                   assertBaseDisposed,
                                   assertChildDisposed,
                                   fieldA, fieldB)
        lu.assertEquals(isBaseDisposed, assertBaseDisposed)
        lu.assertEquals(isChildDisposed, assertChildDisposed)
        lu.assertEquals(obj.fieldA, fieldA)
        lu.assertEquals(obj.fieldB, fieldB)
    end

    local Base =
    {
        fieldA  = classlite.declareTableField(),

        dispose = function(self)
            __assertDispose(self, false, true, fieldValueA, fieldValueB)
            isBaseDisposed = true
        end,
    }
    classlite.declareClass(Base)

    local Child =
    {
        fieldB  = classlite.declareTableField(),

        dispose = function(self)
            __assertDispose(self, false, false, fieldValueA, fieldValueB)
            isChildDisposed = true
        end,
    }
    classlite.declareClass(Child, Base)

    local child = Child:new()
    utils.appendArrayElements(child.fieldA, fieldValueA)
    utils.appendArrayElements(child.fieldB, fieldValueB)
    child:dispose()
    __assertIsDisposed(child)
    lu.assertTrue(isBaseDisposed)
    lu.assertTrue(isChildDisposed)
end


function TestClassLite:testClone()
    local Triple =
    {
        a   = classlite.declareConstantField("a"),
        b   = classlite.declareTableField(),
        c   = classlite.declareConstantField("c"),
    }
    classlite.declareClass(Triple)


    local triple1 = Triple:new()
    triple1.a = "aa"
    triple1.c = "cc"
    table.insert(triple1.b, { 1, 2 })
    table.insert(triple1.b, 2)
    table.insert(triple1.b, 3)

    -- 默认是浅克隆
    local triple2 = triple1:clone()
    lu.assertEquals(triple1, triple2)
    lu.assertIs(triple1.b[1], triple2.b[1])


    local TripleEx =
    {
        clone = function(self, cloneObj)
            cloneObj = Triple.clone(self, cloneObj)
            for i, v in ipairs(self.b)
            do
                if types.isTable(v)
                then
                    local newTable = {}
                    utils.appendArrayElements(newTable, v)
                    cloneObj.b[i] = newTable
                end
            end
            return cloneObj
        end
    }
    classlite.declareClass(TripleEx, Triple)

    local tripleEx1 = TripleEx:new()
    tripleEx1.a = "aaaaa"
    tripleEx1.c = "ccccc"
    table.insert(tripleEx1.b, { 1, 2 })
    table.insert(tripleEx1.b, 2)
    table.insert(tripleEx1.b, 3)

    local function __assertIsDeepClone(tripleEx1, tripleEx2)
        lu.assertEquals(tripleEx1, tripleEx2)

        local table1 = tripleEx1.b
        local table2 = tripleEx2.b
        for i = 1, #table1
        do
            local elem1 = table1[i]
            local elem2 = table2[i]
            if types.isTable(elem1)
            then
                lu.assertNotIs(elem1, elem2)
            end
        end
    end

    local tripleEx2 = tripleEx1:clone()
    __assertIsDeepClone(tripleEx1, tripleEx2)

    -- 允许使用现有的对象复制，即使某些字段被改写过
    local tripleEx3 = TripleEx:new()
    utils.clearTable(tripleEx3)
    tripleEx2:clone(tripleEx3)
    __assertIsDeepClone(tripleEx2, tripleEx3)

    -- 禁止克隆自己
    tripleEx1:clone(tripleEx1)
    __assertIsDeepClone(tripleEx1, tripleEx2)
    __assertIsDeepClone(tripleEx1, tripleEx3)
end


function TestClassLite:testResetFields()
    local Foo =
    {
        a = classlite.declareConstantField(2),
        b = classlite.declareTableField(),
    }
    classlite.declareClass(Foo)

    local foo = Foo:new()
    foo.a = {}
    foo.b = 1
    foo:reset()
    lu.assertEquals(foo, Foo:new())

    local Bar =
    {
        a = classlite.declareClassField(Foo),
    }
    classlite.declareClass(Bar)

    local bar = Bar:new()
    bar.a.a = {}
    bar.a.b = 5
    bar:reset()
    lu.assertEquals(bar, Bar:new())
end


testutils.runTestCases()