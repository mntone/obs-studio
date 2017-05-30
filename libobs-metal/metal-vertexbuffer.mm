#include <util/base.h>
#include <graphics/vec3.h>

#include "metal-subsystem.hpp"

static inline void PushBuffer(vector<id<MTLBuffer>> &buffers,
		id<MTLBuffer> buffer, const char *name)
{
	if (buffer) {
		buffers.push_back(buffer);
	} else {
		blog(LOG_ERROR, "This vertex shader requires a %s buffer",
				name);
	}
}

void gs_vertex_buffer::FlushBuffer(id <MTLBuffer> buffer, void *array,
		size_t elementSize)
{
	memcpy([buffer contents], array, elementSize * vbd.data->num);
}

void gs_vertex_buffer::MakeBufferList(gs_vertex_shader *shader,
		vector<id<MTLBuffer>> &buffers)
{
	PushBuffer(buffers, vertexBuffer, "point");

	if (shader->hasNormals)
		PushBuffer(buffers, normalBuffer, "normal");
	if (shader->hasColors)
		PushBuffer(buffers, colorBuffer, "color");
	if (shader->hasTangents)
		PushBuffer(buffers, tangentBuffer, "tangent");
	if (shader->nTexUnits <= uvBuffers.size()) {
		for (size_t i = 0; i < shader->nTexUnits; i++) {
			buffers.push_back(uvBuffers[i]);
		}
	} else {
		blog(LOG_ERROR, "This vertex shader requires at least %u "
		                "texture buffers.",
		                (uint32_t)shader->nTexUnits);
	}
}

void gs_vertex_buffer::InitBuffer(const size_t elementSize,
		const size_t numVerts, void *array, id<MTLBuffer> &buffer)
{
	if (buffer != nil) {
		CFRelease(buffer);
		buffer = nil;
	}
	
	NSUInteger         length  = elementSize * numVerts;
	MTLResourceOptions options = isDynamic ? MTLResourceStorageModeShared
			: MTLResourceStorageModePrivate;
	
	buffer = [device->device newBufferWithBytes:array
			length:length options:options];
	if (buffer == nil)
		throw "Failed to create buffer";
}

void gs_vertex_buffer::BuildBuffers()
{
	InitBuffer(sizeof(vec3), vbd->num, vbd->points, vertexBuffer);

	if (vbd.data->normals)
		InitBuffer(sizeof(vec3), vbd->num, vbd->normals, normalBuffer);

	if (vbd.data->tangents)
		InitBuffer(sizeof(vec3), vbd->num, vbd->tangents,
				tangentBuffer);

	if (vbd.data->colors)
		InitBuffer(sizeof(uint32_t), vbd->num, vbd->colors,
				colorBuffer);

	for (struct gs_tvertarray *tverts = vbd->tvarray;
			tverts != vbd->tvarray + vbd->num_tex;
			tverts++) {
		if (tverts->width != 2 && tverts->width != 4)
			throw "Invalid texture vertex size specified";
		if (!tverts->array)
			throw "No texture vertices specified";

		id<MTLBuffer> buffer;
		InitBuffer(tverts->width * sizeof(float), vbd->num,
				tverts->array, buffer);

		uvBuffers.push_back(buffer);
		uvSizes.push_back(tverts->width * sizeof(float));
	}
}

inline void gs_vertex_buffer::Rebuild()
{
	uvBuffers.clear();
	uvSizes.clear();
	
	BuildBuffers();
}

gs_vertex_buffer::gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data,
		uint32_t flags)
	: gs_obj    (device, gs_type::gs_vertex_buffer),
	  isDynamic ((flags & GS_DYNAMIC) != 0),
	  vbd       (data)
{
	if (!data->num)
		throw "Cannot initialize vertex buffer with 0 vertices";
	if (!data->points)
		throw "No points specified for vertex buffer";

	BuildBuffers();
}
