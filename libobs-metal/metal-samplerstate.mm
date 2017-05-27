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

	return D3D11_TEXTURE_ADDRESS_WRAP;
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

gs_sampler_state::gs_sampler_state(gs_device_t *device,
		const gs_sampler_info *info)
	: gs_obj (device, gs_type::gs_sampler_state),
	  info   (*info)
{
	vec4 v4;

	sd = [MTLSamplerDescriptor new];
	sd.rAddressMode    = ConvertGSAddressMode(info->address_u);
	sd.sAddressMode    = ConvertGSAddressMode(info->address_v);
	sd.tAddressMode    = ConvertGSAddressMode(info->address_w);
	sd.minFilter       = ConvertGSMinFilter(info->filter);
	sd.magFilter       = ConvertGSMagFilter(info->filter);
	sd.mipFilter       = ConvertGSMipFilter(info->filter);
	sd.maxAnisotropy   = info->max_anisotropy;
	sd.compareFunction = MTLCompareFunctionAlways;

	if ((info->border_color & 0xFF000000) == 0)
		sd.borderColor = MTLSamplerBorderColorTransparentBlack;
	else if (info->border_color == 0xFFFFFFFF)
		sd.borderColor = MTLSamplerBorderColorOpaqueWhite;
	else
		sd.borderColor = MTLSamplerBorderColorOpaqueBlack;

	state = [device->device newSamplerStateWithDescriptor:sd]
}
