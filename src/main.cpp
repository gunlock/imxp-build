#include "config.h"
#include <XPLMDisplay.h>
#include <XPLMPlugin.h>
#include <XPLMUtilities.h>
#include <cstring>

PLUGIN_API int XPluginStart(char* outName, char* outSig, char* outDesc) {
  std::strncpy(outName, PLUGIN_NAME, 256);
  std::strncpy(outSig, PLUGIN_SIGNATURE, 256);
  std::strncpy(outDesc, PLUGIN_DESC, 256);

  XPLMDebugString(PLUGIN_NAME ": started\n");
  return 1;
}

PLUGIN_API void XPluginStop() {
  XPLMDebugString(PLUGIN_NAME ": stopped\n");
}

PLUGIN_API int XPluginEnable() {
  XPLMDebugString(PLUGIN_NAME ": enabled\n");
  return 1;
}

PLUGIN_API void XPluginDisable() {
  XPLMDebugString(PLUGIN_NAME ": disabled\n");
}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID from, int msg, void* param) {
  // Handle X-Plane messages here
}
