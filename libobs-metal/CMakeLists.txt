project(libobs-metal)

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
		PREFIX "")
target_link_libraries(libobs-metal
	libobs)

install_obs_core(libobs-metal)
