// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#define PT_TRACE_ME 0
#import <dlfcn.h>

#import <spawn.h>
#import "DebuggerUtils.h"
#import "EntitlementUtils.h"

static bool s_has_jit = false;
static bool s_has_jit_with_ptrace = false;
extern int ptrace(int a, int b, void* c, int d);
extern char** environ;

void AcquireJit(char* argv[])
{
  //if (IsProcessDebugged())
  //{
   // s_has_jit = true;
    //return;
  //}
  
  if (@available(iOS 14.2, *))
  {
    // Query MobileGestalt for the CPU architecture
    void* gestalt_handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
    if (!gestalt_handle)
    {
      NSLog(@"Failed to load MobileGestalt: %s", dlerror());
      abort();
    }
    
    typedef NSString* (*MGCopyAnswer_ptr)(NSString*);
    MGCopyAnswer_ptr MGCopyAnswer = (MGCopyAnswer_ptr)dlsym(gestalt_handle, "MGCopyAnswer");
    
    char* dlsym_error = dlerror();
    if (dlsym_error)
    {
      NSLog(@"Failed to load from MobileGestalt: %s", dlsym_error);
      abort();
    }
    
    NSString* cpu_architecture = MGCopyAnswer(@"k7QIBwZJJOVw+Sej/8h8VA"); // "CPUArchitecture"
    bool is_arm64e = [cpu_architecture isEqualToString:@"arm64e"];
    
    if (is_arm64e && HasGetTaskAllowEntitlement())
    {
        int ret; pid_t pid;
          if (getppid() != 1) {
              ret = ptrace(PT_TRACE_ME, 0, NULL, 0);
              NSLog(@"child: ptrace(PT_TRACE_ME) %d", ret);
              exit(ret);
          }
      ret = posix_spawnp(&pid, argv[0], NULL, NULL, (void *)argv, (void *)environ);
    
    s_has_jit_with_ptrace = true;
  
  s_has_jit = true;
      return;
    }
  }
  
#if TARGET_OS_SIMULATOR
  s_has_jit = true;
#elif defined(NONJAILBROKEN)
  if (@available(iOS 14, *))
  {
    // can't do anything here
  }
  else
  {
    SetProcessDebuggedWithPTrace();
    
    s_has_jit = true;
    s_has_jit_with_ptrace = true;
  }
#else // jailbroken
  // Check for jailbreakd (Chimera)

    SetProcessDebuggedWithPTrace();
    
    s_has_jit_with_ptrace = true;
  
  s_has_jit = true;
#endif
}

bool HasJit()
{
  return s_has_jit;
}

bool HasJitWithPTrace()
{
  return s_has_jit_with_ptrace;
}
