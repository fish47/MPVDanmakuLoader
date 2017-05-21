local types = require("src/base/types")


local function __getValidatorValue(hook, input, defaultVal)
    local val = nil
    if types.isFunction(hook)
    then
        val = hook(input)
    else
        val = input
    end
    return types.chooseValue(types.isNil(val), defaultVal, val)
end

local function createSimpleValidator(inputHook, outputHook)
    local ret = function(input, defaultVal)
        local val = __getValidatorValue(inputHook, input, defaultVal)
        return __getValidatorValue(outputHook, val)
    end
    return ret;
end

local function createIntValidator(inputHook, outputHook, minVal, maxVal)
    local ret = function(input, defaultVal)
        local val = __getValidatorValue(inputHook, input, defaultVal)
        val = val and minVal and math.max(val, minVal) or val
        val = val and maxVal and math.min(val, maxVal) or val
        return __getValidatorValue(outputHook, val)
    end
    return ret
end


return
{
    createSimpleValidator   = createSimpleValidator,
    createIntValidator      = createIntValidator,
}