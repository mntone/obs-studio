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

void gs_vertex_buffer::FlushBuffer(id<MTLBuffer> buffer, void *array,
		size_t elementSize)
{
	memcpy(buffer.contents, array, elementSize * vbData->num);
}

void gs_vertex_buffer::FlushBuffers()
{
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
		for (size_t i = 0; i < shader->nTexUnits; i++)
			buffers.push_back(uvBuffers[i]);
	} else {
		blog(LOG_ERROR, "This vertex shader requires at least %u "
		                "texture buffers.",
		                (uint32_t)shader->nTexUnits);
	}
}

void gs_vertex_buffer::InitBuffer(size_t elementSize, size_t numVerts,
		void *array, id<MTLBuffer> &buffer)
{
	NSUInteger         length  = elementSize * numVerts;
	MTLResourceOptions options = isDynamic ? MTLResourceStorageModeShared
			: MTLResourceStorageModePrivate;
	
	buffer = [device->device newBufferWithBytes:array
			length:length options:options];
	if (buffer == nil)
		throw "Failed to create buffer";
}

void gs_vertex_buffer::InitBuffers()
{
	InitBuffer(sizeof(vec3), vbData->num, vbData->points, vertexBuffer);

	if (vbData->normals)
		InitBuffer(sizeof(vec3), vbData->num, vbData->normals,
				normalBuffer);

	if (vbData->tangents)
		InitBuffer(sizeof(vec3), vbData->num, vbData->tangents,
				tangentBuffer);

	if (vbData->colors)
		InitBuffer(sizeof(uint32_t), vbData->num, vbData->colors,
				colorBuffer);

	for (struct gs_tvertarray *tverts = vbData->tvarray;
			tverts != vbData->tvarray + vbData->num_tex;
			tverts++) {
		if (tverts->width != 2 && tverts->width != 4)
			throw "Invalid texture vertex size specified";
		if (!tverts->array)
			throw "No texture vertices specified";

		id<MTLBuffer> buffer;
		InitBuffer(tverts->width * sizeof(float), vbData->num,
				tverts->array, buffer);

		uvBuffers.push_back(buffer);
		uvSizes.push_back(tverts->width * sizeof(float));
	}
}

inline void gs_vertex_buffer::Rebuild()
{
	[vertexBuffer release];
	[normalBuffer release];
	[colorBuffer release];
	[tangentBuffer release];
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
