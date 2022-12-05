package org.dolphinemu.dolphinemu.ui.platform;

import android.os.Bundle;

import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import org.dolphinemu.dolphinemu.R;
import org.dolphinemu.dolphinemu.adapters.GameAdapter;
import org.dolphinemu.dolphinemu.services.GameFileCacheService;

public final class PlatformGamesFragment extends Fragment implements PlatformGamesView
{
  private static final String ARG_PLATFORM = "platform";

  private GameAdapter mAdapter;
  private RecyclerView mRecyclerView;

  public static PlatformGamesFragment newInstance(Platform platform)
  {
    PlatformGamesFragment fragment = new PlatformGamesFragment();

    Bundle args = new Bundle();
    args.putSerializable(ARG_PLATFORM, platform);

    fragment.setArguments(args);
    return fragment;
  }

  @Override
  public void onCreate(Bundle savedInstanceState)
  {
    super.onCreate(savedInstanceState);
  }

  @Override
  public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState)
  {
    View rootView = inflater.inflate(R.layout.fragment_grid, container, false);

    findViews(rootView);

    return rootView;
  }

  @Override
  public void onViewCreated(View view, Bundle savedInstanceState)
  {
    int columns = getResources().getInteger(R.integer.game_grid_columns);
    RecyclerView.LayoutManager layoutManager = new GridLayoutManager(getActivity(), columns);
    mAdapter = new GameAdapter();

    mRecyclerView.setLayoutManager(layoutManager);
    mRecyclerView.setAdapter(mAdapter);

    mRecyclerView.addItemDecoration(new GameAdapter.SpacesItemDecoration(8));

    showGames();
  }

  @Override
  public void refreshScreenshotAtPosition(int position)
  {
    mAdapter.notifyItemChanged(position);
  }

  @Override
  public void onItemClick(String gameId)
  {
    // No-op for now
  }

  @Override
  public void showGames()
  {
    if (mAdapter != null)
    {
      Platform platform = (Platform) getArguments().getSerializable(ARG_PLATFORM);
      mAdapter.swapDataSet(GameFileCacheService.getGameFilesForPlatform(platform));
    }
  }

  private void findViews(View root)
  {
    mRecyclerView = (RecyclerView) root.findViewById(R.id.grid_games);
  }
}
