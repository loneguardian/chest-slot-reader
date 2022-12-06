local MOD_NAME = "chest-slot-reader"
local c = {
    MOD_NAME = MOD_NAME,
    MOD_PATH = "__" .. MOD_NAME .. "__",

    CSR_NAME = MOD_NAME .. ":combinator",

    CONTAINER_TYPES = {
        ["container"] = true,
        ["logistic-container"] = true,
        ["infinity-container"] = true
    },

    UPDATE_RATE_NAME = MOD_NAME .. ":max-update-per-tick",
    UPDATE_RATE = 4
}

return c