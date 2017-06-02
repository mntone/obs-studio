#include <graphics/vec4.h>

#include "metal-subsystem.hpp"

static inline MTLSamplerAddressMode ConvertGSAddressMode(gs_address_mode mode)
{
	switch (mode) {
	case GS_ADDRESS_WRAP:
		return MTLSamplerAddressModeRepeat;
	case GS_ADDRESS_CLAMP:
		return MTLSamplerAddressModeClampToEdge;
	case GS_ADDRESS_MIRROR:
		return MTLSamplerAddressModeMirrorRepeat;
	case GS_ADDRESS_BORDER:
		return MTLSamplerAddressModeClampToBorderColor;
	case GS_ADDRESS_MIRRORONCE:
		return MTLSamplerAddressModeMirrorClampToEdge;
	}

	return MTLSamplerAddressModeRepeat;
}

static inline MTLSamplerMinMagFilter ConvertGSMinFilter(gs_sample_filter filter)
{
	switch (filter) {
	case GS_FILTER_POINT:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_LINEAR:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_ANISOTROPIC:
		return MTLSamplerMinMagFilterLinear;
	}

	return MTLSamplerMinMagFilterNearest;
}

static inline MTLSamplerMinMagFilter ConvertGSMagFilter(gs_sample_filter filter)
{
	switch (filter) {
	case GS_FILTER_POINT:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_LINEAR:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMinMagFilterNearest;
	case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMinMagFilterLinear;
	case GS_FILTER_ANISOTROPIC:
		return MTLSamplerMinMagFilterLinear;
	}
	
	return MTLSamplerMinMagFilterNearest;
}

static inline MTLSamplerMipFilter ConvertGSMipFilter(gs_sample_filter filter)
{
	switch (filter) {
	case GS_FILTER_POINT:
		return MTLSamplerMipFilterNearest;
	case GS_FILTER_LINEAR:
		return MTLSamplerMipFilterLinear;
	case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMipFilterLinear;
	case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMipFilterNearest;
	case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
		return MTLSamplerMipFilterLinear;
	case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
		return MTLSamplerMipFilterNearest;
	case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
		return MTLSamplerMipFilterLinear;
	case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
		return MTLSamplerMipFilterNearest;
	case GS_FILTER_ANISOTROPIC:
		return MTLSamplerMipFilterLinear;
	}
	
	return MTLSamplerMipFilterNearest;
}

inline void gs_sampler_state::InitSampler()
{
	samplerState = [device->device
			newSamplerStateWithDescriptor:samplerDesc];
	if (samplerState == nil)
		throw "Failed to create sampler state";
}

inline void gs_sampler_state::Rebuild(id<MTLDevice> dev)
{
	if (samplerState != nil) {
		CFRelease(samplerState);
		samplerState = nil;
	}
	
	InitSampler();
	
	UNUSED_PARAMETER(dev);
}

gs_sampler_state::gs_sampler_state(gs_device_t *device,
		const gs_sampler_info *info)
	: gs_obj (device, gs_type::gs_sampler_state),
	  info   (*info)
{
	samplerDesc = [MTLSamplerDescriptor new];
	samplerDesc.rAddressMode    = ConvertGSAddressMode(info->address_u);
	samplerDesc.sAddressMode    = ConvertGSAddressMode(info->address_v);
	samplerDesc.tAddressMode    = ConvertGSAddressMode(info->address_w);
	samplerDesc.minFilter       = ConvertGSMinFilter(info->filter);
	samplerDesc.magFilter       = ConvertGSMagFilter(info->filter);
	samplerDesc.mipFilter       = ConvertGSMipFilter(info->filter);
	samplerDesc.maxAnisotropy   = info->max_anisotropy;
	samplerDesc.compareFunction = MTLCompareFunctionAlways;

	if ((info->border_color & 0xFF000000) == 0)
		samplerDesc.borderColor = MTLSamplerBorderColorTransparentBlack;
	else if (info->border_color == 0xFFFFFFFF)
		samplerDesc.borderColor = MTLSamplerBorderColorOpaqueWhite;
	else
		samplerDesc.borderColor = MTLSamplerBorderColorOpaqueBlack;

	InitSampler();
}
