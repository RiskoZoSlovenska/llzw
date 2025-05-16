local bit32_lshift, bit32_extract = bit32.lshift, bit32.extract

local string_byte = string.byte

local INITIAL_DICT_SIZE = 256
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PADDING = "="
local PADDING_BYTE = string_byte(PADDING)

local lookupB64Char = {}
local lookupB64Code = {}

for i = 1, 64 do
	local c = string.sub(ALPHABET, i, i)

	lookupB64Char[i - 1] = c
	lookupB64Code[string_byte(c)] = i - 1
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

	local trieCodes = {}
	local trieNexts = {}
	for i = 0, INITIAL_DICT_SIZE - 1 do
		trieCodes[i] = i
		trieNexts[i] = {}
	end
	local nextEntry = INITIAL_DICT_SIZE

	local key = nil -- The code corresponding to the current input slice that's being processed

	local curWidth = math.floor(math.log(nextEntry, 2)) + 1
	local nextWidthChangeAt = 2^curWidth

	local outBuffer, outBufferLen = 0, 0
	local outArr, outArrNext = {}, 1

	for i = 1, #data do
		local c = string_byte(data, i, i)

		if key == nil then
			key = c
			continue
		end

		local nextKey = trieNexts[key][c]
		if nextKey ~= nil then
			key = nextKey
			continue -- key isn't the longest in the dictionary yet; keep searching
		end

		-- Emit key code
		local code = trieCodes[key]
		outBuffer = bit32_lshift(outBuffer, curWidth) + code
		outBufferLen = outBufferLen + curWidth

		-- Write from out buffer
		while outBufferLen >= 6 do
			local b64Code = bit32_extract(outBuffer, outBufferLen - 6, 6)
			outBufferLen = outBufferLen - 6

			outArr[outArrNext] = lookupB64Char[b64Code]
			outArrNext = outArrNext + 1
		end

		-- Insert an entry for `key .. c` into the dictionary with code `nextEntry` and change width if necessary
		trieNexts[key][c] = nextEntry
		trieCodes[nextEntry] = nextEntry
		trieNexts[nextEntry] = {}
		nextEntry = nextEntry + 1
		if nextEntry >= nextWidthChangeAt then
			nextWidthChangeAt = nextWidthChangeAt * 2
			curWidth = curWidth + 1
		end

		-- We emitted `key`'s code', but `key` doesn't contain `c`; `c` is left over and becomes the new `key`
		key = c
	end

	-- Emit code for the remainder (guaranteed to exist in the dictionary already)
	local code = trieCodes[key]
	outBuffer = bit32_lshift(outBuffer, curWidth) + code
	outBufferLen = outBufferLen + curWidth

	-- Ensure outBuffer contains a whole number of sextets
	local rem = outBufferLen % 6
	if rem ~= 0 then
		outBuffer = bit32_lshift(outBuffer, 6 - rem)
		outBufferLen = outBufferLen + 6 - rem
	end

	-- Write out the rest of the output buffer
	while outBufferLen >= 6 do
		local b64Code = bit32_extract(outBuffer, outBufferLen - 6, 6)
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

	local trieChars = {}
	local triePrevs = {}
	local trieLens = {}

	for i = 0, INITIAL_DICT_SIZE - 1 do
		trieChars[i] = string.char(i)
		triePrevs[i] = nil
		trieLens[i] = 0
	end
	local nextEntry = INITIAL_DICT_SIZE

	local previousEmitted = nil

	local curWidth = math.floor(math.log(nextEntry, 2)) + 1
	local nextWidthChangeAt = 2^curWidth

	local outBuffer, outBufferLen = 0, 0
	local outArr, outArrNext = {}, 1

	for i = 1, #data do
		-- Read and decode the next sextet
		local cByte = string_byte(data, i)
		if cByte == PADDING_BYTE then
			break -- If we reach padding, we've read everything
		end

		outBuffer = bit32_lshift(outBuffer, 6) + lookupB64Code[cByte]
		outBufferLen = outBufferLen + 6

		if outBufferLen < curWidth then
			continue -- We haven't decoded enough characters to get the next code
		end

		-- Read next code
		local code = bit32_extract(outBuffer, outBufferLen - curWidth, curWidth)
		outBufferLen = outBufferLen - curWidth

		local codeIsInDictionary = (trieChars[code] ~= nil)
		local toEmit = codeIsInDictionary and code or previousEmitted

		-- Emit toEmit and find its first character
		local lenToEmit = trieLens[toEmit]
		local emitting = toEmit

		for emitOffset = lenToEmit, 0, -1 do
			outArr[outArrNext + emitOffset] = trieChars[emitting]
			emitting = triePrevs[emitting]
		end

		local firstChar = outArr[outArrNext]
		outArrNext = outArrNext + lenToEmit + 1

		-- Add `previousEmitted .. firstChar` to the dictionary
		if previousEmitted ~= nil then
			trieChars[nextEntry] = firstChar
			triePrevs[nextEntry] = previousEmitted
			trieLens[nextEntry] = trieLens[previousEmitted] + 1

			nextEntry = nextEntry + 1
			if nextEntry >= nextWidthChangeAt - 1 then -- We have to change width one entry before the encoder
				nextWidthChangeAt = nextWidthChangeAt * 2
				curWidth = curWidth + 1
			end
		end

		if not codeIsInDictionary then
			-- If `code` was not in the dict, we actually wanted to emit `previousEmitted .. firstChar`
			outArr[outArrNext] = firstChar
			outArrNext = outArrNext + 1
		end

		previousEmitted = codeIsInDictionary and toEmit or (nextEntry - 1)
	end

	-- If there is anything non-zero left in the buffer, the string was malformed
	-- assert(bit32_extract(outBuffer, 0, outBufferLen) == 0, "buffer was not empty")

	return table.concat(outArr)
end


return {
	compress = compress,
	decompress = decompress,
}
