// Copyright 2019 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import "AnalyticsNoticeViewController.h"

#import "AppDelegate.h"

#import "AutoStates.h"

#import "Common/CommonPaths.h"
#import "Common/Config/Config.h"
#import "Common/FileUtil.h"
#import "Common/IniFile.h"
#import "Common/MsgHandler.h"
#import "Common/StringUtil.h"

#import "ControllerSettingsUtils.h"

#import "Core/Config/MainSettings.h"
#import "Core/Config/UISettings.h"
#import "Core/ConfigManager.h"
#import "Core/Core.h"
#import "Core/HW/GCKeyboard.h"
#import "Core/HW/GCPad.h"
#import "Core/HW/Wiimote.h"
#import "Core/HW/WiimoteEmu/WiimoteEmu.h"
#import "Core/IOS/ES/ES.h"
#import "Core/IOS/IOS.h"
#import "Core/PowerPC/PowerPC.h"
#import "Core/State.h"

#import "DolphiniOS-Swift.h"

#import "DonationNoticeViewController.h"

#import <Firebase/Firebase.h>
#import <FirebaseAnalytics/FirebaseAnalytics.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>

#import "FastmemUtil.h"

#import "GameFileCacheHolder.h"

#import "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#import "InputCommon/ControllerEmu/ControlGroup/ControlGroup.h"
#import "InputCommon/ControllerEmu/ControlGroup/IMUCursor.h"
#import "InputCommon/ControllerInterface/ControllerInterface.h"
#import "InputCommon/ControllerInterface/Touch/ButtonManager.h"
#import "InputCommon/InputConfig.h"

#import "InvalidCpuCoreNoticeViewController.h"

#import "JitAcquisitionUtils.h"

#import "KilledBuildNoticeViewController.h"

#import <mach/mach.h>

#import "MainiOS.h"

#import <MetalKit/MetalKit.h>

#import "NonJailbrokenNoticeViewController.h"
#import "NoticeNavigationViewController.h"

#import "ReloadFailedNoticeViewController.h"
#import "ReloadStateNoticeViewController.h"

#import "UICommon/UICommon.h"

#import "UnofficialBuildNoticeViewController.h"

#import "UpdateNoticeViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application
    didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
  // Check the device compatibility
#ifndef SUPPRESS_UNSUPPORTED_DEVICE
  // Provide a way to bypass this check for debugging purposes
  NSString* bypass_flag_file = [[MainiOS getUserFolder] stringByAppendingPathComponent:@"bypass_unsupported_device"];
  if (![[NSFileManager defaultManager] fileExistsAtPath:bypass_flag_file])
  {
    // Check for GPU Family 3
    id<MTLDevice> metalDevice = MTLCreateSystemDefaultDevice();
    if (![metalDevice supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily3_v2])
    {
      // Show the incompatibilty warning
      self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
      self.window.rootViewController = [[UIViewController alloc] initWithNibName:@"UnsupportedDeviceNotice" bundle:nil];
      [self.window makeKeyAndVisible];
      
      return true;
    }
  }
#endif
  
#ifdef NONJAILBROKEN
  if (!HasJit())
  {
    // Show the incompatibilty warning
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UIViewController alloc] initWithNibName:@"OSTooNewNotice" bundle:nil];
    [self.window makeKeyAndVisible];
    
    return true;
  }
