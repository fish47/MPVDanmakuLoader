local lu = require('3rdparties/luaunit')    --= lu luaunit
local base = require('src/base')            --= base base
local encoding = require('src/encoding')    --= encoding encoding

local __UTF8_TEST_CASES =
{
    {238,159,143}, {59343},
    {230,155,162}, {26338},
    {236,180,151}, {52503},
    {225,168,133}, {6661},
    {237,174,169}, {56233},
    {226,146,175}, {9391},
    {230,167,173}, {27117},
    {225,161,161}, {6241},
    {232,174,134}, {35718},
    {229,159,129}, {22465},
    {224,168,190}, {2622},
    {239,169,154}, {64090},
    {235,155,153}, {46809},
    {226,156,173}, {10029},
    {229,175,157}, {23517},
    {237,161,174}, {55406},
    {230,136,159}, {25119},
    {234,156,141}, {42765},
    {229,155,146}, {22226},
    {238,166,183}, {59831},
    {227,189,134}, {16198},
    {233,154,178}, {38578},
    {226,159,169}, {10217},
    {228,156,163}, {18211},
    {225,160,182}, {6198},
    {231,129,185}, {28793},
    {228,175,169}, {19433},
    {240,147,161,182}, {79990},
    {240,146,129,152}, {73816},
    {240,159,174,139}, {129931},
    {240,152,173,145}, {101201},
    {240,145,166,183}, {72119},
    {240,144,183,149}, {69077},
    {240,149,166,132}, {88452},
    {240,147,186,135}, {81543},
    {240,148,189,131}, {85827},
    {240,155,172,183}, {113463},
    {240,149,179,137}, {89289},
    {240,158,134,131}, {123267},
    {240,159,178,163}, {130211},
    {240,153,156,155}, {104219},
    {240,152,165,139}, {100683},
    {240,157,142,166}, {119718},
    {240,147,173,132}, {80708},
    {240,159,142,175}, {127919},
    {240,145,128,147}, {69651},
    {240,153,166,156}, {104860},
    {240,145,145,140}, {70732},
    {240,150,190,163}, {94115},
    {240,158,149,186}, {124282},
    {240,155,133,174}, {110958},
    {240,149,176,171}, {89131},
    {240,154,188,188}, {110396},
    {240,155,179,187}, {113915},
    {240,157,166,162}, {121250},
    {240,154,139,168}, {107240},
    {240,145,186,128}, {73344},
    {240,151,146,149}, {95381},
    {240,152,190,154}, {102298},
    {240,150,164,138}, {92426},
    {240,158,178,187}, {126139},
    {240,146,179,184}, {77048},
    {240,154,147,139}, {107723},
    {233,130,151,234,156,129}, {37015,42753},
    {199,170,240,159,157,154}, {490,128858},
    {230,153,151,238,158,185}, {26199,59321},
    {238,167,144,228,135,185}, {59856,16889},
    {227,155,173,225,150,157}, {14061,5533},
    {226,142,147,224,182,187}, {9107,3515},
    {229,159,133,236,158,147}, {22469,51091},
    {206,167,240,157,158,189}, {935,120765},
    {239,152,177,236,164,154}, {63025,51482},
    {227,134,151,230,132,134}, {12695,24838},
    {232,163,182,232,165,191}, {35062,35199},
    {236,132,172,237,163,141}, {49452,55501},
    {240,153,135,179,227,188,164}, {102899,16164},
    {234,145,143,240,148,140,187}, {42063,82747},
    {240,153,154,181,225,184,149}, {104117,7701},
    {232,164,145,240,147,151,167}, {35089,79335},
    {229,146,165,240,153,137,143}, {21669,102991},
    {225,136,156,240,157,191,141}, {4636,122829},
    {240,155,181,140,232,145,151}, {113996,33879},
    {233,136,151,240,150,167,150}, {37399,92630},
    {232,146,180,240,158,138,157}, {33972,123549},
    {237,172,175,240,147,176,151}, {56111,80919},
    {240,151,185,136,232,136,140}, {97864,33292},
    {240,154,167,147,239,163,145}, {109011,63697},
    {240,145,181,139,227,169,166}, {73035,14950},
    {236,142,133,240,152,149,143}, {50053,99663},
    {240,152,148,169,229,141,187}, {99625,21371},
    {238,175,155,240,144,179,168}, {60379,68840},
    {236,177,138,240,153,171,136}, {52298,105160},
    {240,148,128,167,229,188,138}, {81959,24330},
    {225,155,171,240,154,135,178}, {5867,106994},
    {240,152,177,150,233,162,173}, {101462,39085},
    {240,149,190,160,240,158,171,161}, {90016,125665},
    {240,154,172,149,240,147,151,186}, {109333,79354},
    {240,154,168,140,240,158,155,188}, {109068,124668},
    {240,153,183,132,240,158,164,183}, {105924,125239},
    {240,152,130,178,240,146,151,138}, {98482,75210},
    {240,155,130,167,240,157,132,152}, {110759,119064},
    {240,146,179,182,240,149,166,171}, {77046,88491},
    {240,148,138,162,240,159,184,148}, {82594,130580},
    {235,132,166,228,185,157,238,143,156}, {45350,20061,58332},
    {225,156,139,239,190,139,226,179,172}, {5899,65419,11500},
    {224,187,144,228,188,159,230,164,169}, {3792,20255,26921},
    {208,130,236,179,179,240,159,180,185}, {1026,52467,130361},
    {225,171,130,240,154,178,136,217,167}, {6850,109704,1639},
    {196,151,240,144,166,171,226,149,171}, {279,68011,9579},
    {240,148,150,151,209,175,235,153,186}, {83351,1135,46714},
    {229,168,169,228,174,176,229,130,174}, {23081,19376,20654},
    {234,167,144,240,150,190,158,239,189,143}, {43472,94110,65359},
    {234,174,132,240,158,184,173,238,146,171}, {43908,126509,58539},
    {240,148,173,174,235,184,168,227,149,188}, {84846,48680,13692},
    {233,134,154,240,147,137,162,228,180,154}, {37274,78434,19738},
    {233,175,128,237,135,164,240,145,144,179}, {39872,53732,70707},
    {231,188,141,240,149,138,183,225,181,149}, {32525,86711,7509},
    {240,159,156,179,239,162,132,238,158,141}, {128819,63620,59277},
    {229,131,162,237,182,130,240,149,190,173}, {20706,56706,90029},
    {240,159,187,153,234,174,133,233,174,168}, {130777,43909,39848},
    {240,148,187,178,232,183,131,235,128,159}, {85746,36291,45087},
    {237,167,177,240,150,159,133,239,184,184}, {55793,92101,65080},
    {239,174,178,240,144,176,162,231,182,143}, {64434,68642,32143},
    {240,146,128,159,230,129,133,231,169,168}, {73759,24645,31336},
    {229,147,164,233,153,143,240,148,160,130}, {21732,38479,83970},
    {234,177,178,240,145,173,184,225,148,178}, {44146,72568,5426},
    {228,160,167,240,149,134,170,240,144,171,174}, {18471,86442,68334},
    {240,150,186,164,240,159,182,131,235,182,144}, {93860,130435,48528},
    {240,159,156,131,237,173,165,240,153,165,188}, {128771,56165,104828},
    {206,190,240,147,191,143,233,188,177,223,179}, {958,81871,40753,2035},
    {240,155,181,178,225,178,152,240,147,129,144}, {114034,7320,77904},
    {240,146,167,170,239,149,154,240,158,150,155}, {76266,62810,124315},
    {225,169,135,240,151,186,154,240,149,149,182}, {6727,97946,87414},
    {240,145,130,173,240,157,162,163,224,176,162}, {69805,120995,3106},
    {240,146,175,161,227,178,159,240,148,129,159}, {76769,15519,82015},
    {240,158,142,167,240,157,143,147,226,137,176}, {123815,119763,8816},
    {240,144,148,155,226,136,132,240,158,190,175}, {66843,8708,126895},
    {240,155,182,191,238,128,189,240,148,187,132}, {114111,57405,85700},
    {240,151,131,145,238,153,181,240,156,142,147}, {94417,58997,115603},
    {240,158,155,180,225,190,133,240,150,172,162}, {124660,8069,92962},
    {240,146,174,156,240,158,147,188,225,155,151}, {76700,124156,5847},
    {232,155,146,240,158,172,146,240,144,182,170}, {34514,125714,69034},
    {240,157,156,131,239,188,145,240,151,155,137}, {120579,65297,95945},
    {240,145,172,152,236,166,137,240,149,153,140}, {72472,51593,87628},
    {240,159,145,190,240,144,150,165,240,152,175,148}, {128126,66981,101332},
    {240,157,163,139,240,145,139,155,240,147,131,162}, {121035,70363,78050},
    {240,147,134,134,240,153,138,129,240,145,188,137}, {78214,103041,73481},
    {240,155,146,141,240,152,150,150,240,159,188,132}, {111757,99734,130820},
    {233,139,178,236,180,132,225,179,129,234,128,161}, {37618,52484,7361,40993},
    {240,145,137,150,240,151,170,163,240,145,171,165}, {70230,96931,72421},
    {240,146,177,150,240,149,168,144,240,150,163,179}, {76886,88592,92403},
    {232,169,148,229,134,149,229,188,138,235,137,137}, {35412,20885,24330,45641},
    {240,152,142,150,240,152,132,136,240,150,187,184}, {99222,98568,93944},
    {228,148,135,231,158,173,240,159,190,154,211,189}, {17671,30637,130970,1277},
    {240,148,166,157,240,147,163,130,240,144,190,186}, {84381,80066,69562},
    {226,159,154,239,165,139,231,191,166,235,190,145}, {10202,63819,32742,49041},
    {240,155,155,154,224,170,149,218,132,225,138,170}, {112346,2709,1668,4778},
    {240,150,138,141,240,149,171,164,240,158,153,177}, {90765,88804,124529},
    {240,149,141,151,230,163,161,234,190,173,227,170,133}, {86871,26849,44973,14981},
    {228,172,128,239,175,159,231,161,168,240,156,144,167}, {19200,64479,30824,115751},
    {236,139,131,240,147,154,154,232,163,177,235,130,137}, {49859,79514,35057,45193},
    {233,161,135,231,161,137,232,168,155,240,156,177,183}, {38983,30793,35355,117879},
    {240,159,146,180,225,184,138,224,172,144,227,150,181}, {128180,7690,2832,13749},
    {235,163,161,239,190,174,226,185,175,240,148,169,148}, {47329,65454,11887,84564},
    {229,157,169,240,154,166,183,225,129,183,225,178,159}, {22377,108983,4215,7327},
    {227,155,163,234,150,136,228,164,161,240,144,143,159}, {14051,42376,18721,66527},
    {233,132,173,239,145,156,226,167,129,240,156,191,178}, {37165,62556,10689,118770},
    {227,173,169,231,175,163,240,154,159,155,225,140,145}, {15209,31715,108507,4881},
    {238,177,187,240,156,147,180,233,170,183,239,133,187}, {60539,115956,39607,61819},
    {235,175,130,240,146,138,183,237,169,142,230,160,175}, {48066,74423,55886,26671},
    {232,128,157,232,136,128,240,159,172,157,232,168,156}, {32797,33280,129821,35356},
    {224,183,164,240,150,134,139,230,138,157,238,170,164}, {3556,90507,25245,60068},
    {240,157,142,160,238,177,152,240,150,187,132,227,181,139}, {119712,60504,93892,15691},
    {231,148,185,232,172,182,240,159,165,139,240,148,181,184}, {30009,35638,129355,85368},
    {240,155,143,146,225,156,135,238,133,142,240,155,130,153}, {111570,5895,57678,110745},
    {240,154,169,185,227,183,129,240,148,158,163,236,174,152}, {109177,15809,83875,52120},
    {232,166,174,240,151,136,183,240,156,161,138,238,129,140}, {35246,94775,116810,57420},
    {240,149,182,181,240,145,179,130,224,161,188,238,174,172}, {89525,72898,2172,60332},
    {225,182,146,240,158,172,162,240,156,163,156,234,178,139}, {7570,125730,116956,44171},
    {240,147,142,171,234,174,128,233,179,190,240,147,140,188}, {78763,43904,40190,78652},
    {240,144,186,168,240,154,138,178,233,169,191,229,189,173}, {69288,107186,39551,24429},
    {240,145,145,133,240,148,183,132,234,166,147,227,162,140}, {70725,85444,43411,14476},
    {240,159,189,163,240,159,179,164,224,164,191,225,191,153}, {130915,130276,2367,8153},
    {240,145,150,171,237,178,128,240,159,147,181,235,147,187}, {71083,56448,128245,46331},
    {226,138,132,237,190,184,240,158,178,154,240,150,180,175}, {8836,57272,126106,93487},
    {240,149,177,152,233,140,162,239,191,162,240,144,174,166}, {89176,37666,65506,68518},
    {240,154,164,150,240,150,178,155,240,153,160,181,232,139,165}, {108822,93339,104501,33509},
    {240,155,157,145,237,143,191,240,145,154,168,240,159,184,153}, {112465,54271,71336,130585},
    {235,172,143,240,145,167,153,240,151,151,170,240,159,133,182}, {47887,72153,95722,127350},
    {232,132,137,240,159,180,139,240,146,157,189,240,154,156,137}, {33033,130315,75645,108297},
    {240,147,181,153,240,155,176,150,240,148,166,142,226,158,189}, {81241,113686,84366,10173},
    {240,150,190,178,240,149,135,138,239,179,180,240,148,145,150}, {94130,86474,64756,83030},
    {228,151,143,240,152,148,163,240,151,147,139,240,153,151,187}, {17871,99619,95435,103931},
    {225,131,132,240,158,137,160,240,149,149,136,240,144,179,172}, {4292,123488,87368,68844},
    {238,181,138,240,158,137,148,240,151,191,143,240,159,138,134}, {60746,123476,98255,127622},
    {240,159,136,171,240,156,191,183,240,146,167,183,224,161,158}, {127531,118775,76279,2142},
    {240,159,186,133,240,148,155,176,229,177,171,240,157,155,166}, {130693,83696,23659,120550},
    {240,155,179,173,240,146,172,135,240,144,141,132,240,153,128,156}, {113901,76551,66372,102428},
    {240,146,176,169,240,147,162,171,240,146,185,188,240,146,146,154}, {76841,80043,77436,74906},
    {240,145,185,188,240,158,186,139,240,144,146,179,240,150,156,141}, {73340,126603,66739,91917},
}


TestIterateUTF8CodePoints =
{
    test_decode = function()
        for _, stringBytes, codePoints in base.iteratePairsArray(__UTF8_TEST_CASES)
        do
            local iterCount = 0
            local str = string.char(table.unpack(stringBytes))
            for _, codePoint in encoding.iterateUTF8CodePoints(str)
            do
                iterCount = iterCount + 1
                lu.assertEquals(codePoint, codePoints[iterCount])
            end

            lu.assertEquals(iterCount, #codePoints)
        end
    end,


    test_encode = function()
        local encodedBytes = {}
        for _, stringBytes, codePoints in base.iteratePairsArray(__UTF8_TEST_CASES)
        do
            local byteIdx = 1
            for _, codePoint in ipairs(codePoints)
            do
                byteIdx = byteIdx + encoding.getUTF8Bytes(codePoint, encodedBytes)
            end

            lu.assertEquals(encodedBytes, stringBytes)
            base.clearTable(encodedBytes)
        end
    end,
}

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())