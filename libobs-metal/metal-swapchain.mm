#include "metal-subsystem.hpp"

#import <QuartzCore/QuartzCore.h>

void gs_swap_chain::InitTarget(uint32_t cx, uint32_t cy)
{
	if (target != nullptr) {
		delete target;
		target = nullptr;
	}
	
	target = new gs_texture_2d(device, metalView.currentDrawable.texture);
	
	UNUSED_PARAMETER(cx);
	UNUSED_PARAMETER(cy);
}

void gs_swap_chain::InitZStencilBuffer(uint32_t cx, uint32_t cy)
{
	if (zs != nullptr) {
		delete zs;
		zs = nullptr;
	}
	
	zs = new gs_zstencil_buffer(device, metalView.depthStencilTexture);
	
	UNUSED_PARAMETER(cx);
	UNUSED_PARAMETER(cy);
}

void gs_swap_chain::Init()
{
	InitTarget(initData.cx, initData.cy);
	InitZStencilBuffer(initData.cx, initData.cy);
}

void gs_swap_chain::Resize(uint32_t cx, uint32_t cy)
{
	NSRect clientRect;
	
	initData.cx = cx;
	initData.cy = cy;
	
	if (cx == 0 || cy == 0) {
		clientRect = view.layer.frame;
		if (cx == 0) cx = clientRect.size.width - clientRect.origin.x;
		if (cy == 0) cy = clientRect.size.height - clientRect.origin.y;
	}
	
	[metalView setFrame:NSMakeRect(0, 0, cx, cy)];
	
	Init();
}

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
	: gs_obj     (device, gs_type::gs_swap_chain),
	  numBuffers (data->num_backbuffers),
	  view       (data->window.view),
	  initData   (*data)
{
	CGRect frameRect;
	
	frameRect = CGRectMake(0, 0, initData.cx, initData.cy);
	
	metalView = [[MTKView alloc] initWithFrame:frameRect
		device:device->device];
	metalView.sampleCount = numBuffers;
	
	/*if (metalView.colorPixelFormat !=
			ConvertGSTextureFormat(data->format) ||
	    metalView.depthStencilPixelFormat !=
			ConvertGSZStencilFormat(data->zsformat))
		throw "Incompabile format";*/
	
	Init();
}