#endif
  
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"is_killed"])
  {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[KilledBuildNoticeViewController alloc] initWithNibName:@"KilledBuildNotice" bundle:nil];
    [self.window makeKeyAndVisible];
    
    return true;
  }
  
  // Default settings values should be set in DefaultPreferences.plist in the future
  NSURL *defaultPrefsFile = [[NSBundle mainBundle] URLForResource:@"DefaultPreferences" withExtension:@"plist"];
  NSDictionary *defaultPrefs = [NSDictionary dictionaryWithContentsOfURL:defaultPrefsFile];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPrefs];
  
  Common::RegisterStringTranslator([](const char* text) -> std::string {
    return FoundationToCppString(DOLocalizedString(CToFoundationString(text)));
  });
  
  [MainiOS applicationStart];
  
  // Mark the ROM folder as excluded from backups
  NSURL* rom_folder_url = [NSURL fileURLWithPath:[MainiOS getUserFolder]];
  [rom_folder_url setResourceValue:[NSNumber numberWithBool:true] forKey:NSURLIsExcludedFromBackupKey error:nil];
  
  // Create a UINavigationController for alerts
  NoticeNavigationViewController* nav_controller = [[NoticeNavigationViewController alloc] init];
  [nav_controller setNavigationBarHidden:true];
  
  if (@available(iOS 13, *))
  {
    [nav_controller setModalPresentationStyle:UIModalPresentationFormSheet];
    nav_controller.modalInPresentation = true;
  }
  else
  {
    [nav_controller setModalPresentationStyle:UIModalPresentationFullScreen];
  }
  
  // Check if the background save state exists
  std::string state_path = File::GetUserPath(D_STATESAVES_IDX) + "backgroundAuto.sav";
  if (File::Exists(state_path))
  {
    // Convert 2.x.x last game format to 3.x.x
    NSString* last_game_path = [[NSUserDefaults standardUserDefaults] stringForKey:@"last_game_path"];
    if (last_game_path != nil)
    {
      // Convert old into new
      [[NSUserDefaults standardUserDefaults] setObject:@{
        @"user_facing_name": [[NSUserDefaults standardUserDefaults] stringForKey:@"last_game_title"],
        @"boot_type" : @(DOLAutoStateBootTypeFile),
        @"location" : last_game_path,
        @"state_version": @([[NSUserDefaults standardUserDefaults] integerForKey:@"last_game_state_version"])
      } forKey:@"last_game_boot_info"];
      
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"last_game_title"];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"last_game_path"];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"last_game_state_version"];
    }
    
    NSDictionary* last_game_data = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"last_game_boot_info"];
    
    DOLReloadFailedReason reload_fail_reason = DOLReloadFailedReasonNone;
    if ([last_game_data[@"user_facing_name"] isEqualToString:@"Dummy"])
    {
      // Silently fail, we have no data but a state is present
      reload_fail_reason = DOLReloadFailedReasonSilent;
    }
    else if ([last_game_data[@"state_version"] integerValue] != State::GetVersion())
    {
      reload_fail_reason = DOLReloadFailedReasonOld;
    }
    else
    {
      DOLAutoStateBootType boot_type = (DOLAutoStateBootType)[last_game_data[@"boot_type"] integerValue];
      if (boot_type == DOLAutoStateBootTypeNand)
      {
        u64 title_id = [last_game_data[@"location"] unsignedLongLongValue];
        
        IOS::HLE::Kernel ios;
        const auto tmd = ios.GetES()->FindInstalledTMD(title_id);
        
        if (!tmd.IsValid())
        {
          reload_fail_reason = DOLReloadFailedReasonFileGone;
        }
      }
      else if (boot_type == DOLAutoStateBootTypeGCIPL)
      {
        DiscIO::Region region = static_cast<DiscIO::Region>([last_game_data[@"location"] integerValue]);
        std::string region_dir = USA_DIR; // default to NTSC-U
        if (region == DiscIO::Region::NTSC_J)
        {
          region_dir = JAP_DIR;
        }
        else if (region == DiscIO::Region::PAL)
        {
          region_dir = EUR_DIR;
        }
        
        if (!File::Exists(SConfig::GetInstance().GetBootROMPath(region_dir)))
        {
          reload_fail_reason = DOLReloadFailedReasonFileGone;
        }
      }
      else if (boot_type == DOLAutoStateBootTypeFile) // Game file
      {
        NSString* last_game_path = last_game_data[@"location"];
        if (!File::Exists(FoundationToCppString(last_game_path)))
        {
          reload_fail_reason = DOLReloadFailedReasonFileGone;
        }
      }
      else // ???
      {
        reload_fail_reason = DOLReloadFailedReasonSilent;
      }
    }
    
    if (reload_fail_reason == DOLReloadFailedReasonNone)
    {
      [nav_controller pushViewController:[[ReloadStateNoticeViewController alloc] initWithNibName:@"ReloadStateNotice" bundle:nil] animated:true];
    }
    else if (reload_fail_reason == DOLReloadFailedReasonSilent)
    {
      File::Delete(state_path);
    }
    else
    {
      ReloadFailedNoticeViewController* view_controller = [[ReloadFailedNoticeViewController alloc] initWithNibName:@"ReloadFailedNotice" bundle:nil];
      view_controller.m_reason = reload_fail_reason;
      
      [nav_controller pushViewController:view_controller animated:true];
    }
  }
  
  PowerPC::CPUCore correct_core;
#if !TARGET_OS_SIMULATOR
  correct_core = PowerPC::CPUCore::JITARM64;
#else
  correct_core = PowerPC::CPUCore::JIT64;
