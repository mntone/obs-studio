#include "metal-subsystem.hpp"

gs_stage_surface::gs_stage_surface(gs_device_t *device, uint32_t width,
		uint32_t height, gs_color_format colorFormat)
	: gs_obj         (device, gs_type::gs_stage_surface),
	  width          (width),
	  height         (height),
	  format         (colorFormat),
	  mtlPixelFormat (ConvertGSTextureFormat(colorFormat))
{
	td = [MTLTextureDescriptor
			texture2DDescriptorWithPixelFormat:mtlPixelFormat
			width:width height:height mipmapped:NO];
	td.storageMode = MTLStorageModeManaged;
	
	texture = [device->device newTextureWithDescriptor:td];
}
