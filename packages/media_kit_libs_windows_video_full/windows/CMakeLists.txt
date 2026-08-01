# This file is a fork of media_kit_libs_windows_video.
#
# It downloads a FULL libmpv build from zhongfly/mpv-winbuild (LGPL V3 variant)
# which includes libavfilter support (yadif, bwdif, w3fdif, nnedi deinterlace
# filters) and msg-level property support.
#
# V3 variant: requires CPU not older than Intel Haswell or AMD Excavator
# (includes AVX2, BMI1, BMI2, FMA instructions for better performance).
#
# The original media_kit libmpv build is a minimal/stripped build that lacks
# vf filter support and msg-level property.
#
# Auto-update: This script queries the GitHub API at configure time to find
# the latest mpv-dev-lgpl-x86_64-v3 release. If the API is unreachable, it
# falls back to a hardcoded URL. To force a refresh, delete:
#   build/windows/x64/zhongfly_releases.json

cmake_minimum_required(VERSION 3.31)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------
# download_and_verify: supports both SHA256 (64 hex chars) and MD5 (32 hex chars)
function(download_and_verify url hash locationForArchive)
  if(EXISTS "${locationForArchive}")
    string(LENGTH "${hash}" HASH_LEN)
    if(HASH_LEN EQUAL 64)
      file(SHA256 "${locationForArchive}" COMPUTED_HASH)
    elseif(HASH_LEN EQUAL 32)
      file(MD5 "${locationForArchive}" COMPUTED_HASH)
    else()
      set(COMPUTED_HASH "${hash}")
    endif()

    if(NOT hash STREQUAL COMPUTED_HASH)
      file(REMOVE "${locationForArchive}")
      message(STATUS "Hash mismatch. File deleted.")
    endif()
  endif()

  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(DOWNLOAD "${url}" "${locationForArchive}"
      TIMEOUT 300
      STATUS DOWNLOAD_STATUS
    )
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
      message(FATAL_ERROR "Download failed: ${DOWNLOAD_STATUS}")
    endif()
    message(STATUS "Downloaded archive to ${locationForArchive}.")

    string(LENGTH "${hash}" HASH_LEN)
    if(HASH_LEN EQUAL 64)
      file(SHA256 "${locationForArchive}" COMPUTED_HASH)
    elseif(HASH_LEN EQUAL 32)
      file(MD5 "${locationForArchive}" COMPUTED_HASH)
    else()
      set(COMPUTED_HASH "${hash}")
    endif()

    if(hash STREQUAL COMPUTED_HASH)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(check_directory_exists_and_not_empty dir result_var)
  if(EXISTS "${dir}")
    file(GLOB dir_contents "${dir}/*")
    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
      message(STATUS "Directory ${dir} exists but is empty!")
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
    message(STATUS "Directory ${dir} does not exist!")
  endif()
endfunction()

