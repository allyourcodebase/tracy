#ifndef __TRACYFILEMETA_HPP__
#define __TRACYFILEMETA_HPP__

#include <algorithm>
#include <stddef.h>
#include <zstd.h>
#include <lz4.h>

namespace tracy
{

constexpr size_t FileBufSize = 64 * 1024;
constexpr size_t FileBoundSize = std::max( LZ4_COMPRESSBOUND( FileBufSize ), ZSTD_COMPRESSBOUND( FileBufSize ) );

}

#endif
