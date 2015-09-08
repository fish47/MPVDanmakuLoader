local utils = require("src/utils")
return utils.exportModules(
    require("src/_shell/_base"),
    require("src/_shell/logic"),
    require("src/_shell/model"),
    require("src/_shell/uistrings")
)