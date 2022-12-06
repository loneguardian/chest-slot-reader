local c = require("constants")

local csr = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
csr.name = c.CSR_NAME
csr.item_slot_count = 2
csr.allow_copy_paste = false
csr.minable.result = c.CSR_NAME

local csr_item = table.deepcopy(data.raw["item"]["constant-combinator"])
csr_item.name = csr.name
csr_item.place_result = csr.name
csr_item.subgroup = "circuit-network"
csr_item.order = "c[combinators]-m[chest-slot-reader]"

local csr_recipe = table.deepcopy(data.raw["recipe"]["constant-combinator"])
csr_recipe.name = csr.name
csr_recipe.result = csr.name
table.insert(data.raw["technology"]["circuit-network"].effects, {type = "unlock-recipe", recipe = csr.name})

data:extend{
    csr,
    csr_item,
    csr_recipe
}