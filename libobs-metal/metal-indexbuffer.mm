#include "metal-subsystem.hpp"

void gs_index_buffer::InitBuffer()
{
	NSUInteger         length  = indexSize * num;
	MTLResourceOptions options = dynamic ? MTLResourceStorageModeManaged
			: MTLResourceStorageModePrivate;
    
	indexBuffer = [device->device newBufferWithBytes:indices.data
			length:length options:options];
}

gs_index_buffer::gs_index_buffer(gs_device_t *device, enum gs_index_type type,
		void *indices, size_t num, uint32_t flags)
	: gs_obj  (device, gs_type::gs_index_buffer),
	  dynamic ((flags & GS_DYNAMIC) != 0),
	  type    (type),
	  num     (num),
	  indices (indices)
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
