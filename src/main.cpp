#include <XPLMDisplay.h>
#include <XPLMPlugin.h>
#include <XPLMUtilities.h>
#include <cstring>

static constexpr char kPluginName[] = "MyPlugin";
static constexpr char kPluginSig[] = "com.example.myplugin";
static constexpr char kPluginDesc[] = "X-Plane plugin scaffold with ImGui";

PLUGIN_API int XPluginStart(char* outName, char* outSig, char* outDesc) {
  std::strncpy(outName, kPluginName, 256);
  std::strncpy(outSig, kPluginSig, 256);
  std::strncpy(outDesc, kPluginDesc, 256);

  XPLMDebugString("MyPlugin: started\n");
  return 1;
}

PLUGIN_API void XPluginStop() {
  XPLMDebugString("MyPlugin: stopped\n");
}

PLUGIN_API int XPluginEnable() {
  XPLMDebugString("MyPlugin: enabled\n");
  return 1;
}

PLUGIN_API void XPluginDisable() {
  XPLMDebugString("MyPlugin: disabled\n");
}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID from, int msg, void* param) {
  // Handle X-Plane messages here
}
