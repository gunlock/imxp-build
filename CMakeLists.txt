cmake_minimum_required(VERSION 3.25)

#----------------------------------------------------------------------------
# Customize plugin name, plugin version, and ImGui font
#   project() function sets the cmake variable ${PROJECT_NAME} to 
#   user defined ${PLUGIN_NAME} and the cmake variable ${PROJECT_VERSION} 
#   to user defined ${PLUGIN_VERSION}

#----------------------------------------------------------------------------
set(PLUGIN_NAME "Flymate")
set(PLUGIN_VERSION "0.1.0")
set(PLUGIN_SIGNATURE "com.${PLUGIN_NAME}")
set(PLUGIN_DESC "${PLUGIN_NAME} v${PLUGIN_VERSION}")
set(IMGUI_FONT "Roboto-Medium.ttf")

project(${PLUGIN_NAME} VERSION ${PLUGIN_VERSION} LANGUAGES C CXX)

string(TOLOWER "${PROJECT_NAME}" PROJECT_NAME_LOWER)
set(DOCKER_IMAGE "${PROJECT_NAME_LOWER}-build")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Export compile_commands.json for editor tooling.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(SRC_FILES
    src/main.cpp
)

# generated configuration file
configure_file(
    src/config.h.in
    "${PROJECT_BINARY_DIR}/generated/config.h"
)

include(FetchContent)

# ---------------------------------------------------------------------------
# X-Plane SDK 4.3.0
# ---------------------------------------------------------------------------
FetchContent_Declare(
    xpsdk
    URL      https://developer.x-plane.com/wp-content/plugins/code-sample-generation/sdk_zip_files/XPSDK430.zip
    URL_HASH SHA256=b9875ab27b593927b4f9b3e0ddfffe7401ee5dce6d86b50aea0da65f70ff7816
)
FetchContent_MakeAvailable(xpsdk)

set(XPSDK_ROOT "${xpsdk_SOURCE_DIR}")

# ---------------------------------------------------------------------------
# Dear ImGui v1.92.6
# ---------------------------------------------------------------------------
FetchContent_Declare(
    imgui
    URL      https://github.com/ocornut/imgui/archive/refs/tags/v1.92.6.tar.gz
    URL_HASH SHA256=5b17c01f69545bde732b14936d89ce0f508adb83e8b56fa82448371845172bc3
)
FetchContent_MakeAvailable(imgui)

set(IMGUI_DIR "${imgui_SOURCE_DIR}")

# ---------------------------------------------------------------------------
# Plugin target
# ---------------------------------------------------------------------------
add_library(${PROJECT_NAME} SHARED
    ${SRC_FILES}
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/backends/imgui_impl_opengl3.cpp
)

target_include_directories(${PROJECT_NAME} PRIVATE
    src
    ${PROJECT_BINARY_DIR}/generated
    ${XPSDK_ROOT}/CHeaders/XPLM
    ${XPSDK_ROOT}/CHeaders/Widgets
    ${IMGUI_DIR}
)

# X-Plane SDK version defines (XP11+ compatibility).
target_compile_definitions(${PROJECT_NAME} PRIVATE
    XPLM200
    XPLM210
    XPLM300
    XPLM301
    ${PROJECT_NAME}_VERSION="${PROJECT_VERSION}"
)

# Prevent the compiler from registering destructors for static C++ objects
# via __cxa_atexit. When X-Plane unloads the plugin (dlclose), those
# destructors can reference code/data that has already been unmapped,
# causing a crash on shutdown or plugin reload.
target_compile_options(${PROJECT_NAME} PRIVATE -fno-c++-static-destructors)

# Mark the shared library as non-deletable so dlclose() skips __cxa_finalize.
# This is needed because linked libraries may register their own atexit
# destructors that we can't control with compile flags.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_options(${PROJECT_NAME} PRIVATE "LINKER:-z,nodelete")
endif()

# ---------------------------------------------------------------------------
# Platform-specific configuration
# ---------------------------------------------------------------------------
if(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE IBM=1)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        ${XPSDK_ROOT}/Libraries/Win/XPLM_64.lib
        ${XPSDK_ROOT}/Libraries/Win/XPWidgets_64.lib
        opengl32
    )
elseif(APPLE)
    target_compile_definitions(${PROJECT_NAME} PRIVATE APL=1)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-F${XPSDK_ROOT}/Libraries/Mac"
        "-framework XPLM"
        "-framework XPWidgets"
    )
else()
    # Linux: symbols resolved at runtime by X-Plane.
    target_compile_definitions(${PROJECT_NAME} PRIVATE LIN=1)
    target_link_options(${PROJECT_NAME} PRIVATE -nodefaultlibs)
endif()

# Output as .xpl regardless of platform.
# Place the binary in the X-Plane plugin directory layout:
#   ${PROJECT_NAME}/{lin_x64,win_x64,mac_x64}/${PROJECT_NAME}.xpl
if(WIN32)
    set(PLUGIN_PLATFORM_DIR "win_x64")
elseif(APPLE)
    set(PLUGIN_PLATFORM_DIR "mac_x64")
