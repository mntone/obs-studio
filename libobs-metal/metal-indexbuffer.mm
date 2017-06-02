#include "metal-subsystem.hpp"

void gs_index_buffer::InitBuffer()
{
	NSUInteger         length  = indexSize * num;
	MTLResourceOptions options = isDynamic ? MTLResourceStorageModeShared
			: MTLResourceStorageModePrivate;
    
	indexBuffer = [device->device newBufferWithBytes:&indices
			length:length options:options];
	if (indexBuffer == nil)
		throw "Failed to create buffer";
}

inline void gs_index_buffer::Rebuild(id<MTLDevice> dev)
{
	if (indexBuffer != nil) {
		[indexBuffer release];
		indexBuffer = nil;
	}
	
	InitBuffer();
	
	UNUSED_PARAMETER(dev);
}

gs_index_buffer::gs_index_buffer(gs_device_t *device, enum gs_index_type type,
		void *indices, size_t num, uint32_t flags)
	: gs_obj    (device, gs_type::gs_index_buffer),
	  type      (type),
	  indices   (indices, bfree),
	  num       (num),
	  isDynamic ((flags & GS_DYNAMIC) != 0)
{
	switch (type) {
	case GS_UNSIGNED_SHORT:
		indexSize = 2;
		indexType = MTLIndexTypeUInt16;
		break;
	case GS_UNSIGNED_LONG:
		indexSize = 4;
		indexType = MTLIndexTypeUInt32;
		break;
	}

	InitBuffer();
}
