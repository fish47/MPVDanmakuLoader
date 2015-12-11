local lu        = require("3rdparties/luaunit")    --= luaunit lu
local types     = require("src/base/types")
local classlite = require("src/base/classlite")


TestClassLite =
{
    __assertIsDisposed = function(self, obj)
        lu.assertNotNil(obj)
        lu.assertTrue(types.isEmptyTable(obj))
        lu.assertNil(getmetatable(obj))
    end,


    test_custom_constructor = function(self)
        local FooClass =
        {
            str = classlite.declareConstantField("abc"),

            new = function(self, val)
                self.val = val
            end,
        }
        classlite.declareClass(FooClass)

        local val = { 1, 2, 3 }
        local foo = FooClass:new(val)
        lu.assertIs(foo.val, val)
        lu.assertEquals(foo.str, "abc")

        foo:dispose()
        self:__assertIsDisposed(foo)
    end,


    test_plain_class_constructor = function(self)
        local Base =
        {
            a   = classlite.declareConstantField(1),
            b   = classlite.declareConstantField(2),
        }
        classlite.declareClass(Base)

        local Derived =
        {
            c   = classlite.declareConstantField(3)
        }
        classlite.declareClass(Derived, Base)

        local derived = Derived:new("a", "b", "c")
        lu.assertEquals(derived.a, "a")
        lu.assertEquals(derived.b, "b")
        lu.assertEquals(derived.c, "c")
    end,


    test_auto_class_field = function(self)
        local Triple =
        {
            a   = classlite.declareConstantField(true),
            b   = classlite.declareConstantField(true),
            c   = classlite.declareConstantField(true),
        }
        classlite.declareClass(Triple)

        local Foo =
        {
            triple = classlite.declareClassField(Triple, 1, 2, 3),
        }
        classlite.declareClass(Foo)

        local foo = Foo:new()
        lu.assertNotNil(foo.triple)
        lu.assertEquals(foo.triple.a, 1)
        lu.assertEquals(foo.triple.b, 2)
        lu.assertEquals(foo.triple.c, 3)

        foo:dispose()
        self:__assertIsDisposed(foo)
    end,


    test_dipose_auto_fields = function(self)
        local fooDisposeCount = 0
        local barDisposeCount = 0

        local FooClass =
        {
            fieldA  = classlite.declareConstantField(nil),
            fieldB  = classlite.declareConstantField(1),
            fieldC  = classlite.declareTableField(),

            dispose = function(self)
                fooDisposeCount = fooDisposeCount + 1
            end,
        }
        classlite.declareClass(FooClass)

        local BarClass =
        {
            fieldA  = classlite.declareClassField(FooClass),

            dispose = function(self)
                barDisposeCount = barDisposeCount + 1
            end,
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
        self:__assertIsDisposed(foo)
        self:__assertIsDisposed(bar)

        lu.assertEquals(fooDisposeCount, 1)
        lu.assertEquals(barDisposeCount, 1)
    end,


    test_clone = function(self)
        local Triple =
        {
            a   = classlite.declareConstantField("a"),
            b   = classlite.declareTableField(),
            c   = classlite.declareConstantField("c"),
        }
        classlite.declareClass(Triple)

        -- 默认是浅克隆
        local triple1 = Triple:new()
        local triple2 = triple1:clone()
        lu.assertEquals(triple1, triple2)
        lu.assertIs(triple1.b, triple2.b)


        local TripleEx =
        {
            clone = function(self, cloneObj)
                cloneObj = Triple.clone(self, cloneObj)
                cloneObj.b = {}
                for k, v in pairs(self.b)
                do
                    cloneObj.b[k] = v
                end
                return cloneObj
            end,
        }
        classlite.declareClass(TripleEx, Triple)

        local tripleEx1 = TripleEx:new()
        table.insert(tripleEx1.b, 1)
        table.insert(tripleEx1.b, 2)
        table.insert(tripleEx1.b, 3)

        local tripleEx2 = tripleEx1:clone()
        lu.assertEquals(tripleEx1, tripleEx2)
        lu.assertNotIs(tripleEx1.b, tripleEx2.b)
    end,
}


lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())