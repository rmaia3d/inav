
main_sources(SITL_COMMON_SRC_EXCLUDES
    build/atomic.h
    drivers/system.c
    drivers/time.c
    drivers/timer.c
    drivers/rcc.c
    drivers/persistent.c
    drivers/accgyro/accgyro_mpu.c
    drivers/display_ug2864hsweg01.c
    io/displayport_oled.c
)

main_sources(SITL_SRC
    config/config_streamer_file.c
    drivers/serial_tcp.c
    drivers/serial_tcp.h
    target/SITL/sim/realFlight.c
    target/SITL/sim/realFlight.h
    target/SITL/sim/simHelper.c
    target/SITL/sim/simHelper.h
    target/SITL/sim/simple_soap_client.c
    target/SITL/sim/simple_soap_client.h
    target/SITL/sim/xplane.c
    target/SITL/sim/xplane.h
)

set(SITL_LINK_OPTIONS
    -lrt
    -Wl,-L${STM32_LINKER_DIR}
    -Wl,--cref
    -static-libgcc # Required for windows build under cygwin
)

set(SITL_LINK_LIBRARIS
    -lpthread
    -lm
    -lc
)

set(SITL_COMPILE_OPTIONS
    -Wno-format #Fixme: Compile for 32bit, but settings.rb has to be adjusted
    -Wno-return-local-addr
    -Wno-error=maybe-uninitialized
    -fsingle-precision-constant
    -funsigned-char
)

set(SITL_DEFINITIONS
    SITL_BUILD
)

function(generate_map_file target)
    if(CMAKE_VERSION VERSION_LESS 3.15)
        set(map "$<TARGET_FILE:${target}>.map")
    else()
        set(map "$<TARGET_FILE_DIR:${target}>/$<TARGET_FILE_BASE_NAME:${target}>.map")
    endif()
    target_link_options(${target} PRIVATE "-Wl,-gc-sections,-Map,${map}")
endfunction()

function (target_sitl name)

    if(NOT host STREQUAL TOOLCHAIN)
        return()
    endif()
    
    exclude(COMMON_SRC "${SITL_COMMON_SRC_EXCLUDES}")

    set(target_sources)
    list(APPEND target_sources ${SITL_SRC})
    file(GLOB target_c_sources "${CMAKE_CURRENT_SOURCE_DIR}/*.c")
    file(GLOB target_h_sources "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
    list(APPEND target_sources ${target_c_sources} ${target_h_sources})
    
    set(target_definitions ${COMMON_COMPILE_DEFINITIONS})
    
    set(hse_mhz ${STM32_DEFAULT_HSE_MHZ})
    math(EXPR hse_value "${hse_mhz} * 1000000")
    list(APPEND target_definitions "HSE_VALUE=${hse_value}")

    string(TOLOWER ${PROJECT_NAME} lowercase_project_name)
    set(binary_name ${lowercase_project_name}_${FIRMWARE_VERSION}_${name})
    if(DEFINED BUILD_SUFFIX AND NOT "" STREQUAL "${BUILD_SUFFIX}")
        set(binary_name "${binary_name}_${BUILD_SUFFIX}")
    endif()

    list(APPEND target_definitions ${SITL_DEFINITIONS})
    set(exe_target ${name}.elf)
    add_executable(${exe_target})
    target_sources(${exe_target} PRIVATE ${target_sources} ${COMMON_SRC})
    target_include_directories(${exe_target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    target_compile_definitions(${exe_target} PRIVATE ${target_definitions})

    
    if(WARNINGS_AS_ERRORS)
        target_compile_options(${exe_target} PRIVATE -Werror)
    endif()
    
    target_compile_options(${exe_target} PRIVATE ${SITL_COMPILE_OPTIONS})
  
    target_link_libraries(${exe_target} PRIVATE ${SITL_LINK_LIBRARIS})
    target_link_options(${exe_target} PRIVATE ${SITL_LINK_OPTIONS})
    
    generate_map_file(${exe_target})
    
    set(script_path ${MAIN_SRC_DIR}/target/link/sitl.ld)
    if(NOT EXISTS ${script_path})
        message(FATAL_ERROR "linker script ${script_path} doesn't exist")
    endif()
    set_target_properties(${exe_target} PROPERTIES LINK_DEPENDS ${script_path})
    target_link_options(${exe_target} PRIVATE -T${script_path})

    if(${WIN32} OR ${CYGWIN})
        set(exe_filename ${CMAKE_BINARY_DIR}/${binary_name}.exe)
    else()
        set(exe_filename ${CMAKE_BINARY_DIR}/${binary_name})
    endif()
    
    add_custom_target(${name} ALL
        cmake -E env PATH="$ENV{PATH}"
        ${CMAKE_OBJCOPY} $<TARGET_FILE:${exe_target}> ${exe_filename}
        BYPRODUCTS ${hex}
    )

    setup_firmware_target(${exe_target} ${name} ${ARGN})
    #clean_<target>
    set(generator_cmd "")
    if (CMAKE_GENERATOR STREQUAL "Unix Makefiles")
        set(generator_cmd "make")
    elseif(CMAKE_GENERATOR STREQUAL "Ninja")
        set(generator_cmd "ninja")
    endif()
    if (NOT generator_cmd STREQUAL "")
        set(clean_target "clean_${name}")
        add_custom_target(${clean_target}
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMAND ${generator_cmd} clean
            COMMENT "Removing intermediate files for ${name}")
        set_property(TARGET ${clean_target} PROPERTY
            EXCLUDE_FROM_ALL 1
            EXCLUDE_FROM_DEFAULT_BUILD 1)
    endif()
endfunction()
