// Copyright 2010 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include "Core/HW/Wiimote.h"

#include <fmt/format.h>

#include "Common/ChunkFile.h"
#include "Common/CommonTypes.h"

#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/HW/WiimoteEmu/WiimoteEmu.h"
#include "Core/HW/WiimoteReal/WiimoteReal.h"
#include "Core/IOS/IOS.h"
#include "Core/IOS/USB/Bluetooth/BTEmu.h"
#include "Core/IOS/USB/Bluetooth/WiimoteDevice.h"
#include "Core/Movie.h"
#include "Core/NetPlayClient.h"

#include "InputCommon/ControllerEmu/ControlGroup/ControlGroup.h"
#include "InputCommon/InputConfig.h"

// Limit the amount of wiimote connect requests, when a button is pressed in disconnected state
static std::array<u8, MAX_BBMOTES> s_last_connect_request_counter;

namespace WiimoteCommon
{
static std::array<std::atomic<WiimoteSource>, MAX_BBMOTES> s_wiimote_sources;

WiimoteSource GetSource(unsigned int index)
{
  return s_wiimote_sources[index];
}

void SetSource(unsigned int index, WiimoteSource source)
{
  const WiimoteSource previous_source = s_wiimote_sources[index].exchange(source);

  if (previous_source == source)
  {
    // No change. Do nothing.
    return;
  }

  WiimoteReal::HandleWiimoteSourceChange(index);

  // Reconnect to the emulator.
  Core::RunAsCPUThread([index, previous_source, source] {
    if (previous_source != WiimoteSource::None)
      ::Wiimote::Connect(index, false);

    if (source == WiimoteSource::Emulated)
      ::Wiimote::Connect(index, true);
  });
}
}  // namespace WiimoteCommon

namespace Wiimote
{
static InputConfig s_config(WIIMOTE_INI_NAME, _trans("Wii Remote"), "Wiimote");

InputConfig* GetConfig()
{
  return &s_config;
}

ControllerEmu::ControlGroup* GetWiimoteGroup(int number, WiimoteEmu::WiimoteGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetWiimoteGroup(group);
}

ControllerEmu::ControlGroup* GetNunchukGroup(int number, WiimoteEmu::NunchukGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetNunchukGroup(group);
}

ControllerEmu::ControlGroup* GetClassicGroup(int number, WiimoteEmu::ClassicGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetClassicGroup(group);
}

ControllerEmu::ControlGroup* GetGuitarGroup(int number, WiimoteEmu::GuitarGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetGuitarGroup(group);
}

ControllerEmu::ControlGroup* GetDrumsGroup(int number, WiimoteEmu::DrumsGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetDrumsGroup(group);
}

ControllerEmu::ControlGroup* GetTurntableGroup(int number, WiimoteEmu::TurntableGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))
      ->GetTurntableGroup(group);
}

ControllerEmu::ControlGroup* GetUDrawTabletGroup(int number, WiimoteEmu::UDrawTabletGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))
      ->GetUDrawTabletGroup(group);
}

ControllerEmu::ControlGroup* GetDrawsomeTabletGroup(int number,
                                                    WiimoteEmu::DrawsomeTabletGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))
      ->GetDrawsomeTabletGroup(group);
}

ControllerEmu::ControlGroup* GetTaTaConGroup(int number, WiimoteEmu::TaTaConGroup group)
{
  return static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->GetTaTaConGroup(group);
}

void Shutdown()
{
  s_config.UnregisterHotplugCallback();

  s_config.ClearControllers();

  WiimoteReal::Stop();
}

void Initialize(InitializeMode init_mode)
{
  if (s_config.ControllersNeedToBeCreated())
  {
    for (unsigned int i = WIIMOTE_CHAN_0; i < MAX_BBMOTES; ++i)
      s_config.CreateController<WiimoteEmu::Wiimote>(i);
  }

  s_config.RegisterHotplugCallback();

  LoadConfig();

  WiimoteReal::Initialize(init_mode);

  // Reload Wiimotes with our settings
  if (Movie::IsMovieActive())
    Movie::ChangeWiiPads();
}