#endif
  
  // Get the number of launches
  NSInteger launch_times = [[NSUserDefaults standardUserDefaults] integerForKey:@"launch_times"];
  if (launch_times == 0)
  {
    SConfig::GetInstance().cpu_core = correct_core;
    Config::SetBaseOrCurrent(Config::MAIN_CPU_CORE, correct_core);
    
    Config::Save();
    SConfig::GetInstance().SaveSettings();
  }
  else
  {
    // Check the CPUCore type if necessary
    bool has_changed_core = [[NSUserDefaults standardUserDefaults] boolForKey:@"did_deliberately_change_cpu_core"];

    if (!has_changed_core)
    {
      const std::string config_path = File::GetUserPath(F_DOLPHINCONFIG_IDX);
      
      // Load Dolphin.ini
      IniFile dolphin_config;
      dolphin_config.Load(config_path);
      
      PowerPC::CPUCore core_type;
      dolphin_config.GetOrCreateSection("Core")->Get("CPUCore", &core_type);
      
      if (core_type != correct_core)
      {
        // Reset the CPUCore
        SConfig::GetInstance().cpu_core = correct_core;
        Config::SetBaseOrCurrent(Config::MAIN_CPU_CORE, correct_core);
        
        [nav_controller pushViewController:[[InvalidCpuCoreNoticeViewController alloc] initWithNibName:@"InvalidCpuCoreNotice" bundle:nil] animated:true];
      }
    }
  }
  
#ifdef NONJAILBROKEN
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"seen_njb_notice"])
  {
    [nav_controller pushViewController:[[NonJailbrokenNoticeViewController alloc] initWithNibName:@"NonJailbrokenNotice" bundle:nil] animated:true];
    
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"seen_njb_notice"];
  }
#endif
  
  if (launch_times == 0)
  {
    [nav_controller pushViewController:[[UnofficialBuildNoticeViewController alloc] initWithNibName:@"UnofficialBuildNotice" bundle:nil] animated:true];
  }

#ifdef ANALYTICS
  if (!SConfig::GetInstance().m_analytics_permission_asked)
  {
    [nav_controller pushViewController:[[AnalyticsNoticeViewController alloc] initWithNibName:@"AnalyticsNotice" bundle:nil] animated:true];
  }
#endif
  
  // Present if the navigation controller isn't empty
  if ([[nav_controller viewControllers] count] != 0)
  {
    [self.window makeKeyAndVisible];
    [self.window.rootViewController presentViewController:nav_controller animated:true completion:nil];
  }
  
  // Get the version string
  NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
  NSString* version_str = [NSString stringWithFormat:@"%@ (%@)", [info objectForKey:@"CFBundleShortVersionString"], [info objectForKey:@"CFBundleVersion"]];
  
  // Check for updates
#ifndef DEBUG
  NSURL* update_url = [NSURL URLWithString:@"https://dolphinios.oatmealdome.me/api/v2/update.json"];
  
  // Create en ephemeral session to avoid caching
  NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
  [[session dataTaskWithURL:update_url completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
    if (error != nil)
    {
      return;
    }
    
    // Deserialize the JSON
    NSDictionary* json_dict = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    
    NSString* dict_key;
#ifndef PATREON
#ifndef NONJAILBROKEN
      dict_key = @"public";
#else
      dict_key = @"public_njb";
#endif
#else
#ifndef NONJAILBROKEN
      dict_key = @"patreon";
#else
      dict_key = @"patreon_njb";
#endif
#endif
    
    NSArray* killed_array = json_dict[@"kbs"];
    if ([killed_array containsObject:version_str])
    {
      [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"is_killed"];
      [[NSUserDefaults standardUserDefaults] setObject:json_dict[dict_key][@"install_url"] forKey:@"killed_url"];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.rootViewController = [[UIViewController alloc] initWithNibName:@"KilledBuildNotice" bundle:nil];
        [self.window makeKeyAndVisible];
      });
    }
    
    NSDictionary* dict = json_dict[dict_key];
//    if (![dict[@"version"] isEqualToString:version_str])
 //   {
 //     dispatch_async(dispatch_get_main_queue(), ^{
 //       UpdateNoticeViewController* update_controller = [[UpdateNoticeViewController alloc] initWithNibName:@"UpdateNotice" bundle:nil];
 //       update_controller.m_update_json = dict;
 //
 //       if (self.window.rootViewController.presentedViewController != nav_controller)
 //       {
 //         [nav_controller setViewControllers:@[update_controller]];
 //         [self.window.rootViewController presentViewController:nav_controller animated:true completion:nil];
 //       }
 //       else
 //       {
 //         [nav_controller pushViewController:update_controller animated:true];
 //       }
 //     });
   // }
  }] resume];
