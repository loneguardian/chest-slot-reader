local c = require("constants")

data:extend{
	{
		type = "int-setting",
		name = c.UPDATE_RATE_NAME,
		setting_type = "runtime-global",
		default_value = c.UPDATE_RATE,
		minimum_value = 1
	}
}