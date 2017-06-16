#include "metal-subsystem.hpp"

#import <QuartzCore/QuartzCore.h>

gs_texture_2d *gs_swap_chain::NextTarget()
{
	if (nextTarget != nullptr)
		delete nextTarget;
	
	nextDrawable = metalLayer.nextDrawable;
	
	if (nextDrawable != nil)
		nextTarget = new gs_texture_2d(device, nextDrawable.texture);
	
	return nextTarget;
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
	
	metalLayer.drawableSize = CGSizeMake(cx, cy);
}

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
	: gs_obj     (device, gs_type::gs_swap_chain),
	  numBuffers (data->num_backbuffers),
	  view       (data->window.view),
	  initData   (*data)
{
	metalLayer = [CAMetalLayer new];
	metalLayer.device = device->device;
	//metalLayer.pixelFormat = ConvertGSTextureFormat(data->format);
	metalLayer.drawableSize = CGSizeMake(initData.cx, initData.cy);
	view.wantsLayer = YES;
	view.layer = metalLayer;
	
	/*if (metalView.colorPixelFormat !=
			ConvertGSTextureFormat(data->format) ||
	    metalView.depthStencilPixelFormat !=
			ConvertGSZStencilFormat(data->zsformat))
		throw "Incompabile format";*/
}

gs_swap_chain::~gs_swap_chain()
{
	Release();
}
