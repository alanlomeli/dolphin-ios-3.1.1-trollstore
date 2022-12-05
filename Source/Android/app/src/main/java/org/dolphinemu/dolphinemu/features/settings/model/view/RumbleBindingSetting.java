package org.dolphinemu.dolphinemu.features.settings.model.view;

import android.os.Vibrator;
import android.view.InputDevice;
import android.view.KeyEvent;

import org.dolphinemu.dolphinemu.DolphinApplication;
import org.dolphinemu.dolphinemu.R;
import org.dolphinemu.dolphinemu.features.settings.model.Setting;
import org.dolphinemu.dolphinemu.features.settings.model.StringSetting;
import org.dolphinemu.dolphinemu.utils.Rumble;

public class RumbleBindingSetting extends InputBindingSetting
{

  public RumbleBindingSetting(String key, String section, int titleId, Setting setting,
          String gameId)
  {
    super(key, section, titleId, setting, gameId);
  }

  @Override
  public String getValue()
  {
    if (getSetting() == null)
    {
      return "";
    }

    StringSetting setting = (StringSetting) getSetting();
    return setting.getValue();
  }

  /**
   * Just need the device when saving rumble.
   */
  @Override
  public void onKeyInput(KeyEvent keyEvent)
  {
    saveRumble(keyEvent.getDevice());
  }

  /**
   * Just need the device when saving rumble.
   */
  @Override
  public void onMotionInput(InputDevice device,
          InputDevice.MotionRange motionRange,
          char axisDir)
  {
    saveRumble(device);
  }

  private void saveRumble(InputDevice device)
  {
    Vibrator vibrator = device.getVibrator();
    if (vibrator != null && vibrator.hasVibrator())
    {
      setValue(device.getDescriptor(), device.getName());
      Rumble.doRumble(vibrator);
    }
    else
    {
      setValue("",
              DolphinApplication.getAppContext().getString(R.string.rumble_not_found));
    }
  }

  @Override
  public int getType()
  {
    return TYPE_RUMBLE_BINDING;
  }
}
