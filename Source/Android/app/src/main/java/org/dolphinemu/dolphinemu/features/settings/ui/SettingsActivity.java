package org.dolphinemu.dolphinemu.features.settings.ui;

import android.app.ProgressDialog;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.FragmentTransaction;
import androidx.lifecycle.ViewModelProvider;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.appcompat.app.AppCompatActivity;

import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.widget.Toast;

import org.dolphinemu.dolphinemu.R;
import org.dolphinemu.dolphinemu.ui.main.MainActivity;
import org.dolphinemu.dolphinemu.ui.main.TvMainActivity;
import org.dolphinemu.dolphinemu.utils.DirectoryInitialization;
import org.dolphinemu.dolphinemu.utils.DirectoryStateReceiver;
import org.dolphinemu.dolphinemu.utils.FileBrowserHelper;
import org.dolphinemu.dolphinemu.utils.TvUtil;

public final class SettingsActivity extends AppCompatActivity implements SettingsActivityView
{
  private static final String ARG_MENU_TAG = "menu_tag";
  private static final String ARG_GAME_ID = "game_id";
  private static final String FRAGMENT_TAG = "settings";
  private SettingsActivityPresenter mPresenter;

  private ProgressDialog dialog;

  public static void launch(Context context, MenuTag menuTag, String gameId)
  {
    Intent settings = new Intent(context, SettingsActivity.class);
    settings.putExtra(ARG_MENU_TAG, menuTag);
    settings.putExtra(ARG_GAME_ID, gameId);
    context.startActivity(settings);
  }

  @Override
  protected void onCreate(Bundle savedInstanceState)
  {
    super.onCreate(savedInstanceState);

    if (TvUtil.isLeanback(getApplicationContext()))
    {
      TvMainActivity.skipRescanningLibrary();
    }
    else
    {
      MainActivity.skipRescanningLibrary();
    }

    setContentView(R.layout.activity_settings);

    Intent launcher = getIntent();
    String gameID = launcher.getStringExtra(ARG_GAME_ID);
    MenuTag menuTag = (MenuTag) launcher.getSerializableExtra(ARG_MENU_TAG);

    mPresenter = new SettingsActivityPresenter(this, getSettings());
    mPresenter.onCreate(savedInstanceState, menuTag, gameID, getApplicationContext());
  }

  @Override
  public boolean onCreateOptionsMenu(Menu menu)
  {
    MenuInflater inflater = getMenuInflater();
    inflater.inflate(R.menu.menu_settings, menu);

    return true;
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item)
  {
    return mPresenter.handleOptionsItem(item.getItemId());
  }

  @Override
  protected void onSaveInstanceState(@NonNull Bundle outState)
  {
    // Critical: If super method is not called, rotations will be busted.
    super.onSaveInstanceState(outState);
    mPresenter.saveState(outState);
  }

  @Override
  protected void onStart()
  {
    super.onStart();
    mPresenter.onStart();
  }

  /**
   * If this is called, the user has left the settings screen (potentially through the
   * home button) and will expect their changes to be persisted. So we kick off an
   * IntentService which will do so on a background thread.
   */
  @Override
  protected void onStop()
  {
    super.onStop();

    mPresenter.onStop(isFinishing());
  }

  @Override
  public void showSettingsFragment(MenuTag menuTag, Bundle extras, boolean addToStack,
          String gameID)
  {
    if (!addToStack && getFragment() != null)
      return;

    FragmentTransaction transaction = getSupportFragmentManager().beginTransaction();

    if (addToStack)
    {
      if (areSystemAnimationsEnabled())
      {
        transaction.setCustomAnimations(
                R.animator.settings_enter,
                R.animator.settings_exit,
                R.animator.settings_pop_enter,
                R.animator.setttings_pop_exit);
      }

      transaction.addToBackStack(null);
    }
    transaction.replace(R.id.frame_content, SettingsFragment.newInstance(menuTag, gameID, extras),
            FRAGMENT_TAG);

    transaction.commit();
  }

  private boolean areSystemAnimationsEnabled()
  {
    float duration = Settings.Global.getFloat(
            getContentResolver(),
            Settings.Global.ANIMATOR_DURATION_SCALE, 1);
    float transition = Settings.Global.getFloat(
            getContentResolver(),
            Settings.Global.TRANSITION_ANIMATION_SCALE, 1);
    return duration != 0 && transition != 0;
  }

