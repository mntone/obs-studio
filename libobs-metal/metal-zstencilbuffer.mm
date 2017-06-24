#include "metal-subsystem.hpp"

static inline MTLPixelFormat ConvertGSZStencilFormat(gs_zstencil_format format,
		gs_device_t *device)
{
	if (format == GS_Z24_S8 &&
	    device->featureSetFamily == 1 &&
	    device->featureSetVersion == 1 &&
	    !device->device.isDepth24Stencil8PixelFormatSupported) {
		throw "GS_Z24_S8 is not supported in this device.";
	}

	switch (format) {
	case GS_ZS_NONE:    return MTLPixelFormatInvalid;
#ifdef __MAC_10_12
	case GS_Z16:        return MTLPixelFormatDepth16Unorm;
#endif
	case GS_Z24_S8:     return MTLPixelFormatDepth24Unorm_Stencil8;
	case GS_Z32F:       return MTLPixelFormatDepth32Float;
	case GS_Z32F_S8X24: return MTLPixelFormatDepth32Float_Stencil8;
	default:            throw "Cannot initialize zstencil buffer";
	}

	return MTLPixelFormatInvalid;
}

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
			ConvertGSZStencilFormat(format, device)
			width:width height:height mipmapped:NO];
	textureDesc.cpuCacheMode = MTLCPUCacheModeWriteCombined;
	textureDesc.storageMode  = MTLStorageModeManaged;

	InitBuffer();
}
