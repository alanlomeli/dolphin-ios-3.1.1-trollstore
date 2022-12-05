// Copyright 2016 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#pragma once

#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>

#include "Common/Config/ConfigInfo.h"
#include "Common/Config/Enums.h"
#include "Common/Config/Layer.h"

namespace Config
{
using ConfigChangedCallback = std::function<void()>;

// Layer management
void AddLayer(std::unique_ptr<ConfigLayerLoader> loader);
std::shared_ptr<Layer> GetLayer(LayerType layer);
void RemoveLayer(LayerType layer);

void AddConfigChangedCallback(ConfigChangedCallback func);
void InvokeConfigChangedCallbacks();

// Explicit load and save of layers
void Load();
void Save();

void Init();
void Shutdown();
void ClearCurrentRunLayer();

const std::string& GetSystemName(System system);
std::optional<System> GetSystemFromName(const std::string& system);
const std::string& GetLayerName(LayerType layer);
LayerType GetActiveLayerForConfig(const Location&);

template <typename T>
T Get(LayerType layer, const Info<T>& info)
{
  if (layer == LayerType::Meta)
    return Get(info);
  return GetLayer(layer)->Get(info);
}

template <typename T>
T Get(const Info<T>& info)
{
  return GetLayer(GetActiveLayerForConfig(info.location))->Get(info);
}

template <typename T>
T GetBase(const Info<T>& info)
{
  return Get(LayerType::Base, info);
}

template <typename T>
LayerType GetActiveLayerForConfig(const Info<T>& info)
{
  return GetActiveLayerForConfig(info.location);
}

template <typename T>
void Set(LayerType layer, const Info<T>& info, const std::common_type_t<T>& value)
{
  GetLayer(layer)->Set(info, value);
  InvokeConfigChangedCallbacks();
}

template <typename T>
void SetBase(const Info<T>& info, const std::common_type_t<T>& value)
{
  Set<T>(LayerType::Base, info, value);
}

template <typename T>
void SetCurrent(const Info<T>& info, const std::common_type_t<T>& value)
{
  Set<T>(LayerType::CurrentRun, info, value);
}

template <typename T>
void SetBaseOrCurrent(const Info<T>& info, const std::common_type_t<T>& value)
{
  if (GetActiveLayerForConfig(info) == LayerType::Base)
    Set<T>(LayerType::Base, info, value);
  else
    Set<T>(LayerType::CurrentRun, info, value);
}

// Used to defer InvokeConfigChangedCallbacks until after the completion of many config changes.
class ConfigChangeCallbackGuard
{
public:
  ConfigChangeCallbackGuard();
  ~ConfigChangeCallbackGuard();

  ConfigChangeCallbackGuard(const ConfigChangeCallbackGuard&) = delete;
  ConfigChangeCallbackGuard& operator=(const ConfigChangeCallbackGuard&) = delete;
};
}  // namespace Config