  @Override
  public void startDirectoryInitializationService(DirectoryStateReceiver receiver,
          IntentFilter filter)
  {
    LocalBroadcastManager.getInstance(this).registerReceiver(
            receiver,
            filter);
    DirectoryInitialization.start(this);
  }

  @Override
  public void stopListeningToDirectoryInitializationService(DirectoryStateReceiver receiver)
  {
    LocalBroadcastManager.getInstance(this).unregisterReceiver(receiver);
  }

  @Override
  protected void onActivityResult(int requestCode, int resultCode, Intent result)
  {
    super.onActivityResult(requestCode, resultCode, result);

    // Save modified non-FilePicker settings beforehand since finish() won't save them.
    // onStop() must come before handling the resultCode to properly save FilePicker selection.
    mPresenter.onStop(true);

    // If the user picked a file, as opposed to just backing out.
    if (resultCode == MainActivity.RESULT_OK)
    {
      String path = FileBrowserHelper.getSelectedPath(result);
      getFragment().getAdapter().onFilePickerConfirmation(path);

      // Prevent duplicate Toasts.
      if (!mPresenter.shouldSave())
      {
        Toast.makeText(this, "Saved settings to INI files", Toast.LENGTH_SHORT).show();
      }
    }

    // TODO: After result of FilePicker, duplicate SettingsActivity appears.
    //       Finish to avoid this. Is there a better method?
    finish();
  }

  @Override
  public void showLoading()
  {
    if (dialog == null)
    {
      dialog = new ProgressDialog(this);
      dialog.setMessage(getString(R.string.load_settings));
      dialog.setIndeterminate(true);
    }

    dialog.show();
  }

  @Override
  public void hideLoading()
  {
    dialog.dismiss();
  }

  @Override
  public void showPermissionNeededHint()
  {
    Toast.makeText(this, R.string.write_permission_needed, Toast.LENGTH_SHORT)
            .show();
  }

  @Override
  public void showExternalStorageNotMountedHint()
  {
    Toast.makeText(this, R.string.external_storage_not_mounted, Toast.LENGTH_SHORT)
            .show();
  }

  @Override
  public void showGameIniJunkDeletionQuestion()
  {
    new AlertDialog.Builder(this, R.style.DolphinDialogBase)
            .setTitle(getString(R.string.game_ini_junk_title))
            .setMessage(getString(R.string.game_ini_junk_question))
            .setPositiveButton(R.string.yes, (dialogInterface, i) -> mPresenter.clearSettings())
            .setNegativeButton(R.string.no, null)
            .create()
            .show();
  }

  @Override
  public org.dolphinemu.dolphinemu.features.settings.model.Settings getSettings()
  {
    return new ViewModelProvider(this).get(SettingsViewModel.class).getSettings();
  }

  @Override
  public void onSettingsFileLoaded(
          org.dolphinemu.dolphinemu.features.settings.model.Settings settings)
  {
    SettingsFragmentView fragment = getFragment();

    if (fragment != null)
    {
      fragment.onSettingsFileLoaded(settings);
    }
  }

  @Override
  public void onSettingsFileNotFound()
  {
    SettingsFragmentView fragment = getFragment();

    if (fragment != null)
    {
      fragment.loadDefaultSettings();
    }
  }

  @Override
  public void showToastMessage(String message)
  {
    Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
  }

  @Override
  public void onSettingChanged(String key)
  {
    mPresenter.onSettingChanged(key);
  }

  @Override
  public void onGcPadSettingChanged(MenuTag key, int value)
  {
    mPresenter.onGcPadSettingChanged(key, value);
  }

  @Override
  public void onWiimoteSettingChanged(MenuTag section, int value)
  {
    mPresenter.onWiimoteSettingChanged(section, value);
  }

  @Override
  public void onExtensionSettingChanged(MenuTag menuTag, int value)
  {
    mPresenter.onExtensionSettingChanged(menuTag, value);
  }

  private SettingsFragment getFragment()
  {
    return (SettingsFragment) getSupportFragmentManager().findFragmentByTag(FRAGMENT_TAG);
  }
}
