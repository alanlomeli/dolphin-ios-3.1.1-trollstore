package org.dolphinemu.dolphinemu.features.settings.ui.viewholder;

import android.content.Context;
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.view.View;
import android.widget.TextView;

import org.dolphinemu.dolphinemu.R;
import org.dolphinemu.dolphinemu.features.settings.model.view.RumbleBindingSetting;
import org.dolphinemu.dolphinemu.features.settings.model.view.SettingsItem;
import org.dolphinemu.dolphinemu.features.settings.ui.SettingsAdapter;

public class RumbleBindingViewHolder extends SettingViewHolder
{
  private RumbleBindingSetting mItem;

  private TextView mTextSettingName;
  private TextView mTextSettingDescription;

  private Context mContext;

  public RumbleBindingViewHolder(View itemView, SettingsAdapter adapter, Context context)
  {
    super(itemView, adapter);

    mContext = context;
  }

  @Override
  protected void findViews(View root)
  {
    mTextSettingName = (TextView) root.findViewById(R.id.text_setting_name);
    mTextSettingDescription = (TextView) root.findViewById(R.id.text_setting_description);
  }

  @Override
  public void bind(SettingsItem item)
  {
    SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(mContext);

    mItem = (RumbleBindingSetting) item;

    mTextSettingName.setText(item.getNameId());
    mTextSettingDescription
            .setText(sharedPreferences.getString(mItem.getKey() + mItem.getGameId(), ""));
  }

  @Override
  public void onClick(View clicked)
  {
    getAdapter().onInputBindingClick(mItem, getAdapterPosition());
  }
}
