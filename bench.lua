bit32 = bit32 or require("bit32")
local base64 = require("base64")

local llzw = require("llzw")
local lualzw = require("lualzw")
local LibCompress = require("LibCompress")

local data do
	local file = assert(io.open(assert(arg[1], "missing file name"), "r"))
	data = file:read("*a")
	file:close()
end

local function bench(which, compress, decompress, data)
	collectgarbage()
	collectgarbage()

	local compressStart = os.clock()
	local compressed, a, b, c, d = compress(data)
	local compressEnd = os.clock()

	collectgarbage()
	collectgarbage()

	local decompressStart = os.clock()
	local decompressed = decompress(compressed, a, b, c, d)
	local decompressEnd = os.clock()

	-- assert(decompressed == data, "decompressed doesn't match original")

	print(string.format(
		"%s:\n  Compress: %.2f s\n  Decompress: %.2f s\n  Ratio: %.2f (%d KiB -> %d KiB)",
		which,
		compressEnd - compressStart,
		decompressEnd - decompressStart,
		#data / #compressed, math.floor(#data / 1024), math.floor(#compressed / 1024)
	))
end

local function justIter(s)
	for i = 1, #s do
		local c = string.byte(s, i)
	end
	return s
end

local function compose2(f, g)
	return function(...)
		return f(g(...))
	end
end

local function wrapMethod(obj, name)
	return function(...)
		return obj[name](obj, ...)
	end
end

bench("iter", justIter, justIter, data)
bench("llzw", llzw.compress, llzw.decompress, data)
bench("lualzw", lualzw.compress, lualzw.decompress, data)
bench("lualzw + b64", compose2(base64.encode, lualzw.compress), compose2(lualzw.decompress, base64.decode), data)
bench("LibCompress", wrapMethod(LibCompress, "CompressLZW"), wrapMethod(LibCompress, "DecompressLZW"), data)
bench("LibCompress + b64", compose2(base64.encode, wrapMethod(LibCompress, "CompressLZW")), compose2(wrapMethod(LibCompress, "DecompressLZW"), base64.decode), data)
