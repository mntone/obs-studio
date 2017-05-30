#include "metal-subsystem.hpp"

gs_zstencil_buffer::gs_zstencil_buffer(gs_device_t *device,
		uint32_t width, uint32_t height,
		gs_zstencil_format format)
	: gs_obj (device, gs_type::gs_zstencil_buffer),
	  width  (width),
	  height (height),
	  format (format)
{
	td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
			ConvertGSZStencilFormat(format)
			width:width height:height mipmapped:NO];
	td.storageMode = MTLStorageModeShared;
	
	InitTexture();
}

inline void gs_zstencil_buffer::InitTexture()
{
	texture = [device->device newTextureWithDescriptor:td];
	if (texture == nil)
		throw "Failed to create depth stencil texture";
}

inline void gs_zstencil_buffer::Rebuild(id<MTLDevice> dev)
{
	if (texture != nil) {
		CFRelease(texture);
		texture = nil;
	}
	
	InitTexture();
}
