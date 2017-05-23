#include "metal-subsystem.hpp"

gs_zstencil_buffer::gs_zstencil_buffer(gs_device_t *device,
		uint32_t width, uint32_t height,
		gs_zstencil_format format)
	: gs_obj         (device, gs_type::gs_zstencil_buffer),
	  width          (width),
	  height         (height),
	  format         (format),
	  mtlPixelFormat (ConvertGSZStencilFormat(format))
{
	td = [MTLTextureDescriptor
		texture2DDescriptorWithPixelFormat:mtlPixelFormat
		width:width height:height mipmapped:NO];
	td.storageMode = MTLStorageModePrivate;
	
	texture = [device->device newTextureWithDescriptor:td];
	if (texture == nil)
		throw "Failed to create 2D texture";
	
	desc = [[MTLRenderPassStencilAttachmentDescriptor alloc] init];
	desc.texture = texture;
}
