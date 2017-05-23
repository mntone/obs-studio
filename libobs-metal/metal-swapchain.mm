#include "metal-subsystem.hpp"

#import <QuartzCore/QuartzCore.h>

void gs_swap_chain::Resize(uint32_t cx, uint32_t cy)
{
	NSRect clientRect;

	initData.cx = cx;
	initData.cy = cy;

	if (cx == 0 || cy == 0) {
		clientRect = data->window.view.layer.frame;
		if (cx == 0) cx = clientRect.size.width - clientRect.origin.x;
		if (cy == 0) cy = clientRect.size.height - clientRect.origin.y;
	}

	[metalView setFrame:NSMakeRect(0, 0, cx, cy)];
}

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
	: gs_obj     (device, gs_type::gs_swap_chain),
	  numBuffers (data->num_backbuffers),
	  view       (data->window.view),
	  initData   (*data)
{
	CGRect frameRect;
	
	frameRect = CGRect(0, 0, initData.cx, initData.cy);
	
	metalView = [[MTKView alloc] initWithFrame:frameRect
		device:device->device];
	[metalView setSampleCount:numBuffers];
	[metalView setColorPixelFormat:ConvertGSTextureFormat(data->format)];
	[metalView setDepthStencilPixelFormat:
		ConvertGSZStencilFormat(data->zsformat)];
	
	Init();
}
