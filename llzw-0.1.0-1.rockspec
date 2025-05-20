package = "llzw"
version = "0.1.0-1"
source = {
	url = "git://github.com/RiskoZoSlovenska/llzw",
	tag = "v0.1.0",
}
description = {
	summary = "Fast LZW + base64 in pure Lua ",
	detailed = "llzw is a simple, small, relatively fast pure-Lua library that does LZW compression/decompression and base64 encode/decode in one step.",
	homepage = "https://github.com/RiskoZoSlovenska/llzw",
	license = "MIT",
}
dependencies = {
	"lua >= 5.1",
}
build = {
	type = "builtin",
	modules = {
		llzw = "llzw.lua",
	},
}