else()
    set(PLUGIN_PLATFORM_DIR "lin_x64")
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    PREFIX ""
    SUFFIX ".xpl"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${PLUGIN_PLATFORM_DIR}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${PROJECT_NAME}/${PLUGIN_PLATFORM_DIR}"
)

# ---------------------------------------------------------------------------
# Custom targets for dev workflow: build -> deploy -> install-plugin
#
# Local builds use Docker with zig c++ (targeting linux-x64 only) so that
# dev builds match the deployment compiler and ABI.
# ---------------------------------------------------------------------------
set(DOCKER_BUILD_XPL "${CMAKE_SOURCE_DIR}/build/docker/linux-x86/${PROJECT_NAME}/lin_x64/${PROJECT_NAME}.xpl")
set(DEPLOY_DIR "${CMAKE_BINARY_DIR}/deploy/${PROJECT_NAME}/lin_x64")
set(XPLANE_PLUGIN_DIR "" CACHE PATH "Path to X-Plane plugins directory (e.g. .../X-Plane 11/Resources/plugins)")

# build: compile the .xpl for linux-x64 via Docker (zig c++)
add_custom_target(build
    COMMAND docker build -q -t ${DOCKER_IMAGE} "${CMAKE_SOURCE_DIR}"
    COMMAND docker run --rm -v "${CMAKE_SOURCE_DIR}:/src" ${DOCKER_IMAGE} cmake --preset linux-x86
    COMMAND docker run --rm -v "${CMAKE_SOURCE_DIR}:/src" ${DOCKER_IMAGE} cmake --build --preset linux-x86
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building ${PROJECT_NAME} linux-x64 via Docker (zig c++)"
    USES_TERMINAL
)

# deploy: assemble plugin directory layout under build/deploy/
add_custom_target(deploy
    COMMAND ${CMAKE_COMMAND} -E make_directory "${DEPLOY_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "${DOCKER_BUILD_XPL}" "${DEPLOY_DIR}/"
    COMMAND ${CMAKE_COMMAND} -E copy "${IMGUI_DIR}/misc/fonts/${IMGUI_FONT}" "${CMAKE_BINARY_DIR}/deploy/${PROJECT_NAME}/"
    COMMENT "Deploying ${PROJECT_NAME}.xpl to ${DEPLOY_DIR}"
)
add_dependencies(deploy build)

# install-plugin: copy deployed plugin to X-Plane plugins directory
if(XPLANE_PLUGIN_DIR)
    add_custom_target(install-plugin
        COMMAND ${CMAKE_COMMAND} -E make_directory "${XPLANE_PLUGIN_DIR}/${PROJECT_NAME}/lin_x64"
        COMMAND ${CMAKE_COMMAND} -E copy "${DEPLOY_DIR}/${PROJECT_NAME}.xpl" "${XPLANE_PLUGIN_DIR}/${PROJECT_NAME}/lin_x64/"
        COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_BINARY_DIR}/deploy/${PROJECT_NAME}/${IMGUI_FONT}" "${XPLANE_PLUGIN_DIR}/${PROJECT_NAME}/"
        COMMENT "Installing ${PROJECT_NAME}.xpl to ${XPLANE_PLUGIN_DIR}/${PROJECT_NAME}/lin_x64"
    )
else()
    add_custom_target(install-plugin
        COMMAND ${CMAKE_COMMAND} -E echo "ERROR: XPLANE_PLUGIN_DIR is not set. Set it in CMakeUserPresets.json or pass -DXPLANE_PLUGIN_DIR=..."
        COMMAND ${CMAKE_COMMAND} -E false
    )
endif()
add_dependencies(install-plugin deploy)

# docker-deploy: cross-compile all platforms via Docker and produce release zip
add_custom_target(docker-deploy
    COMMAND docker build -t ${DOCKER_IMAGE} "${CMAKE_SOURCE_DIR}"
    COMMAND docker run --rm -v "${CMAKE_SOURCE_DIR}:/src" ${DOCKER_IMAGE} scripts/build-all.sh ${PROJECT_NAME}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building release for all platforms via Docker"
    USES_TERMINAL
)

# docker-deploy-nomacos: cross-compile Linux and Windows only via Docker
add_custom_target(docker-deploy-nomacos
    COMMAND docker build -t ${DOCKER_IMAGE} "${CMAKE_SOURCE_DIR}"
    COMMAND docker run --rm -v "${CMAKE_SOURCE_DIR}:/src" ${DOCKER_IMAGE} scripts/build-nomacos.sh ${PROJECT_NAME}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building release for Linux and Windows via Docker (no macOS)"
    USES_TERMINAL
)

# docker-rebuild: rebuild the Docker build image
add_custom_target(docker-rebuild
    COMMAND docker build -t ${DOCKER_IMAGE} "${CMAKE_SOURCE_DIR}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Rebuilding Docker image ${DOCKER_IMAGE} from Dockerfile"
    USES_TERMINAL
)

# docker-clean-image: remove the Docker build image
add_custom_target(docker-clean-image
    COMMAND docker rmi ${DOCKER_IMAGE}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Removing Docker image ${DOCKER_IMAGE}"
)
