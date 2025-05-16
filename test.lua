local llzw = require("./llzw")

local function checkIsBase64(str)
	assert(#str % 4 == 0, "base64 is not padded")
	assert(not str:match("(.-)=*$"):find("[^a-zA-Z0-9+/]"), "invalid base64")
end

local function makeString(len)
	local buf = {}

	for i = 1, len do
		buf[i] = string.char(math.random(0, 255))
	end

	return table.concat(buf)
end

for i = 0, 2500 do
	for j = 1, 10 do
		local str = makeString(i)

		local compressed = llzw.compress(str)
		checkIsBase64(compressed)
		local decompressed = llzw.decompress(compressed)
		assert(decompressed == str, "decompressed does not match original")
	end
end

print("ALL OK")
