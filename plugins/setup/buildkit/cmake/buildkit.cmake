# buildkit.cmake — Build Go core as part of the native Linux/Windows build
#
# Include this from a plugin's CMakeLists.txt and call:
#   apply_buildkit()
#
# This adds a custom command that runs build_tool cmake before the native target is linked.

function(apply_buildkit)
  # Locate the run_build_tool script relative to this cmake file
  get_filename_component(BUILDKIT_DIR "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)

  if(WIN32)
    set(_launcher "${BUILDKIT_DIR}/run_build_tool.cmd")
  else()
    set(_launcher "${BUILDKIT_DIR}/run_build_tool.sh")
  endif()

  # Project root is one level up from CMAKE_SOURCE_DIR (the top-level CMakeLists.txt
  # lives in linux/ or windows/, so project root is the parent).
  get_filename_component(PROJECT_ROOT "${CMAKE_SOURCE_DIR}" DIRECTORY)

  # The output files the build_tool produces
  if(WIN32)
    set(_output "${PROJECT_ROOT}/libclash/windows/FlClashCore.exe")
  else()
    set(_output "${PROJECT_ROOT}/libclash/linux/FlClashCore")
  endif()

  add_custom_command(
    OUTPUT ${_output}
    COMMAND "${_launcher}" cmake
    WORKING_DIRECTORY "${PROJECT_ROOT}"
    COMMENT "Building Go core via buildkit..."
    VERBATIM
  )

  add_custom_target(setup_buildkit_build DEPENDS ${_output})
endfunction()
