local bit32 = bit32 or require("bit32")

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PADDING = "="
local PADDING_BYTE = string.byte(PADDING)

-- Lookup tables
local lookupB64Char = {}
local lookupB64Code = {}

for i = 1, 64 do
	local c = string.sub(ALPHABET, i, i)

	lookupB64Char[i - 1] = c
	lookupB64Code[string.byte(c)] = i - 1
end

-- Initial dictionary
local initialDictionarySize = 256
local initialDictionary = {}

for i = 0, initialDictionarySize - 1 do
	local char = string.char(i)
	initialDictionary[char] = i
	initialDictionary[i] = char
end


local function table_copy(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = v
	end
	return out
end


--[[
	Compress and base64-encode the given string of arbitrary binary data. The
	returned string is guaranteed to be valid, padded base64.
]]
local function compress(data)
	assert(type(data) == "string", "bad argument #1 to 'compress' (string expected, got " .. type(data) .. ")")
	if data == "" then
		return ""
	end

	local dictionary = table_copy(initialDictionary)
	local nextEntry = initialDictionarySize

	local key = "" -- Input buffer of sorts

	local curWidth = math.floor(math.log(nextEntry, 2)) + 1
	local nextWidthChangeAt = 2^curWidth

	local outBuffer, outBufferLen = 0, 0
	local outArr, outArrNext = {}, 1

	for i = 1, #data do
		local c = string.sub(data, i, i)
		local newKey = key .. c

		if dictionary[newKey] then
			key = newKey
			goto continue -- newKey isn't the longest in the dictionary yet; keep searching
		end

		-- Emit key code
		local code = dictionary[key]
		outBuffer = bit32.lshift(outBuffer, curWidth) + code
		outBufferLen = outBufferLen + curWidth
		key = c -- We emitted key, so key (newKey) becomes just c

		-- Write from out buffer
		while outBufferLen >= 6 do
			local b64Code = bit32.extract(outBuffer, outBufferLen - 6, 6)
			outBufferLen = outBufferLen - 6

			outArr[outArrNext] = lookupB64Char[b64Code]
			outArrNext = outArrNext + 1
		end

		-- Put new key into the dictionary, changing width if necessary
		dictionary[newKey] = nextEntry
		nextEntry = nextEntry + 1
		if nextEntry >= nextWidthChangeAt then
			nextWidthChangeAt = nextWidthChangeAt * 2
			curWidth = curWidth + 1
		end

		::continue::
	end

	-- Emit code for the remainder (guaranteed to exist)
	local code = dictionary[key]
	outBuffer = bit32.lshift(outBuffer, curWidth) + code
	outBufferLen = outBufferLen + curWidth

	-- Ensure outBuffer contains a whole number of sextets
	local rem = outBufferLen % 6
	if rem ~= 0 then
		outBuffer = bit32.lshift(outBuffer, 6 - rem)
		outBufferLen = outBufferLen + 6 - rem
	end

	-- Write out the rest of the output buffer
	while outBufferLen >= 6 do
		local b64Code = bit32.extract(outBuffer, outBufferLen - 6, 6)
		outBufferLen = outBufferLen - 6

		outArr[outArrNext] = lookupB64Char[b64Code]
		outArrNext = outArrNext + 1
	end

	-- Pad the base64 output
	local padRemainder = #outArr % 4 -- outArr contains single characters so #outArr == length of output string
	if padRemainder ~= 0 then
		outArr[outArrNext] = string.rep(PADDING, 4 - padRemainder)
	end

	return table.concat(outArr)
end

--[[
	Decompress the given base64 string and return the original string of binary
	data. Does not check the validity of the input; call via a pcall for inputs
	which are not guaranteed to be well-formed.
]]
local function decompress(data)
	assert(type(data) == "string", "bad argument #1 to 'decompress' (string expected, got " .. type(data) .. ")")

	local dictionary = table_copy(initialDictionary)
	local nextEntry = initialDictionarySize

	local previousEmitted = nil

	local curWidth = math.floor(math.log(nextEntry, 2)) + 1
	local nextWidthChangeAt = 2^curWidth

	local outBuffer, outBufferLen = 0, 0
	local outArr, outArrNext = {}, 1

	for i = 1, #data do
		-- Read and decode the next sextet
		local cByte = string.byte(data, i)
		if cByte == PADDING_BYTE then
			break -- If we reach padding, we've read everything
		end

		outBuffer = bit32.lshift(outBuffer, 6) + lookupB64Code[cByte]
		outBufferLen = outBufferLen + 6

		if outBufferLen < curWidth then
			goto continue -- We haven't decoded enough characters to get the next code
		end

		-- Read next code
		local code = bit32.extract(outBuffer, outBufferLen - curWidth, curWidth)
		outBufferLen = outBufferLen - curWidth

		local key = dictionary[code] -- The key to add to the dictionary, or nil
		local toEmit = nil
		if key then
			toEmit = key
			key = previousEmitted and (previousEmitted .. string.sub(key, 1, 1)) or nil
		else
			key = previousEmitted .. string.sub(previousEmitted, 1, 1)
			toEmit = key
		end

		-- Emit string
		outArr[outArrNext] = toEmit
		outArrNext = outArrNext + 1
		previousEmitted = toEmit

		-- Add to dictionary, changing width if necessary
		if key then
			dictionary[nextEntry] = key
			nextEntry = nextEntry + 1
			if nextEntry >= nextWidthChangeAt - 1 then -- We have to change width one entry before the encoder
				nextWidthChangeAt = nextWidthChangeAt * 2
				curWidth = curWidth + 1
			end
		end

	    ::continue::
	end

	-- If there is anything non-zero left in the buffer, the string was malformed
	-- assert(bit32.extract(outBuffer, 0, outBufferLen) == 0, "buffer was not empty")

	return table.concat(outArr)
end

return {
	compress = compress,
	decompress = decompress,
}
