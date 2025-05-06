# llzw - Fast LZW + base64 in pure Lua

`llzw` is a simple, small, relatively fast library that does [LZW compression/decompression](https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Welch) and [base64 encode/decode](https://en.wikipedia.org/wiki/Base64) in one step. It was originally created for compressing a couple-MiB JSON table into a fully printable string that could then be copied by the user or sent to a pastebin service.

Requires Lua 5.2+ or LuaJIT. See the [luau](../../tree/luau) branch for a Luau version.

The LZW implementation here uses variable-width codes, has no limit on the size of the dictionary, and does not perform any sort of optimization for uncompressible data. This may cause problems when de/compressing very large strings, but `llzw` probably isn't the right tool for that anyway.


## Usage

```lua
local llzw = require("llzw")

local compressed = llzw.compress(str) -- Never fails
local ok, decompressed = pcall(llzw.decompress, compressed) -- Use pcall if passing untrusted input

assert(str == decompressed)
```


## Performance

I've benchmarked `llzw` against [lualzw](https://github.com/Rochet2/lualzw) and [LibCompress](https://github.com/OpenPrograms/LibCompress/blob/master/LibCompress.lua) (both combined with [lbase64](https://github.com/iskolbin/lbase64)). It's not a strictly rigorous benchmark, but it is probably sufficient to get a rough idea of how it performs. Times are in seconds.

`iter` simply iterates over the input string and extracts each character using `string.byte()`.

<details>
	<summary>Results for a 3.2 MiB JSON file with lots of repetition</summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.13            |  0.13              |  1.00             |
| **llzw**          |  **0.44**        |  **0.32**          |  **6.02**         |
| lualzw            |  0.52            |  0.15              |  6.27             |
| lualzw + b64      |  0.59            |  0.25              |  4.70             |
| LibCompress       |  0.69            |  0.16              |  4.89             |
| LibCompress + b64 |  0.90            |  0.26              |  3.67             |
</details>

<details>
	<summary>Results for <a href="https://corpus.canterbury.ac.nz/descriptions/#cantrbry">cantrbry.tar</a></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.11            |  0.10              |  1.00             |
| **llzw**          |  **0.52**        |  **0.38**          |  **2.16**         |
| lualzw            |  0.53            |  0.29              |  2.84             |
| lualzw + b64      |  0.68            |  0.44              |  2.13             |
| LibCompress       |  0.78            |  0.37              |  1.77             |
| LibCompress + b64 |  1.14            |  0.60              |  1.32             |
</details>

<details>
	<summary>Results for <a href="https://corpus.canterbury.ac.nz/descriptions/#large">large.tar</a> (as retrieved on 2025-05-05)</summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.41            |  0.41              |  1.00             |
| **llzw**          |  **2.42**        |  **1.64**          |  **2.39**         |
| lualzw            |  2.18            |  1.33              |  2.85             |
| lualzw + b64      |  2.88            |  2.31              |  2.14             |
| LibCompress       |  4.60            |  1.57              |  2.02             |
| LibCompress + b64 |  5.55            |  2.53              |  1.51             |
</details>

<details>
	<summary>Results for 10 MiB of <code>/dev/random</code></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.40            |  0.41              |  1.00             |
| **llzw**          |  **6.04**        |  **3.68**          |  **0.60**         |
| lualzw            |  3.26            |  0.00              |  1.00             |
| lualzw + b64      |  5.44            |  3.38              |  0.75             |
| LibCompress       |  21.20           |  0.00              |  1.00             |
| LibCompress + b64 |  24.9            |  6.66              |  0.75             |
</details>

<details>
	<summary>Results for <a href="https://mattmahoney.net/dc/textdata.html">enwik8</a></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  3.67            |  3.67              |  1.00             |
| **llzw**          |  **31.49**       |  **18.17**         |  **2.18**         |
| lualzw            |  24.33           |  16.89             |  2.07             |
| lualzw + b64      |  37.04           |  51.68             |  1.55             |
| LibCompress       |  68.13           |  15.85             |  2.09             |
| LibCompress + b64 |  79.99           |  31.17             |  1.57             |
</details>
