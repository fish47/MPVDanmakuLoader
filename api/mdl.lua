
local _DUMMY_FUNCTION_DECLARTION    = { type = "function" }
local _DUMMY_FIELD_DECLARTION       = { type = "value" }
local _DUMMY_METHOD_DECLARTION      = { type = "method" }

local function _declareField(fieldType)
    return { type = "value", valuetype = fieldType }
end

local function _declareMethod(returnType)
    return { type = "method", returns = returnType }
end

local function _declareFunction(returnType)
    return { type = "function", returns = returnType }
end


return
{
    file =
    {
        type = "class",
        inherits = "f",
        childs = {},
    },

    base =
    {
        type = "lib",
        childs =
        {
            allocateInstance            = _DUMMY_FUNCTION_DECLARTION,
            declareClass                = _DUMMY_FUNCTION_DECLARTION,
            iteratePairsArray           = _DUMMY_FUNCTION_DECLARTION,
            findIf                      = _DUMMY_FUNCTION_DECLARTION,
            binarySearchList            = _DUMMY_FUNCTION_DECLARTION,
            isTable                     = _DUMMY_FUNCTION_DECLARTION,
            clearTable                  = _DUMMY_FUNCTION_DECLARTION,
        },
    },

    poscalc =
    {
        type = "lib",
        childs =
        {
            _BasePosCalculator =
            {
                type = "class",
                childs =
                {
                    new             = _declareMethod("poscalc._BasePosCalculator"),
                    dispose         = _DUMMY_METHOD_DECLARTION,
                    calculate       = _DUMMY_METHOD_DECLARTION,
                }
            },

            L2RPosCalculator =
            {
                type = "class",
                inherits = "poscalc._BasePosCalculator",
                childs = {}
            },

            R2LPosCalculaotr =
            {
                type = "class",
                inherits = "poscalc._BasePosCalculator",
                childs = {},
            },

            T2BPosCalculator =
            {
                type = "class",
                inherits = "poscalc._BasePosCalculator",
                childs = {},
            },

            B2TPosCalcluator =
            {
                type = "class",
                inherits = "poscalc._BasePosCalculator",
                childs = {},
            },
        },
    },


    json =
    {
        type = "lib",
        childs =
        {
            JSONParseContext =
            {
                type = "class",
                childs =
                {
                    content = _declareField("string"),
                    readIndex = _declareField("number"),
                    collectionStack = _DUMMY_FIELD_DECLARTION,
                },
            },
        },
    },
}