# ------------------------------------------------------------------------------
# Query GitHub API for the latest mpv-dev-lgpl-x86_64-v3 release.
# Uses string(JSON) for reliable parsing (requires CMake 3.19+).
# Falls back to hardcoded values if the API is unreachable or parsing fails.
function(find_latest_libmpv_v3 out_url out_sha256)
  # Hardcoded fallback (updated: 2026-07-31)
  set(FALLBACK_URL "https://github.com/zhongfly/mpv-winbuild/releases/download/2026-07-31-1d15686142/mpv-dev-lgpl-x86_64-v3-20260731-git-1d15686142.7z")
  set(FALLBACK_SHA256 "c75aa6f15ef56b3e62a9803bc420c5f38dc0db5106f56de3e26db0e9d4d9e895")

  set(API_URL "https://api.github.com/repos/zhongfly/mpv-winbuild/releases?per_page=10")
  set(API_FILE "${CMAKE_BINARY_DIR}/zhongfly_releases.json")

  # Download API response (cached in build dir, delete to force refresh)
  if(NOT EXISTS "${API_FILE}")
    message(STATUS "Querying zhongfly/mpv-winbuild API for latest mpv-dev-lgpl-x86_64-v3...")
    file(DOWNLOAD "${API_URL}" "${API_FILE}"
      HTTPHEADER "User-Agent: cmake-media-kit-fork"
      TIMEOUT 30
      STATUS API_STATUS
    )
    list(GET API_STATUS 0 API_STATUS_CODE)
    if(NOT API_STATUS_CODE EQUAL 0)
      message(STATUS "GitHub API unreachable (${API_STATUS}), using fallback URL")
      file(REMOVE "${API_FILE}")
      set(${out_url} "${FALLBACK_URL}" PARENT_SCOPE)
      set(${out_sha256} "${FALLBACK_SHA256}" PARENT_SCOPE)
      return()
    endif()
  endif()

  file(READ "${API_FILE}" API_CONTENT)

  # Parse JSON array using string(JSON) — reliable, no regex hacks
  string(JSON ARRAY_LEN ERROR_VARIABLE JSON_ERR LENGTH "${API_CONTENT}")
  if(JSON_ERR)
    message(STATUS "JSON parse error: ${JSON_ERR}, using fallback URL")
    set(${out_url} "${FALLBACK_URL}" PARENT_SCOPE)
    set(${out_sha256} "${FALLBACK_SHA256}" PARENT_SCOPE)
    return()
  endif()

  set(FOUND_URL "")
  set(FOUND_SHA256 "")
  math(EXPR LAST_IDX "${ARRAY_LEN} - 1")

  foreach(i RANGE ${LAST_IDX})
    if(NOT "${FOUND_URL}" STREQUAL "")
      break()
    endif()

    # Get release at index i
    string(JSON RELEASE_JSON ERROR_VARIABLE ERR GET "${API_CONTENT}" ${i})
    if(ERR)
      continue()
    endif()

    # Get assets array
    string(JSON ASSETS_JSON ERROR_VARIABLE ERR GET "${RELEASE_JSON}" "assets")
    if(ERR)
      continue()
    endif()

    # Get assets length
    string(JSON ASSETS_LEN ERROR_VARIABLE ERR LENGTH "${ASSETS_JSON}")
    if(ERR)
      continue()
    endif()

    # Iterate through assets to find mpv-dev-lgpl-x86_64-v3-*.7z
    math(EXPR ASSETS_LAST "${ASSETS_LEN} - 1")
    foreach(j RANGE ${ASSETS_LAST})
      string(JSON ASSET_NAME ERROR_VARIABLE ERR GET "${ASSETS_JSON}" ${j} "name")
      if(ERR)
        continue()
      endif()

      if(ASSET_NAME MATCHES "^mpv-dev-lgpl-x86_64-v3-.*\\.7z$")
        string(JSON ASSET_URL ERROR_VARIABLE ERR GET "${ASSETS_JSON}" ${j} "browser_download_url")
        if(ERR)
          continue()
        endif()
        string(JSON ASSET_DIGEST ERROR_VARIABLE ERR GET "${ASSETS_JSON}" ${j} "digest")
        if(ERR)
          set(ASSET_DIGEST "")
        endif()
        # Strip "sha256:" prefix
        string(REGEX REPLACE "^sha256:" "" FOUND_SHA256 "${ASSET_DIGEST}")
        set(FOUND_URL "${ASSET_URL}")
        message(STATUS "Found latest libmpv V3: ${ASSET_NAME}")
        break()
      endif()
    endforeach()
  endforeach()

  if("${FOUND_URL}" STREQUAL "")
    message(STATUS "mpv-dev-lgpl-x86_64-v3 not found in API response, using fallback URL")
    set(${out_url} "${FALLBACK_URL}" PARENT_SCOPE)
    set(${out_sha256} "${FALLBACK_SHA256}" PARENT_SCOPE)
  else()
    set(${out_url} "${FOUND_URL}" PARENT_SCOPE)
    set(${out_sha256} "${FOUND_SHA256}" PARENT_SCOPE)
  endif()
endfunction()

# ------------------------------------------------------------------------------
# Resolve libmpv download URL and SHA256 (dynamic via API or fallback)
find_latest_libmpv_v3(LIBMPV_URL LIBMPV_SHA256)

# Extract filename from URL for the local archive path
string(REGEX REPLACE ".*/" "" LIBMPV_FILENAME "${LIBMPV_URL}")
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV_FILENAME}")
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")

download_and_verify(
  ${LIBMPV_URL}
  ${LIBMPV_SHA256}
  ${LIBMPV_ARCHIVE}
)

# If archive doesn't exist (new URL from API → new filename), clear stale extraction
if(NOT EXISTS "${LIBMPV_ARCHIVE}")
  file(REMOVE_RECURSE "${LIBMPV_SRC}")
endif()

check_directory_exists_and_not_empty(${LIBMPV_SRC} LIBMPV_SRC_VALID)

# Extract the libmpv archive.
if(NOT LIBMPV_SRC_VALID)
  message(STATUS "Extracting ${LIBMPV_FILENAME}...")
  make_directory("${LIBMPV_SRC}")
  add_custom_target("${PROJECT_NAME}_LIBMPV_EXTRACT" ALL)
  add_custom_command(
    TARGET "${PROJECT_NAME}_LIBMPV_EXTRACT"
    POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${LIBMPV_ARCHIVE}\""
    COMMAND xcopy "\"${LIBMPV_SRC}/include/mpv\"" "\"${LIBMPV_SRC}/mpv\"" /E /H /C /I
    COMMAND rmdir "\"${LIBMPV_SRC}/include\"" /S /Q
    COMMAND ren "\"${LIBMPV_SRC}/mpv\"" "\"include\""
    WORKING_DIRECTORY "${LIBMPV_SRC}"
  )
endif()

# ------------------------------------------------------------------------------

# ANGLE archive containing the pre-built shared libraries & headers.
set(ANGLE "ANGLE.7z")
set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")

set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

download_and_verify(
  ${ANGLE_URL}
  ${ANGLE_MD5}
  ${ANGLE_ARCHIVE}
)

check_directory_exists_and_not_empty(${ANGLE_SRC} ANGLE_SRC_VALID)

if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting ${ANGLE}...")
  make_directory("${ANGLE_SRC}")
  add_custom_target("${PROJECT_NAME}_ANGLE_EXTRACT" ALL)
  add_custom_command(
    TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
    POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${ANGLE_ARCHIVE}\""
    WORKING_DIRECTORY "${ANGLE_SRC}"
  )
endif()

# ------------------------------------------------------------------------------
set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
