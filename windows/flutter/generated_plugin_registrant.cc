//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <restart_app/restart_app_plugin_c_api.h>
#include <screen_brightness_windows/screen_brightness_windows_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <media_kit_video/media_kit_video_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  RestartAppPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("RestartAppPluginCApi"));
  ScreenBrightnessWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenBrightnessWindowsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
}
