find_package(musica ${MUSICA_VERSION} REQUIRED)
message(STATUS "  MUSICA version ${MUSICA_VERSION}")

include(FetchContent)

FetchContent_Declare(musica
  GIT_REPOSITORY https://github.com/NCAR/musica.git
  GIT_TAG        v0.6.1
)

set(MUSICA_ENABLE_TESTS OFF)
set(MUSICA_BUILD_C_CXX_INTERFACE OFF)
set(MUSICA_BUILD_FORTRAN_INTERFACE ON)
set(MUSICA_ENABLE_TUVX OFF)

FetchContent_MakeAvailable(musica)

# ---------------------------------------------------------
# Create a test for MICM CCPP wrapper
# ---------------------------------------------------------

add_executable(test_micm_api test_micm_api.F90)

target_sources(test_micm_api
  PUBLIC
    ${MICM_SRC_PATH}/micm.F90
    ${CCPP_SRC_PATH}/ccpp_api.F90
    ${CCPP_SRC_PATH}/ccpp_constituent_prop_mod.F90
    ${CCPP_SRC_PATH}/ccpp_hash_table.F90
    ${CCPP_SRC_PATH}/ccpp_hashable.F90
    ${CCPP_SRC_PATH}/ccpp_types.F90
    ${CCPP_TEST_SRC_PATH}/ccpp_kinds.F90
)

target_link_libraries(test_micm_api
  PRIVATE
    musica::musica-fortran
)

set_target_properties(test_micm_api
  PROPERTIES
  LINKER_LANGUAGE Fortran
)

include(CTest)

add_test(
  NAME test_micm_api
  COMMAND $<TARGET_FILE:test_micm_api>
  WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
)