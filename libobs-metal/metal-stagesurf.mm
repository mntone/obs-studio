#include "metal-subsystem.hpp"

inline void gs_stage_surface::InitTexture()
{
	texture = [device->device newTextureWithDescriptor:td];
	if (texture == nil)
		throw "Failed to create staging surface";
}

inline void gs_stage_surface::Rebuild(id<MTLDevice> dev)
{
	if (texture != nil) {
		CFRelease(texture);
		texture = nil;
	}
	
	InitTexture();
	
	UNUSED_PARAMETER(dev);
}

gs_stage_surface::gs_stage_surface(gs_device_t *device, uint32_t width,
		uint32_t height, gs_color_format colorFormat)
	: gs_obj (device, gs_type::gs_stage_surface),
	  width  (width),
	  height (height),
	  format (colorFormat)
{
	td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
			ConvertGSTextureFormat(colorFormat)
			width:width height:height mipmapped:NO];
	td.storageMode = MTLStorageModeShared;
	
	InitTexture();
}
