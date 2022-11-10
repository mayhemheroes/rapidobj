#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../include/rapidobj/rapidobj.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
    std::ofstream binFile("tmp.bin", std::ios::out | std::ios::binary);
    binFile.write((char*)Data, Size);
    binFile.close();

    rapidobj::ParseFile("tmp.bin");

    return 0;
}