// mayhem/rapidobj-fuzz.cpp — libFuzzer harness for guybrush77/rapidobj's Wavefront .OBJ parser.
//
// Target name preserved from the original mayhemheroes integration: rapidobj-fuzz.
// rapidobj is a header-only C++17 .OBJ parser (single header include/rapidobj/rapidobj.hpp).
//
// The original fork harness wrote the fuzz bytes to "tmp.bin" on disk and called ParseFile(); that
// is slow (a file write per iteration) and pulls in filesystem state. Here we feed the bytes to the
// in-memory rapidobj::ParseStream() over a std::istringstream instead — same parser surface, no
// per-iteration disk I/O. MaterialLibrary::Ignore() keeps an embedded `mtllib` directive from
// reaching out to the filesystem, so the harness fuzzes ONLY the .OBJ parser on attacker bytes.
#include <cstddef>
#include <cstdint>
#include <sstream>
#include <string>

#include "rapidobj/rapidobj.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    std::string text(reinterpret_cast<const char*>(data), size);
    std::istringstream stream(text);

    // Parse the attacker .OBJ from memory; Ignore() so `mtllib` lines don't touch the filesystem.
    rapidobj::Result result = rapidobj::ParseStream(stream, rapidobj::MaterialLibrary::Ignore());

    // Exercise the post-parse path too: triangulation walks the parsed mesh.
    if (!result.error) {
        rapidobj::Triangulate(result);
    }

    return 0;
}