#endif
  
  // Increment the launch count
  [[NSUserDefaults standardUserDefaults] setInteger:launch_times + 1 forKey:@"launch_times"];
  
  Config::SetBaseOrCurrent(Config::MAIN_USE_GAME_COVERS, true);
  
#ifdef NONJAILBROKEN
  SConfig::GetInstance().bFastmem = CanEnableFastmem();
#endif
  
  // Apply latest touchscreen controller configuration
  void(^update_input_config)(InputConfig*, bool) = ^(InputConfig* input_config, bool is_wii)
  {
    for (int i = 0; i < 4; i++)
    {
      ControllerEmu::EmulatedController* controller = input_config->GetController(i);
      if ([ControllerSettingsUtils IsControllerConnectedToTouchscreen:controller])
      {
        // This is terrible but we need to save some settings for consistency
        // TODO: the code for upright and sideways Wiimotes will break at some point!
        u32 selected_attachment = 0;
        bool imu_point_enabled = false;
        bool is_upright = false;
        bool is_sideways = false;
        if (is_wii)
        {
          ControllerEmu::Attachments* attachments = static_cast<ControllerEmu::Attachments*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::Attachments));
          selected_attachment = attachments->GetSelectedAttachment();
          
          ControllerEmu::IMUCursor* cursor = static_cast<ControllerEmu::IMUCursor*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::IMUPoint));
          imu_point_enabled = cursor->enabled;
          
          ControllerEmu::ControlGroup* options_group = static_cast<ControllerEmu::ControlGroup*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::Options));
          std::unique_ptr<ControllerEmu::NumericSettingBase>& upright_setting_base = options_group->numeric_settings[2];
          ControllerEmu::NumericSetting<bool>* upright_setting = static_cast<ControllerEmu::NumericSetting<bool>*>(upright_setting_base.get());
          is_upright = upright_setting->GetValue();
          
          std::unique_ptr<ControllerEmu::NumericSettingBase>& sideways_setting_base = options_group->numeric_settings[3];
          ControllerEmu::NumericSetting<bool>* sideways_setting = static_cast<ControllerEmu::NumericSetting<bool>*>(sideways_setting_base.get());
          is_sideways = sideways_setting->GetValue();
        }
        
        [ControllerSettingsUtils LoadDefaultProfileOnController:controller is_wii:is_wii type:@"Touch"];
        
        if (is_wii)
        {
          ControllerEmu::Attachments* attachments = static_cast<ControllerEmu::Attachments*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::Attachments));
          attachments->SetSelectedAttachment(selected_attachment);
          
          ControllerEmu::IMUCursor* cursor = static_cast<ControllerEmu::IMUCursor*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::IMUPoint));
          cursor->enabled = imu_point_enabled;
          
          ControllerEmu::ControlGroup* options_group = static_cast<ControllerEmu::ControlGroup*>(Wiimote::GetWiimoteGroup(i, WiimoteEmu::WiimoteGroup::Options));
          
          std::unique_ptr<ControllerEmu::NumericSettingBase>& upright_setting_base = options_group->numeric_settings[2];
          ControllerEmu::NumericSetting<bool>* upright_setting = static_cast<ControllerEmu::NumericSetting<bool>*>(upright_setting_base.get());
          upright_setting->SetValue(is_upright);
          
          std::unique_ptr<ControllerEmu::NumericSettingBase>& sideways_setting_base = options_group->numeric_settings[3];
          ControllerEmu::NumericSetting<bool>* sideways_setting = static_cast<ControllerEmu::NumericSetting<bool>*>(sideways_setting_base.get());
          sideways_setting->SetValue(is_sideways);
        }
      }
    }
    
    input_config->SaveConfig();
  };
  
  const NSInteger latest_tscontroller_config_version = 1;
  
  if ([[NSUserDefaults standardUserDefaults] integerForKey:@"tscontroller_config_version"] != latest_tscontroller_config_version)
  {
    update_input_config(Pad::GetConfig(), false);
    update_input_config(Wiimote::GetConfig(), true);
    
    [[NSUserDefaults standardUserDefaults] setInteger:latest_tscontroller_config_version forKey:@"tscontroller_config_version"];
  }

  [[GameFileCacheHolder sharedInstance] scanSoftwareFolder];

