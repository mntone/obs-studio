project(libobs-metal)

find_library(IOSURF IOSurface)
include_directories(${IOSURF})
mark_as_advanced(${IOSURF})

find_library(QUARTZCORE QuartzCore)
mark_as_advanced(QUARTZCORE)
include_directories(${QUARTZCORE})

find_library(METAL Metal)
mark_as_advanced(METAL)
include_directories(${METAL})

find_library(METALKIT MetalKit)
mark_as_advanced(METALKIT)
include_directories(${METALKIT})

set(libobs-metal_PLATFORM_DEPS
	${IOSURF}
	${QUARTZCORE})

set(libobs-metal_PLATFORM_DEPS_WEAK
	Metal
	MetalKit)

include_directories(SYSTEM "${CMAKE_SOURCE_DIR}/libobs")

add_definitions(-DLIBOBS_EXPORTS)

set(libobs-metal_SOURCES
	metal-indexbuffer.mm
	metal-samplerstate.mm
	metal-shader.mm
	metal-shaderprocessor.mm
	metal-stagesurf.mm
	metal-subsystem.mm
	metal-swapchain.mm
	metal-texture2d.mm
	metal-vertexbuffer.mm
	metal-zstencilbuffer.mm)

set(libobs-metal_HEADERS
	metal-shaderprocessor.hpp
	metal-subsystem.hpp)

add_library(libobs-metal MODULE
	${libobs-metal_SOURCES}
	${libobs-metal_HEADERS})
set_target_properties(libobs-metal
	PROPERTIES
		OUTPUT_NAME libobs-metal
		PREFIX ""
		XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)
target_link_libraries(libobs-metal
	PRIVATE
		${libobs-metal_PLATFORM_DEPS}
	PUBLIC
		libobs)
foreach(FRAMEWORK ${libobs-metal_PLATFORM_DEPS_WEAK})
	target_link_libraries(libobs-metal
		PRIVATE
			"-weak_framework ${FRAMEWORK}")
endforeach()

install_obs_core(libobs-metal)
