#include <util/base.h>
#include <graphics/vec3.h>

#include "metal-subsystem.hpp"

using namespace std;

inline void gs_vertex_buffer::FlushBuffer(id<MTLBuffer> buffer, void *array,
		size_t elementSize)
{
	memcpy(buffer.contents, array, elementSize * vbData->num);
}

void gs_vertex_buffer::FlushBuffers()
{
	assert(isDynamic);
	
	FlushBuffer(vertexBuffer, vbData->points, sizeof(vec3));
	
	if (normalBuffer != nil)
		FlushBuffer(normalBuffer, vbData->normals, sizeof(vec3));
	
	if (tangentBuffer != nil)
		FlushBuffer(tangentBuffer, vbData->tangents, sizeof(vec3));
	
	if (colorBuffer != nil)
		FlushBuffer(colorBuffer, vbData->colors, sizeof(uint32_t));
	
	for (size_t i = 0; i < uvBuffers.size(); i++) {
		gs_tvertarray &tv = vbData->tvarray[i];
		FlushBuffer(uvBuffers[i], tv.array, tv.width * sizeof(float));
	}
}

static inline void PushBuffer(vector<id<MTLBuffer>> &buffers,
		id<MTLBuffer> buffer, const char *name)
{
	if (buffer != nil) {
		buffers.push_back(buffer);
	} else {
		blog(LOG_ERROR, "This vertex shader requires a %s buffer",
				name);
	}
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
	if (shader->texUnits <= uvBuffers.size()) {
		for (size_t i = 0; i < shader->texUnits; i++)
			buffers.push_back(uvBuffers[i]);
	} else {
		blog(LOG_ERROR, "This vertex shader requires at least %u "
		                "texture buffers.",
		                (uint32_t)shader->texUnits);
	}
}

inline void gs_vertex_buffer::InitBuffer(size_t elementSize, void *array,
		id<MTLBuffer> &buffer, const char *name)
{
	NSUInteger         length  = elementSize * vbData->num;
	MTLResourceOptions options = isDynamic ? MTLResourceStorageModeShared
			: MTLResourceStorageModeManaged;
	
	buffer = [device->device newBufferWithBytes:array
			length:length options:options];
	if (buffer == nil)
		throw "Failed to create buffer";
	
	buffer.label = [[NSString alloc] initWithUTF8String:name];
}

void gs_vertex_buffer::InitBuffers()
{
	InitBuffer(sizeof(vec3), vbData->points, vertexBuffer, "point");
	if (vbData->normals)
		InitBuffer(sizeof(vec3), vbData->normals, normalBuffer,
				"normal");
	if (vbData->tangents)
		InitBuffer(sizeof(vec3), vbData->tangents, tangentBuffer,
				"color");
	if (vbData->colors)
		InitBuffer(sizeof(uint32_t), vbData->colors, colorBuffer,
				"tangent");
	for (struct gs_tvertarray *tverts = vbData->tvarray;
	     tverts != vbData->tvarray + vbData->num_tex;
	     tverts++) {
		if (tverts->width != 2 && tverts->width != 4)
			throw "Invalid texture vertex size specified";
		if (!tverts->array)
			throw "No texture vertices specified";

		id<MTLBuffer> buffer;
		InitBuffer(tverts->width * sizeof(float), tverts->array, buffer,
				"texcoord");

		uvBuffers.push_back(buffer);
		uvSizes.emplace_back(tverts->width * sizeof(float));
	}
}

inline void gs_vertex_buffer::Rebuild()
{
	[vertexBuffer release];
	if (normalBuffer != nil) {
		[normalBuffer release];
		normalBuffer = nil;
	}
	if (colorBuffer != nil) {
		[colorBuffer release];
		colorBuffer = nil;
	}
	if (tangentBuffer != nil) {
		[tangentBuffer release];
		tangentBuffer = nil;
	}
	for (auto uvBuffer : uvBuffers)
		[uvBuffer release];
	uvBuffers.clear();
	uvSizes.clear();
	
	InitBuffers();
}

gs_vertex_buffer::gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data,
		uint32_t flags)
	: gs_obj    (device, gs_type::gs_vertex_buffer),
	  isDynamic ((flags & GS_DYNAMIC) != 0),
	  vbData    (data, gs_vbdata_destroy)
{
	if (!data->num)
		throw "Cannot initialize vertex buffer with 0 vertices";
	if (!data->points)
		throw "No points specified for vertex buffer";

	InitBuffers();
}