#ifdef ANALYTICS
  [FIRApp configure];
#if !defined(DEBUG) && !TARGET_OS_SIMULATOR
  [FIRAnalytics setAnalyticsCollectionEnabled:SConfig::GetInstance().m_analytics_enabled];
  [[FIRCrashlytics crashlytics] setCrashlyticsCollectionEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"crash_reporting_enabled"]];
#else
  [FIRAnalytics setAnalyticsCollectionEnabled:false];
  [[FIRCrashlytics crashlytics] setCrashlyticsCollectionEnabled:false];
#endif
#endif
  
  NSString* last_version = [[NSUserDefaults standardUserDefaults] stringForKey:@"last_version"];
  if (![last_version isEqualToString:version_str])
  {
    NSString* app_type;
#ifndef NONJAILBROKEN
    app_type = @"jailbroken";
#else
    app_type = @"non-jailbroken";
#endif

#ifdef ANALYTICS
    [FIRAnalytics logEventWithName:@"version_start" parameters:@{
      @"type" : app_type,
      @"version" : version_str
    }];
#endif
    
    [[NSUserDefaults standardUserDefaults] setObject:version_str forKey:@"last_version"];
  }
 
  return YES;
}

- (void)applicationWillTerminate:(UIApplication*)application
{
  [AppDelegate Shutdown];
}

- (void)applicationDidBecomeActive:(UIApplication*)application
{
  if (Core::IsRunning())
  {
    Core::SetState(Core::State::Running);
  }

#ifdef ANALYTICS
  [[FIRCrashlytics crashlytics] setCustomValue:@"active" forKey:@"app-state"];
#endif
}

- (void)applicationWillResignActive:(UIApplication*)application
{
  if (Core::IsRunning())
  {
    Core::SetState(Core::State::Paused);
  }
  
  // Write out the configuration in case we don't get a chance later
  Config::Save();
  SConfig::GetInstance().SaveSettings();

#ifdef ANALYTICS
  [[FIRCrashlytics crashlytics] setCustomValue:@"inactive" forKey:@"app-state"];
#endif
}

- (void)applicationDidEnterBackground:(UIApplication*)application
{
  std::string save_state_dir = File::GetUserPath(D_STATESAVES_IDX);
  std::string temp_path = save_state_dir + "tempBgAuto.sav";
  std::string real_path = save_state_dir + "backgroundAuto.sav";
  
  self.m_save_state_task = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"Write Automatic Save State" expirationHandler:^{
    // Delete the save state - it's probably corrupt
    File::Delete(temp_path);
    File::Delete(real_path);
    
    [[UIApplication sharedApplication] endBackgroundTask:self.m_save_state_task];
    self.m_save_state_task = UIBackgroundTaskInvalid;
  }];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    if (Core::IsRunning())
    {
      File::Delete(temp_path);
      File::Delete(real_path);
      
      // Save out a save state
      State::SaveAs(temp_path, true);
    }
    
    File::Rename(temp_path, real_path);

    [[UIApplication sharedApplication] endBackgroundTask:self.m_save_state_task];
    self.m_save_state_task = UIBackgroundTaskInvalid;
  });
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
  // Write out the configuration
  Config::Save();
  SConfig::GetInstance().SaveSettings();
  
  // Create a "background" save state just in case
  std::string state_path = File::GetUserPath(D_STATESAVES_IDX) + "backgroundAuto.sav";
  File::Delete(state_path);
  
  if (Core::IsRunning())
  {
    State::SaveAs(state_path, true);
  }
}

- (BOOL)application:(UIApplication*)app openURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id>*)options
{
  [MainiOS importFiles:[NSSet setWithObject:url]];
  
  return YES;
}

+ (void)Shutdown
{
  if (Core::IsRunning())
  {
    Core::Stop();
    
    // Spin while Core stops
    while (Core::GetState() != Core::State::Uninitialized);
  }
  
  [[TCDeviceMotion shared] stopMotionUpdates];
  ButtonManager::Shutdown();
  Pad::Shutdown();
  Keyboard::Shutdown();
  Wiimote::Shutdown();
  g_controller_interface.Shutdown();
  
  Config::Save();
  SConfig::GetInstance().SaveSettings();
  
  Core::Shutdown();
  UICommon::Shutdown();
  
#ifdef NONJAILBROKEN
  if (HasJitWithPTrace())
  {
    exit(0);
  }
#endif
}

@end
