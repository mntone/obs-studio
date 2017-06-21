#include "metal-subsystem.hpp"

void gs_zstencil_buffer::InitBuffer()
{
	texture = [device->device newTextureWithDescriptor:textureDesc];
	if (texture == nil)
		throw "Failed to create depth stencil texture";
	
#if _DEBUG
	texture.label = @"zstencil";
#endif
}

gs_zstencil_buffer::gs_zstencil_buffer(gs_device_t *device,
		uint32_t width, uint32_t height,
		gs_zstencil_format format)
	: gs_obj (device, gs_type::gs_zstencil_buffer),
	  width  (width),
	  height (height),
	  format (format)
{
	textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
			ConvertGSZStencilFormat(format)
			width:width height:height mipmapped:NO];
	textureDesc.cpuCacheMode     = MTLCPUCacheModeWriteCombined;
	textureDesc.storageMode = MTLStorageModeManaged;
	
	InitBuffer();
}
