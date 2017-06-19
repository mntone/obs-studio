#include <util/base.h>
#include <graphics/vec3.h>

#include "metal-subsystem.hpp"

using namespace std;

inline id<MTLBuffer> gs_vertex_buffer::PrepareBuffer(
		void *array, size_t elementSize)
{
	return device->GetBuffer(array, elementSize * vbData->num);
}

void gs_vertex_buffer::PrepareBuffers()
{
	assert(isDynamic);
	
	vertexBuffer = PrepareBuffer(vbData->points, sizeof(vec3));
	
	if (vbData->normals)
		normalBuffer = PrepareBuffer(vbData->normals, sizeof(vec3));
	
	if (vbData->tangents)
		tangentBuffer = PrepareBuffer(vbData->tangents, sizeof(vec3));
	
	if (vbData->colors)
		colorBuffer = PrepareBuffer(vbData->colors, sizeof(uint32_t));
	
	for (size_t i = 0; i < vbData->num_tex; i++) {
		gs_tvertarray &tv = vbData->tvarray[i];
		uvBuffers.push_back(PrepareBuffer(tv.array,
				tv.width * sizeof(float)));
	}
}

inline void gs_vertex_buffer::FlushBuffer(id<MTLBuffer> buffer, void *array,
		size_t elementSize)
{
	memcpy(buffer.contents, array, elementSize * vbData->num);
}

void gs_vertex_buffer::FlushBuffers()
{
	assert(isDynamic);
	
	FlushBuffer(vertexBuffer, vbData->points, sizeof(vec3));
	
	if (normalBuffer)
		FlushBuffer(normalBuffer, vbData->normals, sizeof(vec3));
	
	if (tangentBuffer)
		FlushBuffer(tangentBuffer, vbData->tangents, sizeof(vec3));
	
	if (colorBuffer)
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

inline id<MTLBuffer> gs_vertex_buffer::InitBuffer(size_t elementSize,
		void *array, const char *name)
{
	NSUInteger         length  = elementSize * vbData->num;
	MTLResourceOptions options = MTLResourceCPUCacheModeWriteCombined |
			(isDynamic ? MTLResourceStorageModeShared :
			MTLResourceStorageModeManaged);
	
	id<MTLBuffer> buffer = [device->device newBufferWithBytes:array
			length:length options:options];
	if (buffer == nil)
		throw "Failed to create buffer";
	
#ifdef _DEBUG
	buffer.label = [[NSString alloc] initWithUTF8String:name];
#endif
	
	return buffer;
}

void gs_vertex_buffer::InitBuffers()
{
	vertexBuffer = InitBuffer(sizeof(vec3), vbData->points, "point");
	if (vbData->normals)
		normalBuffer = InitBuffer(sizeof(vec3), vbData->normals,
				"normal");
	if (vbData->tangents)
		tangentBuffer = InitBuffer(sizeof(vec3), vbData->tangents,
				"color");
	if (vbData->colors)
		colorBuffer = InitBuffer(sizeof(uint32_t), vbData->colors,
				"tangent");
	for (struct gs_tvertarray *tverts = vbData->tvarray;
	     tverts != vbData->tvarray + vbData->num_tex;
	     tverts++) {
		if (tverts->width != 2 && tverts->width != 4)
			throw "Invalid texture vertex size specified";
		if (!tverts->array)
			throw "No texture vertices specified";

		id<MTLBuffer> buffer = InitBuffer(tverts->width * sizeof(float),
				tverts->array, "texcoord");
		uvBuffers.emplace_back(buffer);
	}
}

inline void gs_vertex_buffer::Rebuild()
{
	if (!isDynamic)
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

	if (!isDynamic)
		InitBuffers();
}
