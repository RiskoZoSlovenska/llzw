# llzw - Fast LZW + base64 in pure Lua

This is the Luau branch of `llzw`.

`llzw` is a simple, small, relatively fast library that does [LZW compression/decompression](https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Welch) and [base64 encode/decode](https://en.wikipedia.org/wiki/Base64) in one step. It was originally created for compressing a couple-MiB JSON table into a fully printable string that could then be copied by the user or sent to a pastebin service.

The LZW implementation here uses variable-width codes, has no limit on the size of the dictionary, and does not perform any sort of optimization for uncompressible data. This may cause problems when de/compressing very large strings, but `llzw` probably isn't the right tool for that anyway.


## Usage

```lua
local llzw = require("llzw")

local compressed = llzw.compress(str) -- Never fails
local ok, decompressed = pcall(llzw.decompress, compressed) -- Use pcall if passing untrusted input

assert(str == decompressed)
```


## Performance

I've benchmarked `llzw` against [lualzw](https://github.com/Rochet2/lualzw) and [LibCompress](https://github.com/OpenPrograms/LibCompress/blob/master/LibCompress.lua) (both combined with [lbase64](https://github.com/iskolbin/lbase64)). It's not a strictly rigorous benchmark, but it is probably sufficient to get a rough idea of how it performs. These were done with Lua 5.2 on an i7-11800H. Times are in seconds.

`iter` simply iterates over the input string and extracts each character using `string.byte()`.

<details>
	<summary>Results for a 2.5 MiB minified JSON file with lots of repetition</summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.10            |  0.10              |  1.00             |
| **llzw**          |  **0.33**        |  **0.27**          |  **5.06**         |
| lualzw            |  0.41            |  0.14              |  5.41             |
| lualzw + b64      |  0.49            |  0.23              |  4.06             |
| LibCompress       |  0.55            |  0.14              |  4.14             |
| LibCompress + b64 |  0.71            |  0.23              |  3.11             |
</details>

<details>
	<summary>Results for <a href="https://corpus.canterbury.ac.nz/descriptions/#cantrbry">cantrbry.tar</a></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.11            |  0.11              |  1.00             |
| **llzw**          |  **0.48**        |  **0.36**          |  **2.16**         |
| lualzw            |  0.54            |  0.29              |  2.84             |
| lualzw + b64      |  0.68            |  0.44              |  2.13             |
| LibCompress       |  0.78            |  0.36              |  1.77             |
| LibCompress + b64 |  1.13            |  0.60              |  1.32             |
</details>

<details>
	<summary>Results for <a href="https://corpus.canterbury.ac.nz/descriptions/#large">large.tar</a> (as retrieved on 2025-05-05)</summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.41            |  0.41              |  1.00             |
| **llzw**          |  **2.24**        |  **1.55**          |  **2.39**         |
| lualzw            |  2.19            |  1.30              |  2.85             |
| lualzw + b64      |  2.86            |  2.31              |  2.14             |
| LibCompress       |  4.73            |  1.59              |  2.02             |
| LibCompress + b64 |  5.79            |  2.54              |  1.51             |
</details>

<details>
	<summary>Results for 10 MiB of <code>/dev/random</code></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  0.39            |  0.39              |  1.00             |
| **llzw**          |  **5.81**        |  **3.31**          |  **0.60**         |
| lualzw            |  3.26            |  0.00              |  1.00             |
| lualzw + b64      |  5.52            |  3.39              |  0.75             |
| LibCompress       |  21.46           |  0.00              |  1.00             |
| LibCompress + b64 |  26.46           |  6.86              |  0.75             |
</details>

<details>
	<summary>Results for <a href="https://mattmahoney.net/dc/textdata.html">enwik8</a></summary>

|                   | Compression Time | Decompression Time | Compression Ratio |
|-------------------|------------------|--------------------|-------------------|
| iter              |  3.77            |  3.72              |  1.00             |
| **llzw**          |  **30.48**       |  **17.38**         |  **2.18**         |
| lualzw            |  24.42           |  17.63             |  2.07             |
| lualzw + b64      |  36.98           |  52.48             |  1.55             |
| LibCompress       |  68.52           |  16.02             |  2.09             |
| LibCompress + b64 |  80.13           |  31.07             |  1.57             |
</details>
