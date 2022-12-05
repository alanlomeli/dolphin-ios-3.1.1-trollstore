// Copyright 2008 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include "Common/Thread.h"
#include "Common/CommonFuncs.h"
#include "Common/CommonTypes.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#ifdef __APPLE__
#include <mach/mach.h>
#elif defined BSD4_4 || defined __FreeBSD__ || defined __OpenBSD__
#include <pthread_np.h>
#elif defined __HAIKU__
#include <OS.h>
#endif

#ifdef USE_VTUNE
#include <ittnotify.h>
#pragma comment(lib, "libittnotify.lib")
#endif

namespace Common
{
int CurrentThreadId()
{
#ifdef _WIN32
  return GetCurrentThreadId();
#elif defined __APPLE__
  return mach_thread_self();
#else
  return 0;
#endif
}

#ifdef _WIN32

void SetThreadAffinity(std::thread::native_handle_type thread, u32 mask)
{
  SetThreadAffinityMask(thread, mask);
}

void SetCurrentThreadAffinity(u32 mask)
{
  SetThreadAffinityMask(GetCurrentThread(), mask);
}

// Supporting functions
void SleepCurrentThread(int ms)
{
  Sleep(ms);
}

void SwitchCurrentThread()
{
  SwitchToThread();
}

// Sets the debugger-visible name of the current thread.
// Uses trick documented in:
// https://docs.microsoft.com/en-us/visualstudio/debugger/how-to-set-a-thread-name-in-native-code
void SetCurrentThreadName(const char* szThreadName)
{
  static const DWORD MS_VC_EXCEPTION = 0x406D1388;

#pragma pack(push, 8)
  struct THREADNAME_INFO
  {
    DWORD dwType;      // must be 0x1000
    LPCSTR szName;     // pointer to name (in user addr space)
    DWORD dwThreadID;  // thread ID (-1=caller thread)
    DWORD dwFlags;     // reserved for future use, must be zero
  } info;
#pragma pack(pop)

  info.dwType = 0x1000;
  info.szName = szThreadName;
  info.dwThreadID = static_cast<DWORD>(-1);
  info.dwFlags = 0;

  __try
  {
    RaiseException(MS_VC_EXCEPTION, 0, sizeof(info) / sizeof(ULONG_PTR), (ULONG_PTR*)&info);
  }
  __except (EXCEPTION_CONTINUE_EXECUTION)
  {
  }
}

#else  // !WIN32, so must be POSIX threads

void SetThreadAffinity(std::thread::native_handle_type thread, u32 mask)
{
#ifdef __APPLE__
  thread_policy_set(pthread_mach_thread_np(thread), THREAD_AFFINITY_POLICY, (integer_t*)&mask, 1);
#elif (defined __linux__ || defined BSD4_4 || defined __FreeBSD__) && !(defined ANDROID)
#ifdef __FreeBSD__
  cpuset_t cpu_set;
#else
  cpu_set_t cpu_set;
#endif
  CPU_ZERO(&cpu_set);

  for (int i = 0; i != sizeof(mask) * 8; ++i)
    if ((mask >> i) & 1)
      CPU_SET(i, &cpu_set);

  pthread_setaffinity_np(thread, sizeof(cpu_set), &cpu_set);
#endif
}

void SetCurrentThreadAffinity(u32 mask)
{
  SetThreadAffinity(pthread_self(), mask);
}

void SleepCurrentThread(int ms)
{
  usleep(1000 * ms);
}

void SwitchCurrentThread()
{
  usleep(1000 * 1);
}

void SetCurrentThreadName(const char* szThreadName)
{
#ifdef __APPLE__
  pthread_setname_np(szThreadName);
#elif defined __FreeBSD__ || defined __OpenBSD__
  pthread_set_name_np(pthread_self(), szThreadName);
#elif defined __HAIKU__
  rename_thread(find_thread(nullptr), szThreadName);
#else
  // linux doesn't allow to set more than 16 bytes, including \0.
  pthread_setname_np(pthread_self(), std::string(szThreadName).substr(0, 15).c_str());
#endif
#ifdef USE_VTUNE
  // VTune uses OS thread names by default but probably supports longer names when set via its own
  // API.
  __itt_thread_set_name(szThreadName);
#endif
}

#endif

}  // namespace Common
