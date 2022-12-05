// Copyright 2009 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include "DiscIO/Volume.h"

#include <algorithm>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "Common/CommonTypes.h"
#include "Common/StringUtil.h"

#include "DiscIO/Blob.h"
#include "DiscIO/Enums.h"
#include "DiscIO/VolumeDisc.h"
#include "DiscIO/VolumeGC.h"
#include "DiscIO/VolumeWad.h"
#include "DiscIO/VolumeWii.h"

namespace DiscIO
{
const IOS::ES::TicketReader Volume::INVALID_TICKET{};
const IOS::ES::TMDReader Volume::INVALID_TMD{};
const std::vector<u8> Volume::INVALID_CERT_CHAIN{};

std::map<Language, std::string> Volume::ReadWiiNames(const std::vector<char16_t>& data)
{
  std::map<Language, std::string> names;
  for (size_t i = 0; i < NUMBER_OF_LANGUAGES; ++i)
  {
    const size_t name_start = NAME_CHARS_LENGTH * i;
    if (name_start + NAME_CHARS_LENGTH <= data.size())
    {
      const std::string name = UTF16BEToUTF8(data.data() + name_start, NAME_CHARS_LENGTH);
      if (!name.empty())
        names[static_cast<Language>(i)] = name;
    }
  }
  return names;
}

static std::unique_ptr<VolumeDisc> CreateDisc(std::unique_ptr<BlobReader>& reader)
{
  // Check for Wii
  const std::optional<u32> wii_magic = reader->ReadSwapped<u32>(0x18);
  if (wii_magic == u32(0x5D1C9EA3))
    return std::make_unique<VolumeWii>(std::move(reader));

  // Check for GC
  const std::optional<u32> gc_magic = reader->ReadSwapped<u32>(0x1C);
  if (gc_magic == u32(0xC2339F3D))
    return std::make_unique<VolumeGC>(std::move(reader));

  // No known magic words found
  return nullptr;
}

std::unique_ptr<VolumeDisc> CreateDisc(const std::string& path)
{
  std::unique_ptr<BlobReader> reader(CreateBlobReader(path));
  return reader ? CreateDisc(reader) : nullptr;
}

static std::unique_ptr<VolumeWAD> CreateWAD(std::unique_ptr<BlobReader>& reader)
{
  // Check for WAD
  // 0x206962 for boot2 wads
  const std::optional<u32> wad_magic = reader->ReadSwapped<u32>(0x02);
  if (wad_magic == u32(0x00204973) || wad_magic == u32(0x00206962))
    return std::make_unique<VolumeWAD>(std::move(reader));

  // No known magic words found
  return nullptr;
}

std::unique_ptr<VolumeWAD> CreateWAD(const std::string& path)
{
  std::unique_ptr<BlobReader> reader(CreateBlobReader(path));
  return reader ? CreateWAD(reader) : nullptr;
}

std::unique_ptr<Volume> CreateVolume(const std::string& path)
{
  std::unique_ptr<BlobReader> reader(CreateBlobReader(path));
  if (reader == nullptr)
    return nullptr;

  std::unique_ptr<VolumeDisc> disc = CreateDisc(reader);
  if (disc)
    return disc;

  std::unique_ptr<VolumeWAD> wad = CreateWAD(reader);
  if (wad)
    return wad;

  return nullptr;
}

}  // namespace DiscIO