void Connect(unsigned int index, bool connect)
{
  if (SConfig::GetInstance().m_bt_passthrough_enabled || index >= MAX_BBMOTES)
    return;

  const auto ios = IOS::HLE::GetIOS();
  if (!ios)
    return;

  const auto bluetooth = std::static_pointer_cast<IOS::HLE::Device::BluetoothEmu>(
      ios->GetDeviceByName("/dev/usb/oh1/57e/305"));

  if (bluetooth)
    bluetooth->AccessWiimoteByIndex(index)->Activate(connect);

  const char* const message = connect ? "Wii Remote {} connected" : "Wii Remote {} disconnected";
  Core::DisplayMessage(fmt::format(message, index + 1), 3000);
}

void ResetAllWiimotes()
{
  for (int i = WIIMOTE_CHAN_0; i < MAX_BBMOTES; ++i)
    static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(i))->Reset();
}

void LoadConfig()
{
  s_config.LoadConfig(false);
  s_last_connect_request_counter.fill(0);
}

void Resume()
{
  WiimoteReal::Resume();
}

void Pause()
{
  WiimoteReal::Pause();
}

// An L2CAP packet is passed from the Core to the Wiimote on the HID CONTROL channel.
void ControlChannel(int number, u16 channel_id, const void* data, u32 size)
{
  if (WiimoteCommon::GetSource(number) == WiimoteSource::Emulated)
  {
    static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))
        ->ControlChannel(channel_id, data, size);
  }
  else
  {
    WiimoteReal::ControlChannel(number, channel_id, data, size);
  }
}

// An L2CAP packet is passed from the Core to the Wiimote on the HID INTERRUPT channel.
void InterruptChannel(int number, u16 channel_id, const void* data, u32 size)
{
  if (WiimoteCommon::GetSource(number) == WiimoteSource::Emulated)
  {
    static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))
        ->InterruptChannel(channel_id, data, size);
  }
  else
  {
    WiimoteReal::InterruptChannel(number, channel_id, data, size);
  }
}

bool ButtonPressed(int number)
{
  const WiimoteSource source = WiimoteCommon::GetSource(number);

  if (s_last_connect_request_counter[number] > 0)
  {
    --s_last_connect_request_counter[number];
    if (source != WiimoteSource::None && NetPlay::IsNetPlayRunning())
      Wiimote::NetPlay_GetButtonPress(number, false);
    return false;
  }

  bool button_pressed = false;

  if (source == WiimoteSource::Emulated)
    button_pressed =
        static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->CheckForButtonPress();

  if (source == WiimoteSource::Real)
    button_pressed = WiimoteReal::CheckForButtonPress(number);

  if (source != WiimoteSource::None && NetPlay::IsNetPlayRunning())
    button_pressed = Wiimote::NetPlay_GetButtonPress(number, button_pressed);

  return button_pressed;
}

// This function is called periodically by the Core to update Wiimote state.
void Update(int number, bool connected)
{
  if (connected)
  {
    if (WiimoteCommon::GetSource(number) == WiimoteSource::Emulated)
      static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(number))->Update();
    else
      WiimoteReal::Update(number);
  }
  else
  {
    if (ButtonPressed(number))
    {
      Connect(number, true);
      // arbitrary value so it doesn't try to send multiple requests before Dolphin can react
      // if Wii Remotes are polled at 200Hz then this results in one request being sent per 500ms
      s_last_connect_request_counter[number] = 100;
    }
  }
}

// Save/Load state
void DoState(PointerWrap& p)
{
  for (int i = 0; i < MAX_BBMOTES; ++i)
  {
    const WiimoteSource source = WiimoteCommon::GetSource(i);
    auto state_wiimote_source = u8(source);
    p.Do(state_wiimote_source);

    if (WiimoteSource(state_wiimote_source) == WiimoteSource::Emulated)
    {
      // Sync complete state of emulated wiimotes.
      static_cast<WiimoteEmu::Wiimote*>(s_config.GetController(i))->DoState(p);
    }

    if (p.GetMode() == PointerWrap::MODE_READ)
    {
      // If using a real wiimote or the save-state source does not match the current source,
      // then force a reconnection on load.
      if (source == WiimoteSource::Real || source != WiimoteSource(state_wiimote_source))
      {
        Connect(i, false);
        Connect(i, true);
      }
    }
  }
}
}  // namespace Wiimote
