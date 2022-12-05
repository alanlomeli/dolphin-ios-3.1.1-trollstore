package org.dolphinemu.dolphinemu.utils;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.FragmentActivity;
import androidx.core.content.ContextCompat;

import android.widget.Toast;

import org.dolphinemu.dolphinemu.R;

import static android.Manifest.permission.WRITE_EXTERNAL_STORAGE;

public class PermissionsHandler
{
  public static final int REQUEST_CODE_WRITE_PERMISSION = 500;

  @TargetApi(Build.VERSION_CODES.M)
  public static boolean checkWritePermission(final FragmentActivity activity)
  {
    if (android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.M)
    {
      return true;
    }

    int hasWritePermission = ContextCompat.checkSelfPermission(activity, WRITE_EXTERNAL_STORAGE);

    if (hasWritePermission != PackageManager.PERMISSION_GRANTED)
    {
      if (activity.shouldShowRequestPermissionRationale(WRITE_EXTERNAL_STORAGE))
      {
        showMessageOKCancel(activity, activity.getString(R.string.write_permission_needed),
                (dialog, which) -> activity.requestPermissions(new String[]{WRITE_EXTERNAL_STORAGE},
                        REQUEST_CODE_WRITE_PERMISSION));
        return false;
      }

      activity.requestPermissions(new String[]{WRITE_EXTERNAL_STORAGE},
              REQUEST_CODE_WRITE_PERMISSION);
      return false;
    }

    return true;
  }

  public static boolean hasWriteAccess(Context context)
  {
    if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
    {
      int hasWritePermission = ContextCompat.checkSelfPermission(context, WRITE_EXTERNAL_STORAGE);
      return hasWritePermission == PackageManager.PERMISSION_GRANTED;
    }

    return true;
  }

  private static void showMessageOKCancel(final FragmentActivity activity, String message,
          DialogInterface.OnClickListener okListener)
  {
    new AlertDialog.Builder(activity, R.style.DolphinDialogBase)
            .setMessage(message)
            .setPositiveButton(android.R.string.ok, okListener)
            .setNegativeButton(android.R.string.cancel, (dialogInterface, i) ->
                    Toast.makeText(activity, R.string.write_permission_needed, Toast.LENGTH_SHORT)
                            .show())
            .create()
            .show();
  }
}
