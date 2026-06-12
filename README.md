# JsonToBinary

A small macOS Swift command-line tool (2016) that converts Caffe network weights exported as JSON — the format used by DeepLearningKit-style iOS inference — into a compact custom binary encoding, so that models like Tiny YOLO load in a fraction of the time and size on device. Despite the name in the repo description, the output is not spec-compliant BSON; it is a homegrown tagged format.

## Binary Format

Everything lives in `JsonToBinary/main.swift`:

- A **dictionary** is written as a `UInt32` entry count, then for each entry: key length (`UInt32`), ASCII key bytes, and a one-byte type tag for the value — `0` float, `1` dictionary, `2` array, `3` string.
- An **array** is written as its element type tag, a `UInt32` count, then the payload. Float arrays are dumped as raw little-endian `Float32`, which is the entire point: weight blobs become contiguous binary instead of decimal text.
- `writeBson(file:dic:)` serializes a `Dictionary<String, Any>` produced by `JSONSerialization`; `readBson(file:)` is the matching deserializer used to verify round-trips.

`naive.json` / `naive.bson` are a small committed sample of input and corresponding output.

## Usage

Open `JsonToBinary.xcodeproj`. This is a scratch tool, not a packaged CLI: the bottom of `main.swift` hardcodes a path to a `yolo_tiny.json` model (not included) and most of the driver code is commented out. Point `path` at your JSON model and call `writeBson` / `readBson` as needed. The leftover `cnt == 128` / `FOUND!` branches are leftover debugging code from chasing a single corrupted weight value and can be ignored.

## Status

A one-off utility from the same era as my DeepLearningKit experiments, kept for reference. It uses Swift 3-era `UnsafeMutablePointer` APIs (`deinitialize().assumingMemoryBound(to:)`) that no longer compile on modern Swift without changes.
