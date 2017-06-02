#include <util/base.h>

#include "metal-subsystem.hpp"

void gs_texture_2d::BackupTexture(const uint8_t **data)
{
	this->data.resize(levels);

	uint32_t w = width;
	uint32_t h = height;
	uint32_t bbp = gs_get_format_bpp(format);

	for (uint32_t i = 0; i < levels; i++) {
		if (!data[i])
			break;

		uint32_t texSize = bbp * w * h / 8;
		this->data[i].resize(texSize);

		vector<uint8_t> &subData = this->data[i];
		memcpy(&subData[0], data[i], texSize);

		w /= 2;
		h /= 2;
	}
}

void gs_texture_2d::InitTexture()
{
	assert(!isShared);
	
	texture = [device->device newTextureWithDescriptor:textureDesc];
	if (texture == nil)
		throw "Failed to create 2D texture";
}

inline void gs_texture_2d::Rebuild(id<MTLDevice> dev)
{
	if (isShared)
		return;
	
	if (texture != nil) {
		[texture release];
		texture = nil;
	}
	
	InitTexture();
	
	UNUSED_PARAMETER(dev);
}

gs_texture_2d::gs_texture_2d(gs_device_t *device, uint32_t width,
		uint32_t height, gs_color_format colorFormat, uint32_t levels,
		const uint8_t **data, uint32_t flags, gs_texture_type type)
	: gs_texture      (device, gs_type::gs_texture_2d, type, levels,
	                   colorFormat),
	  width           (width),
	  height          (height),
	  isRenderTarget  ((flags & GS_RENDER_TARGET) != 0),
	  isDynamic       ((flags & GS_DYNAMIC) != 0),
	  genMipmaps      ((flags & GS_BUILD_MIPMAPS) != 0),
	  isShared        (false)
{
	MTLPixelFormat mtlPixelFormat = ConvertGSTextureFormat(format);
	if (type == GS_TEXTURE_CUBE) {
		NSUInteger size = 6 * width * height;
		textureDesc = [MTLTextureDescriptor
				textureCubeDescriptorWithPixelFormat:
				mtlPixelFormat size:size
				mipmapped:genMipmaps ? YES : NO];
	} else {
		textureDesc = [MTLTextureDescriptor
				texture2DDescriptorWithPixelFormat:
				mtlPixelFormat width:width height:height
				mipmapped:genMipmaps ? YES : NO];
	}
	
	switch (type) {
	case GS_TEXTURE_3D:
		textureDesc.textureType = MTLTextureType3D;
		break;
	case GS_TEXTURE_CUBE:
		textureDesc.textureType = MTLTextureTypeCube;
		break;
	case GS_TEXTURE_2D:
	default:
		break;
	}
	textureDesc.mipmapLevelCount = genMipmaps ? 0 : levels;
	textureDesc.arrayLength      = type == GS_TEXTURE_CUBE ? 6 : 1;
	textureDesc.cpuCacheMode     = isDynamic
			? MTLCPUCacheModeWriteCombined
			: MTLCPUCacheModeDefaultCache;
	textureDesc.storageMode      = MTLStorageModeShared;
	textureDesc.usage            = isRenderTarget
			? MTLTextureUsageRenderTarget
			: MTLTextureUsageShaderRead;
	
	if (data)
		BackupTexture(data);
	
	InitTexture();
}

gs_texture_2d::gs_texture_2d(gs_device_t *device, id<MTLTexture> texture)
	: gs_texture      (device, gs_type::gs_texture_2d,
			   GS_TEXTURE_2D,
			   texture.mipmapLevelCount,
			   ConvertMTLTextureFormat(texture.pixelFormat)),
	  width           (texture.width),
	  height          (texture.height),
	  isRenderTarget  (false),
	  isDynamic       (false),
	  isShared        (true),
	  genMipmaps      (false),
	  texture         (texture)
{
}
