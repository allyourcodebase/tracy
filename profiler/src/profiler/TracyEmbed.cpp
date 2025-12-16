#include "TracyEmbed.hpp"
#include "lz4.h"

EmbedData::EmbedData( size_t size, size_t lz4Size, const uint8_t* data )
    : m_data( new char[size] )
    , m_size( size )
{
    LZ4_decompress_safe( (const char*)data, m_data, lz4Size, size );
}

EmbedData::~EmbedData()
{
    delete[] m_data;
}
