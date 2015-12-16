local types     = require("src/base/types")


local function __createAssertFunction(hook, isNilable)
    local ret = function(arg)
        if arg == nil and isNilable
        then
            --TODO
        elseif not hook(arg)
        then
            --TODO
        end
        return arg
    end

    return ret
end


return
{
    assertIsString          = __createAssertFunction(types.isString),
    assertIsNilOrString     = __createAssertFunction(types.isString, true),
    assertIsNumber          = __createAssertFunction(types.isNumber),
    assertIsBoolean         = __createAssertFunction(types.isBoolean),
    assertIsEmptyTable      = __createAssertFunction(types.isEmptyTable),

    assertTrue      = function(val)
        if not val
        then
            --TODO
        end
    end,

    assertEquals    = function(val1, val2)
        if val1 ~= val2
        then
            --TODO
        end
    end,
}