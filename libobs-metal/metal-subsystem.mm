#include <cinttypes>
#include <util/base.h>
#include <util/platform.h>
#include <graphics/matrix3.h>

#include "metal-subsystem.hpp"

#import <QuartzCore/QuartzCore.h>

gs_obj::gs_obj(gs_device_t *device_, gs_type type) :
	device    (device_),
	obj_type  (type)
{
	prev_next = &device->first_obj;
	next = device->first_obj;
	device->first_obj = this;
	if (next)
		next->prev_next = &next;
}

gs_obj::~gs_obj()
{
	if (prev_next)
		*prev_next = next;
	if (next)
		next->prev_next = prev_next;
}

void gs_device::InitDevice(uint32_t deviceIdx)
{
	uint32_t featureSetFamily, featureSetVersion;

	devIdx = deviceIdx;

	device = MTLCopyAllDevices()[deviceIdx];

	blog(LOG_INFO, "Loading up Metal on adapter %s (%" PRIu32 ")",
			[device name].UTF8String, deviceIdx);

	if ([device supportsFeatureSet:OSX_GPUFamily1_v2]) {
		featureSetFamily  = 1;
		featureSetVersion = 2;
	} else if ([device supportsFeatureSet:OSX_GPUFamily1_v1]) {
		featureSetFamily  = 1;
		featureSetVersion = 1;
	}

	blog(LOG_INFO, "Metal loaded successfully, feature set used: %u_v%u",
			featureSetFamily, featureSetVersion);
}

static inline void ConvertStencilSide(MTLStencilDescriptor *desc,
		const StencilSide &side)
{
	desc.stencilCompareFunction    = ConvertGSDepthTest(side.test);
	desc.stencilFailureOperation   = ConvertGSStencilOp(side.fail);
	desc.depthFailureOperation     = ConvertGSStencilOp(side.zfail);
	desc.depthStencilPassOperation = ConvertGSStencilOp(side.zpass);
}

id<MTLDepthStencilState> gs_device::AddZStencilState()
{
	MTLDepthStencilDescriptor *dsd;
	id<MTLDepthStencilState> state;

	dsd                      = [MTLDepthStencilDescriptor new];
	dsd.depthWriteEnabled    = zstencilState.depthWriteEnabled ? YES : NO;
	dsd.depthCompareFunction = ConvertGSDepthTest(zstencilState.depthFunc);
	
	ConvertStencilSide(dsd.frontFaceStencil, zstencilState.stencilFront);
	dsd.frontFaceStencil.readMask  = zstencilState.stencilEnabled ?
			0xFFFFFFFF : 0;
	dsd.frontFaceStencil.writeMask = zstencilState.stencilWriteEnabled ?
			0xFFFFFFFF : 0;
	
	ConvertStencilSide(dsd.backFaceStencil, zstencilState.stencilFront);
	dsd.backFaceStencil.readMask   = zstencilState.stencilEnabled ?
			0xFFFFFFFF : 0;
	dsd.backFaceStencil.writeMask  = zstencilState.stencilWriteEnabled ?
			0xFFFFFFFF : 0;

	SavedZStencilState savedState(zstencilState, dsd);
	state = [device newDepthStencilStateWithDescriptor:dsd];
	if (state == nil)
		throw "Failed to create depth stencil state";

	savedState.state = state;
	zstencilStates.push_back(savedState);

	return state;
}

ID3D11RasterizerState *gs_device::AddRasterState()
{
	HRESULT hr;
	D3D11_RASTERIZER_DESC rd;
	ID3D11RasterizerState *state;

	memset(&rd, 0, sizeof(rd));
	/* use CCW to convert to a right-handed coordinate system */
	rd.FrontCounterClockwise = true;
	rd.FillMode              = D3D11_FILL_SOLID;
	rd.CullMode              = ConvertGSCullMode(rasterState.cullMode);
	rd.DepthClipEnable       = true;
	rd.ScissorEnable         = rasterState.scissorEnabled;

	SavedRasterState savedState(rasterState, rd);
	hr = device->CreateRasterizerState(&rd, savedState.state.Assign());
	if (FAILED(hr))
		throw HRError("Failed to create rasterizer state", hr);

	state = savedState.state;
	rasterStates.push_back(savedState);

	return state;
}

MTLRenderPipelineColorAttachmentDescriptor *gs_device::AddBlendState()
{
	MTLRenderPipelineColorAttachmentDescriptor *cad = nil;
	
	cad = [MTLRenderPipelineColorAttachmentDescriptor new];
	cad.blendingEnabled = blendState.blendEnabled ? YES : NO;
	cad.sourceRGBBlendFactor =
			ConvertGSBlendType(blendState.srcFactorC);
	cad.destinationRGBBlendFactor =
			ConvertGSBlendType(blendState.destFactorC);
	cad.sourceAlphaBlendFactor =
			ConvertGSBlendType(blendState.srcFactorA);
	cad.destinationAlphaBlendFactor =
			ConvertGSBlendType(blendState.destFactorA);

	SavedBlendState savedState(blendState, cad);

	blendStates.push_back(savedState);

	return cad;
}

void gs_device::UpdateZStencilState()
{
	id<MTLDepthStencilState> state = nil;

	if (!zstencilStateChanged)
		return;

	for (size_t i = 0; i < zstencilStates.size(); i++) {
		SavedZStencilState &s = zstencilStates[i];
		if (memcmp(&s, &zstencilState, sizeof(zstencilState)) == 0) {
			state = s.state;
			break;
		}
	}

	if (!state)
		state = AddZStencilState();

	if (state != curDepthStencilState) {
		context->OMSetDepthStencilState(state, 0);
		curDepthStencilState = state;
	}

	zstencilStateChanged = false;
}

void gs_device::UpdateRasterState()
{
	ID3D11RasterizerState *state = NULL;

	if (!rasterStateChanged)
		return;

	for (size_t i = 0; i < rasterStates.size(); i++) {
		SavedRasterState &s = rasterStates[i];
		if (memcmp(&s, &rasterState, sizeof(rasterState)) == 0) {
			state = s.state;
			break;
		}
	}

	if (!state)
		state = AddRasterState();

	if (state != curRasterState) {
		context->RSSetState(state);
		curRasterState = state;
	}

	rasterStateChanged = false;
}

void gs_device::UpdateBlendState()
{
	MTLRenderPipelineColorAttachmentDescriptor *cad = nil;

	if (!blendStateChanged)
		return;

	for (size_t i = 0; i < blendStates.size(); i++) {
		auto &s = blendStates[i];
		if (memcmp(&s, &blendState, sizeof(blendState)) == 0) {
			cad = s.cad;
			break;
		}
	}

	if (!cad)
		cad = AddBlendState();

	if (cad != curBlendState) {
		pipelineDesc.colorAttachments[0] = cad;
		curBlendState = cad;
	}

	blendStateChanged = false;
}

void gs_device::UpdateViewProjMatrix()
{
	gs_matrix_get(&curViewMatrix);

	/* negate Z col of the view matrix for right-handed coordinate system */
	curViewMatrix.x.z = -curViewMatrix.x.z;
	curViewMatrix.y.z = -curViewMatrix.y.z;
	curViewMatrix.z.z = -curViewMatrix.z.z;
	curViewMatrix.t.z = -curViewMatrix.t.z;

	matrix4_mul(&curViewProjMatrix, &curViewMatrix, &curProjMatrix);
	matrix4_transpose(&curViewProjMatrix, &curViewProjMatrix);

	if (curVertexShader->viewProj)
		gs_shader_set_matrix4(curVertexShader->viewProj,
				&curViewProjMatrix);
}

gs_device::gs_device(uint32_t adapterIdx)
{
	matrix4_identity(&curProjMatrix);
	matrix4_identity(&curViewMatrix);
	matrix4_identity(&curViewProjMatrix);

	memset(&viewport, 0, sizeof(viewport));

	for (size_t i = 0; i < GS_MAX_TEXTURES; i++) {
		curTextures[i] = NULL;
		curSamplers[i] = NULL;
	}

	InitDevice(adapterIdx);
	device_set_render_target(this, NULL, NULL);
}

gs_device::~gs_device()
{
	context->ClearState();
}

const char *device_get_name(void)
{
	return "Metal";
}

int device_get_type(void)
{
	return GS_DEVICE_METAL;
}

const char *device_preprocessor_name(void)
{
	return "_Metal";
}

static inline void EnumMetalAdapters(
		bool (*callback)(void*, const char*, uint32_t),
		void *param)
{
	NSArray *devices;
	UINT i = 0;

	devices = MTLCopyAllDevices();
    
	for (id device in devices) {
		if (!callback(param, [device name].UTF8String, i++))
			break;
	}
}

bool device_enum_adapters(
		bool (*callback)(void *param, const char *name, uint32_t id),
		void *param)
{
	try {
		EnumMetalAdapters(callback, param);
		return true;

	} catch (HRError error) {
		blog(LOG_WARNING, "Failed enumerating devices: %s (%08lX)",
				error.str, error.hr);
		return false;
	}
}

static inline void LogMetalAdapters()
{
	NSArray *devices;
	
	blog(LOG_INFO, "Available Video Adapters: ");
    
	devices = MTLCopyAllDevices();
    
	for (id device in devices) {
		blog(LOG_INFO, "\tAdapter %u: %s", i, [device name].UTF8String);
	}
}

int device_create(gs_device_t **p_device, uint32_t adapter)
{
	gs_device *device = nullptr;
	int errorcode = GS_SUCCESS;

	try {
		blog(LOG_INFO, "---------------------------------");
		blog(LOG_INFO, "Initializing Metal...");
		LogMetalAdapters();

		device = new gs_device(adapter);

	} catch (UnsupportedHWError error) {
		blog(LOG_ERROR, "device_create (Metal): %s (%08lX)", error.str,
				error.hr);
		errorcode = GS_ERROR_NOT_SUPPORTED;

	}

	*p_device = device;
	return errorcode;
}

void device_destroy(gs_device_t *device)
{
	delete device;
}

void device_enter_context(gs_device_t *device)
{
	/* does nothing */
	UNUSED_PARAMETER(device);
}

void device_leave_context(gs_device_t *device)
{
	/* does nothing */
	UNUSED_PARAMETER(device);
}

gs_swapchain_t *device_swapchain_create(gs_device_t *device,
		const struct gs_init_data *data)
{
	gs_swap_chain *swap = NULL;

	try {
		swap = new gs_swap_chain(device, data);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_swapchain_create (Metal): %s", error);
	}

	return swap;
}

void device_resize(gs_device_t *device, uint32_t cx, uint32_t cy)
{
	if (!device->curSwapChain) {
		blog(LOG_WARNING, "device_resize (Metal): No active swap");
		return;
	}

	try {
		ID3D11RenderTargetView *renderView = NULL;
		ID3D11DepthStencilView *depthView  = NULL;
		int i = device->curRenderSide;

		device->context->OMSetRenderTargets(1, &renderView, depthView);
		device->curSwapChain->Resize(cx, cy);

		if (device->curRenderTarget)
			renderView = device->curRenderTarget->renderTarget[i];
		if (device->curZStencilBuffer)
			depthView  = device->curZStencilBuffer->view;
		device->context->OMSetRenderTargets(1, &renderView, depthView);

	} catch (const char *error) {
		blog(LOG_ERROR, "device_resize (Metal): %s", error);
	}
}

void device_get_size(const gs_device_t *device, uint32_t *cx, uint32_t *cy)
{
	if (device->curSwapChain) {
		NSRect curRect = [device->curSwapChain->metalView frame];
		*cx = curRect.size.width - curRect.origin.x;
		*cy = curRect.size.height - curRect.origin.y;
	} else {
		blog(LOG_ERROR, "device_get_size (Metal): No active swap");
		*cx = 0;
		*cy = 0;
	}
}

uint32_t device_get_width(const gs_device_t *device)
{
	if (device->curSwapChain) {
		NSRect curRect = [device->curSwapChain->metalView frame];
		return curRect.size.width - curRect.origin.x;
	} else {
		blog(LOG_ERROR, "device_get_size (Metal): No active swap");
		return 0;
	}
}

uint32_t device_get_height(const gs_device_t *device)
{
	if (device->curSwapChain) {
		NSRect curRect = [device->curSwapChain->metalView frame];
		return curRect.size.height - curRect.origin.y;
	} else {
		blog(LOG_ERROR, "device_get_size (Metal): No active swap");
		return 0;
	}
}

gs_texture_t *device_texture_create(gs_device_t *device, uint32_t width,
		uint32_t height, enum gs_color_format color_format,
		uint32_t levels, const uint8_t **data, uint32_t flags)
{
	gs_texture *texture = NULL;
	try {
		texture = new gs_texture_2d(device, width, height, color_format,
				levels, data, flags, GS_TEXTURE_2D, false);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_texture_create (Metal): %s", error);
	}

	return texture;
}

gs_texture_t *device_cubetexture_create(gs_device_t *device, uint32_t size,
		enum gs_color_format color_format, uint32_t levels,
		const uint8_t **data, uint32_t flags)
{
	gs_texture *texture = NULL;
	try {
		texture = new gs_texture_2d(device, size, size, color_format,
				levels, data, flags, GS_TEXTURE_CUBE, false);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_cubetexture_create (Metal): %s", error);
	}

	return texture;
}

gs_texture_t *device_voltexture_create(gs_device_t *device, uint32_t width,
		uint32_t height, uint32_t depth,
		enum gs_color_format color_format, uint32_t levels,
		const uint8_t **data, uint32_t flags)
{
	/* TODO */
	UNUSED_PARAMETER(device);
	UNUSED_PARAMETER(width);
	UNUSED_PARAMETER(height);
	UNUSED_PARAMETER(depth);
	UNUSED_PARAMETER(color_format);
	UNUSED_PARAMETER(levels);
	UNUSED_PARAMETER(data);
	UNUSED_PARAMETER(flags);
	return NULL;
}

gs_zstencil_t *device_zstencil_create(gs_device_t *device, uint32_t width,
		uint32_t height, enum gs_zstencil_format format)
{
	gs_zstencil_buffer *zstencil = NULL;
	try {
		zstencil = new gs_zstencil_buffer(device, width, height,
				format);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_zstencil_create (Metal): %s", error);
	}

	return zstencil;
}

gs_stagesurf_t *device_stagesurface_create(gs_device_t *device, uint32_t width,
		uint32_t height, enum gs_color_format color_format)
{
	gs_stage_surface *surf = NULL;
	try {
		surf = new gs_stage_surface(device, width, height,
				color_format);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_stagesurface_create (Metal): %s",
				error);
	}

	return surf;
}

gs_samplerstate_t *device_samplerstate_create(gs_device_t *device,
		const struct gs_sampler_info *info)
{
	gs_sampler_state *ss = NULL;
	try {
		ss = new gs_sampler_state(device, info);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_samplerstate_create (Metal): %s",
				error);
	}
	return ss;
}

gs_shader_t *device_vertexshader_create(gs_device_t *device,
		const char *shader_string, const char *file,
		char **error_string)
{
	gs_vertex_shader *shader = NULL;
	try {
		shader = new gs_vertex_shader(device, file, shader_string);

	} catch (ShaderError error) {
		blog(LOG_ERROR, "device_vertexshader_create (Metal): "
		                "Compile warnings/errors for %s:\n%s",
		                file,
		                error.error.localizedDescription.UTF8String);

	} catch (const char *error) {
		blog(LOG_ERROR, "device_vertexshader_create (Metal): %s",
				error);
	}

	return shader;
}

gs_shader_t *device_pixelshader_create(gs_device_t *device,
		const char *shader_string, const char *file,
		char **error_string)
{
	gs_pixel_shader *shader = NULL;
	try {
		shader = new gs_pixel_shader(device, file, shader_string);

	} catch (ShaderError error) {
		blog(LOG_ERROR, "device_pixelshader_create (Metal): "
		                "Compile warnings/errors for %s:\n%s",
		                file,
		                error.error.localizedDescription.UTF8String);

	} catch (const char *error) {
		blog(LOG_ERROR, "device_pixelshader_create (Metal): %s", error);
	}

	return shader;
}

gs_vertbuffer_t *device_vertexbuffer_create(gs_device_t *device,
		struct gs_vb_data *data, uint32_t flags)
{
	gs_vertex_buffer *buffer = NULL;
	try {
		buffer = new gs_vertex_buffer(device, data, flags);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_vertexbuffer_create (Metal): %s",
				error);
	}

	return buffer;
}

gs_indexbuffer_t *device_indexbuffer_create(gs_device_t *device,
		enum gs_index_type type, void *indices, size_t num,
		uint32_t flags)
{
	gs_index_buffer *buffer = NULL;
	try {
		buffer = new gs_index_buffer(device, type, indices, num, flags);
	} catch (const char *error) {
		blog(LOG_ERROR, "device_indexbuffer_create (Metal): %s", error);
	}

	return buffer;
}

enum gs_texture_type device_get_texture_type(const gs_texture_t *texture)
{
	return texture->type;
}

void gs_device::LoadVertexBufferData(id<MTLRenderCommandEncoder> commandEncoder)
{
	NSRange               range;
	vector<id<MTLBuffer>> buffers;
	vector<uint32_t>      offsets;

	if (curVertexBuffer && curVertexShader) {
		curVertexBuffer->MakeBufferList(curVertexShader, buffers);
	} else {
		size_t buffersToClear = curVertexShader
			? curVertexShader->NumBuffersExpected() : 0;
		buffers.resize(buffersToClear);
	}

	range.location = 0;
	range.length   = buffers.size();
	offsets.resize(buffers.size());
	
	[commandEncoder setVertexBuffers:buffers.data()
			offsets:offsets.data() withRange:range];
}

void device_load_vertexbuffer(gs_device_t *device, gs_vertbuffer_t *vertbuffer)
{
	if (device->curVertexBuffer == vertbuffer)
		return;

	device->curVertexBuffer = vertbuffer;
}

void device_load_indexbuffer(gs_device_t *device, gs_indexbuffer_t *indexbuffer)
{
	MTLPixelFormat format;
	id<MTLBuffer>  buffer;

	if (device->curIndexBuffer == indexbuffer)
		return;

	if (indexbuffer) {
		switch (indexbuffer->indexSize) {
		case 2: format = MTLPixelFormatR16Uint; break;
		default:
		case 4: format = MTLPixelFormatR32Uint; break;
		}

		buffer = indexbuffer->indexBuffer;
	} else {
		buffer = nil;
		format = MTLPixelFormatR32Uint;
	}

	device->curIndexBuffer = indexbuffer;
	device->context->IASetIndexBuffer(buffer, format, 0);
}

void device_load_texture(gs_device_t *device, gs_texture_t *tex, int unit)
{
	ID3D11ShaderResourceView *view = NULL;

	if (device->curTextures[unit] == tex)
		return;

	if (tex)
		view = tex->shaderRes;

	device->curTextures[unit] = tex;
	device->context->PSSetShaderResources(unit, 1, &view);
}

void device_load_samplerstate(gs_device_t *device,
		gs_samplerstate_t *samplerstate, int unit)
{
	ID3D11SamplerState *state = NULL;

	if (device->curSamplers[unit] == samplerstate)
		return;

	if (samplerstate)
		state = samplerstate->state;

	device->curSamplers[unit] = samplerstate;
	device->context->PSSetSamplers(unit, 1, &state);
}

void device_load_vertexshader(gs_device_t *device, gs_shader_t *vertshader)
{
	ID3D11VertexShader *shader    = NULL;
	ID3D11InputLayout  *layout    = NULL;
	ID3D11Buffer       *constants = NULL;

	if (device->curVertexShader == vertshader)
		return;

	gs_vertex_shader *vs = static_cast<gs_vertex_shader*>(vertshader);
	gs_vertex_buffer *curVB = device->curVertexBuffer;

	if (vertshader) {
		if (vertshader->type != GS_SHADER_VERTEX) {
			blog(LOG_ERROR, "device_load_vertexshader (Metal): "
			                "Specified shader is not a vertex "
			                "shader");
			return;
		}

		shader    = vs->shader;
		layout    = vs->layout;
		constants = vs->constants;
	}

	device->curVertexShader = vs;
	device->context->VSSetShader(shader, NULL, 0);
	device->context->IASetInputLayout(layout);
	device->context->VSSetConstantBuffers(0, 1, &constants);
}

static inline void clear_textures(gs_device_t *device)
{
	ID3D11ShaderResourceView *views[GS_MAX_TEXTURES];
	memset(views,               0, sizeof(views));
	memset(device->curTextures, 0, sizeof(device->curTextures));
	device->context->PSSetShaderResources(0, GS_MAX_TEXTURES, views);
}

void device_load_pixelshader(gs_device_t *device, gs_shader_t *pixelshader)
{
	ID3D11PixelShader  *shader    = NULL;
	ID3D11Buffer       *constants = NULL;
	ID3D11SamplerState *states[GS_MAX_TEXTURES];

	if (device->curPixelShader == pixelshader)
		return;

	gs_pixel_shader *ps = static_cast<gs_pixel_shader*>(pixelshader);

	if (pixelshader) {
		if (pixelshader->type != GS_SHADER_PIXEL) {
			blog(LOG_ERROR, "device_load_pixelshader (Metal): "
			                "Specified shader is not a pixel "
			                "shader");
			return;
		}

		shader    = ps->shader;
		constants = ps->constants;
		ps->GetSamplerStates(states);
	} else {
		memset(states, 0, sizeof(states));
	}

	clear_textures(device);

	device->curPixelShader = ps;
	device->context->PSSetShader(shader, NULL, 0);
	device->context->PSSetConstantBuffers(0, 1, &constants);
	device->context->PSSetSamplers(0, GS_MAX_TEXTURES, states);

	for (int i = 0; i < GS_MAX_TEXTURES; i++)
		if (device->curSamplers[i] &&
				device->curSamplers[i]->state != states[i])
			device->curSamplers[i] = nullptr;
}

void device_load_default_samplerstate(gs_device_t *device, bool b_3d, int unit)
{
	/* TODO */
	UNUSED_PARAMETER(device);
	UNUSED_PARAMETER(b_3d);
	UNUSED_PARAMETER(unit);
}

gs_shader_t *device_get_vertex_shader(const gs_device_t *device)
{
	return device->curVertexShader;
}

gs_shader_t *device_get_pixel_shader(const gs_device_t *device)
{
	return device->curPixelShader;
}

gs_texture_t *device_get_render_target(const gs_device_t *device)
{
	if (device->curRenderTarget == &device->curSwapChain->target)
		return NULL;

	return device->curRenderTarget;
}

gs_zstencil_t *device_get_zstencil_target(const gs_device_t *device)
{
	if (device->curZStencilBuffer == &device->curSwapChain->zs)
		return NULL;

	return device->curZStencilBuffer;
}

void device_set_render_target(gs_device_t *device, gs_texture_t *tex,
		gs_zstencil_t *zstencil)
{
	if (device->curSwapChain) {
		if (!tex)
			tex = &device->curSwapChain->target;
		if (!zstencil)
			zstencil = &device->curSwapChain->zs;
	}

	if (device->curRenderTarget   == tex &&
	    device->curZStencilBuffer == zstencil)
		return;

	if (tex && tex->type != GS_TEXTURE_2D) {
		blog(LOG_ERROR, "device_set_render_target (Metal): "
		                "texture is not a 2D texture");
		return;
	}

	gs_texture_2d *tex2d = static_cast<gs_texture_2d*>(tex);
	if (tex2d && !tex2d->renderTarget[0]) {
		blog(LOG_ERROR, "device_set_render_target (Metal): "
		                "texture is not a render target");
		return;
	}

	ID3D11RenderTargetView *rt = tex2d ? tex2d->renderTarget[0] : nullptr;

	device->curRenderTarget   = tex2d;
	device->curRenderSide     = 0;
	device->curZStencilBuffer = zstencil;
	device->context->OMSetRenderTargets(1, &rt,
			zstencil ? zstencil->view : nullptr);
}

void device_set_cube_render_target(gs_device_t *device, gs_texture_t *tex,
		int side, gs_zstencil_t *zstencil)
{
	if (device->curSwapChain) {
		if (!tex) {
			tex = &device->curSwapChain->target;
			side = 0;
		}

		if (!zstencil)
			zstencil = &device->curSwapChain->zs;
	}

	if (device->curRenderTarget   == tex  &&
	    device->curRenderSide     == side &&
	    device->curZStencilBuffer == zstencil)
		return;

	if (tex->type != GS_TEXTURE_CUBE) {
		blog(LOG_ERROR, "device_set_cube_render_target (D3D11): "
		                "texture is not a cube texture");
		return;
	}

	gs_texture_2d *tex2d = static_cast<gs_texture_2d*>(tex);
	if (!tex2d->renderTarget[side]) {
		blog(LOG_ERROR, "device_set_cube_render_target (D3D11): "
				"texture is not a render target");
		return;
	}

	ID3D11RenderTargetView *rt = tex2d->renderTarget[0];

	device->curRenderTarget   = tex2d;
	device->curRenderSide     = side;
	device->curZStencilBuffer = zstencil;
	device->context->OMSetRenderTargets(1, &rt, zstencil->view);
}

inline void gs_device::CopyTex(ID3D11Texture2D *dst,
		uint32_t dst_x, uint32_t dst_y,
		gs_texture_t *src, uint32_t src_x, uint32_t src_y,
		uint32_t src_w, uint32_t src_h)
{
	if (src->type != GS_TEXTURE_2D)
		throw "Source texture must be a 2D texture";

	gs_texture_2d *tex2d = static_cast<gs_texture_2d*>(src);

	if (dst_x == 0 && dst_y == 0 &&
	    src_x == 0 && src_y == 0 &&
	    src_w == 0 && src_h == 0) {
		context->CopyResource(dst, tex2d->texture);
	} else {
		D3D11_BOX sbox;

		sbox.left = src_x;
		if (src_w > 0)
			sbox.right = src_x + src_w;
		else
			sbox.right = tex2d->width - 1;

		sbox.top = src_y;
		if (src_h > 0)
			sbox.bottom = src_y + src_h;
		else
			sbox.bottom = tex2d->height - 1;

		sbox.front = 0;
		sbox.back = 1;

		context->CopySubresourceRegion(dst, 0, dst_x, dst_y, 0,
				tex2d->texture, 0, &sbox);
	}
}

void device_copy_texture_region(gs_device_t *device,
		gs_texture_t *dst, uint32_t dst_x, uint32_t dst_y,
		gs_texture_t *src, uint32_t src_x, uint32_t src_y,
		uint32_t src_w, uint32_t src_h)
{
	try {
		gs_texture_2d *src2d = static_cast<gs_texture_2d*>(src);
		gs_texture_2d *dst2d = static_cast<gs_texture_2d*>(dst);

		if (!src)
			throw "Source texture is NULL";
		if (!dst)
			throw "Destination texture is NULL";
		if (src->type != GS_TEXTURE_2D || dst->type != GS_TEXTURE_2D)
			throw "Source and destination textures must be a 2D "
			      "textures";
		if (dst->format != src->format)
			throw "Source and destination formats do not match";

		/* apparently casting to the same type that the variable
		 * already exists as is supposed to prevent some warning
		 * when used with the conditional operator? */
		uint32_t copyWidth = (uint32_t)src_w ?
			(uint32_t)src_w : (src2d->width - src_x);
		uint32_t copyHeight = (uint32_t)src_h ?
			(uint32_t)src_h : (src2d->height - src_y);

		uint32_t dstWidth  = dst2d->width  - dst_x;
		uint32_t dstHeight = dst2d->height - dst_y;

		if (dstWidth < copyWidth || dstHeight < copyHeight)
			throw "Destination texture region is not big "
			      "enough to hold the source region";

		if (dst_x == 0 && dst_y == 0 &&
		    src_x == 0 && src_y == 0 &&
		    src_w == 0 && src_h == 0) {
			copyWidth  = 0;
			copyHeight = 0;
		}

		device->CopyTex(dst2d->texture, dst_x, dst_y,
				src, src_x, src_y, copyWidth, copyHeight);

	} catch(const char *error) {
		blog(LOG_ERROR, "device_copy_texture (D3D11): %s", error);
	}
}

void device_copy_texture(gs_device_t *device, gs_texture_t *dst,
		gs_texture_t *src)
{
	device_copy_texture_region(device, dst, 0, 0, src, 0, 0, 0, 0);
}

void device_stage_texture(gs_device_t *device, gs_stagesurf_t *dst,
		gs_texture_t *src)
{
	try {
		gs_texture_2d *src2d = static_cast<gs_texture_2d*>(src);

		if (!src)
			throw "Source texture is NULL";
		if (src->type != GS_TEXTURE_2D)
			throw "Source texture must be a 2D texture";
		if (!dst)
			throw "Destination surface is NULL";
		if (dst->format != src->format)
			throw "Source and destination formats do not match";
		if (dst->width  != src2d->width ||
		    dst->height != src2d->height)
			throw "Source and destination must have the same "
			      "dimensions";

		device->CopyTex(dst->texture, 0, 0, src, 0, 0, 0, 0);

	} catch (const char *error) {
		blog(LOG_ERROR, "device_copy_texture (D3D11): %s", error);
	}
}

void device_begin_scene(gs_device_t *device)
{
	device->commandBuffer = [device->commandQueue commandBuffer];
}

void device_draw(gs_device_t *device, enum gs_draw_mode draw_mode,
		uint32_t start_vert, uint32_t num_verts)
{
	id<MTLRenderCommandEncoder> commandEncoder;
	id<MTLRenderPipelineState>  pipelineState;
	NSError *error = nil;
	
	try {
		if (!device->curVertexShader)
			throw "No vertex shader specified";
		
		if (!device->curPixelShader)
			throw "No pixel shader specified";
		
		if (!device->curVertexBuffer)
			throw "No vertex buffer specified";
		
		if (!device->curSwapChain && !device->curRenderTarget)
			throw "No render target or swap chain to render to";
		
		gs_effect_t *effect = gs_get_effect();
		if (effect)
			gs_effect_update_params(effect);
		
		device->UpdateBlendState();
		
	} catch (const char *error) {
		blog(LOG_ERROR, "device_draw (Metal): %s", error);
		return;
	}
	
	pipelineState = [device->device newRenderPipelineStateWithDescriptor:
			device->pipelineDesc error:&error];
	if (pipelineState == nil)
		throw error.localizedDescription.UTF8String;
		
	commandEncoder = [device->commandBuffer
			renderCommandEncoderWithDescriptor:passDesc];
	[commandEncoder setRenderPipelineState:pipelineState];
	
	try {
		device->LoadVertexBufferData(commandEncoder);
		device->UpdateRasterState();
		device->UpdateZStencilState();
		device->UpdateViewProjMatrix();
		device->curVertexShader->UploadParams();
		device->curPixelShader->UploadParams();

	} catch (const char *error) {
		[commandEncoder endEncoding];
		
		blog(LOG_ERROR, "device_draw (Metal): %s", error);
		return;
	}
	
	MTLPrimitiveType primitive = ConvertGSTopology(draw_mode);
	if (device->curIndexBuffer) {
		if (num_verts == 0)
			num_verts = (uint32_t)device->curIndexBuffer->num;
		[commandEncoder drawIndexedPrimitives:primitive
				indexCount:num_verts
				indexType:device->curIndexBuffer->indexType
				indexBuffer:device->curIndexBuffer->indexBuffer
				indexBufferOffset:0]
	} else {
		if (num_verts == 0)
			num_verts = (uint32_t)device->curVertexBuffer->numVerts;
		[commandEncoder drawPrimitives:primitive
				vertexStart:start_vert vertexCount:num_verts]
	}
	[commandEncoder endEncoding];
}

void device_end_scene(gs_device_t *device)
{
	/* does nothing in Metal */
	UNUSED_PARAMETER(device);
}

void device_load_swapchain(gs_device_t *device, gs_swapchain_t *swapchain)
{
	gs_texture_t  *target = device->curRenderTarget;
	gs_zstencil_t *zs     = device->curZStencilBuffer;
	bool is_cube = device->curRenderTarget ?
		(device->curRenderTarget->type == GS_TEXTURE_CUBE) : false;

	if (device->curSwapChain) {
		if (target == &device->curSwapChain->target)
			target = nullptr;
		if (zs == &device->curSwapChain->zs)
			zs = nullptr;
	}

	device->curSwapChain = swapchain;

	if (is_cube)
		device_set_cube_render_target(device, target,
				device->curRenderSide, zs);
	else
		device_set_render_target(device, target, zs);
}

void device_clear(gs_device_t *device, uint32_t clear_flags,
		const struct vec4 *color, float depth, uint8_t stencil)
{
	if (device->passDesc == nil)
		device->passDesc = [MTLRenderPassDescriptor new];
	
	if ((clear_flags & GS_CLEAR_COLOR) != 0) {
		MTLRenderPassColorAttachmentDescriptor *colorAttachment =
				device->passDesc.colorAttachments[0];
		colorAttachment.loadAction = MTLLoadActionClear;
		colorAttachment.clearColor = MTLClearColorMake(
				color->x, color->y, color->z, color->w);
	}

	if ((clear_flags & GS_CLEAR_DEPTH) != 0)
		device->passDesc.depthAttachment.clearDepth = depth;
	
	if ((clear_flags & GS_CLEAR_STENCIL) != 0)
		device->passDesc.stencilAttachment.clearStencil = stencil;
}

void device_present(gs_device_t *device)
{
	if (device->curSwapChain) {
		id<CAMetalDrawable> drawable =
				device->curSwapChain->metalView.currentDrawable;
		[device->commandBuffer presentDrawable:drawable];
	} else {
		blog(LOG_WARNING, "device_present (Metal): No active swap");
	}
}

void device_flush(gs_device_t *device)
{
	[device->commandBuffer commit];
}

void device_set_cull_mode(gs_device_t *device, enum gs_cull_mode mode)
{
	if (mode == device->rasterState.cullMode)
		return;

	device->rasterState.cullMode = mode;
	device->rasterStateChanged = true;
}

enum gs_cull_mode device_get_cull_mode(const gs_device_t *device)
{
	return device->rasterState.cullMode;
}

void device_enable_blending(gs_device_t *device, bool enable)
{
	if (enable == device->blendState.blendEnabled)
		return;

	device->blendState.blendEnabled = enable;
	device->blendStateChanged = true;
}

void device_enable_depth_test(gs_device_t *device, bool enable)
{
	if (enable == device->zstencilState.depthEnabled)
		return;

	device->zstencilState.depthEnabled = enable;
	device->zstencilStateChanged = true;
}

void device_enable_stencil_test(gs_device_t *device, bool enable)
{
	if (enable == device->zstencilState.stencilEnabled)
		return;

	device->zstencilState.stencilEnabled = enable;
	device->zstencilStateChanged = true;
}

void device_enable_stencil_write(gs_device_t *device, bool enable)
{
	if (enable == device->zstencilState.stencilWriteEnabled)
		return;

	device->zstencilState.stencilWriteEnabled = enable;
	device->zstencilStateChanged = true;
}

void device_enable_color(gs_device_t *device, bool red, bool green,
		bool blue, bool alpha)
{
	if (device->blendState.redEnabled   == red   &&
	    device->blendState.greenEnabled == green &&
	    device->blendState.blueEnabled  == blue  &&
	    device->blendState.alphaEnabled == alpha)
		return;

	device->blendState.redEnabled   = red;
	device->blendState.greenEnabled = green;
	device->blendState.blueEnabled  = blue;
	device->blendState.alphaEnabled = alpha;
	device->blendStateChanged       = true;
}

void device_blend_function(gs_device_t *device, enum gs_blend_type src,
		enum gs_blend_type dest)
{
	if (device->blendState.srcFactorC  == src &&
	    device->blendState.destFactorC == dest &&
	    device->blendState.srcFactorA  == src &&
	    device->blendState.destFactorA == dest)
		return;

	device->blendState.srcFactorC = src;
	device->blendState.destFactorC= dest;
	device->blendState.srcFactorA = src;
	device->blendState.destFactorA= dest;
	device->blendStateChanged     = true;
}

void device_blend_function_separate(gs_device_t *device,
		enum gs_blend_type src_c, enum gs_blend_type dest_c,
		enum gs_blend_type src_a, enum gs_blend_type dest_a)
{
	if (device->blendState.srcFactorC  == src_c &&
	    device->blendState.destFactorC == dest_c &&
	    device->blendState.srcFactorA  == src_a &&
	    device->blendState.destFactorA == dest_a)
		return;

	device->blendState.srcFactorC  = src_c;
	device->blendState.destFactorC = dest_c;
	device->blendState.srcFactorA  = src_a;
	device->blendState.destFactorA = dest_a;
	device->blendStateChanged      = true;
}

void device_depth_function(gs_device_t *device, enum gs_depth_test test)
{
	if (device->zstencilState.depthFunc == test)
		return;

	device->zstencilState.depthFunc = test;
	device->zstencilStateChanged    = true;
}

static inline void update_stencilside_test(gs_device_t *device,
		StencilSide &side, gs_depth_test test)
{
	if (side.test == test)
		return;

	side.test = test;
	device->zstencilStateChanged = true;
}

void device_stencil_function(gs_device_t *device, enum gs_stencil_side side,
		enum gs_depth_test test)
{
	int sideVal = (int)side;

	if (sideVal & GS_STENCIL_FRONT)
		update_stencilside_test(device,
				device->zstencilState.stencilFront, test);
	if (sideVal & GS_STENCIL_BACK)
		update_stencilside_test(device,
				device->zstencilState.stencilBack, test);
}

static inline void update_stencilside_op(gs_device_t *device, StencilSide &side,
		enum gs_stencil_op_type fail, enum gs_stencil_op_type zfail,
		enum gs_stencil_op_type zpass)
{
	if (side.fail == fail && side.zfail == zfail && side.zpass == zpass)
		return;

	side.fail  = fail;
	side.zfail = zfail;
	side.zpass = zpass;
	device->zstencilStateChanged = true;
}

void device_stencil_op(gs_device_t *device, enum gs_stencil_side side,
		enum gs_stencil_op_type fail, enum gs_stencil_op_type zfail,
		enum gs_stencil_op_type zpass)
{
	int sideVal = (int)side;

	if (sideVal & GS_STENCIL_FRONT)
		update_stencilside_op(device,
				device->zstencilState.stencilFront,
				fail, zfail, zpass);
	if (sideVal & GS_STENCIL_BACK)
		update_stencilside_op(device,
				device->zstencilState.stencilBack,
				fail, zfail, zpass);
}

void device_set_viewport(gs_device_t *device, int x, int y, int width,
		int height)
{
	D3D11_VIEWPORT vp;
	memset(&vp, 0, sizeof(vp));
	vp.MaxDepth = 1.0f;
	vp.TopLeftX = (float)x;
	vp.TopLeftY = (float)y;
	vp.Width    = (float)width;
	vp.Height   = (float)height;
	device->context->RSSetViewports(1, &vp);

	device->viewport.x  = x;
	device->viewport.y  = y;
	device->viewport.cx = width;
	device->viewport.cy = height;
}

void device_get_viewport(const gs_device_t *device, struct gs_rect *rect)
{
	memcpy(rect, &device->viewport, sizeof(gs_rect));
}

void device_set_scissor_rect(gs_device_t *device, const struct gs_rect *rect)
{
	D3D11_RECT d3drect;

	device->rasterState.scissorEnabled = (rect != NULL);

	if (rect != NULL) {
		d3drect.left   = rect->x;
		d3drect.top    = rect->y;
		d3drect.right  = rect->x + rect->cx;
		d3drect.bottom = rect->y + rect->cy;
		device->context->RSSetScissorRects(1, &d3drect);
	}

	device->rasterStateChanged = true;
}

void device_ortho(gs_device_t *device, float left, float right, float top,
		float bottom, float zNear, float zFar)
{
	matrix4 *dst = &device->curProjMatrix;

	float rml = right-left;
	float bmt = bottom-top;
	float fmn = zFar-zNear;

	vec4_zero(&dst->x);
	vec4_zero(&dst->y);
	vec4_zero(&dst->z);
	vec4_zero(&dst->t);

	dst->x.x =         2.0f /  rml;
	dst->t.x = (left+right) / -rml;

	dst->y.y =         2.0f / -bmt;
	dst->t.y = (bottom+top) /  bmt;

	dst->z.z =         1.0f /  fmn;
	dst->t.z =        zNear / -fmn;

	dst->t.w = 1.0f;
}

void device_frustum(gs_device_t *device, float left, float right, float top,
		float bottom, float zNear, float zFar)
{
	matrix4 *dst = &device->curProjMatrix;

	float rml    = right-left;
	float bmt    = bottom-top;
	float fmn    = zFar-zNear;
	float nearx2 = 2.0f*zNear;

	vec4_zero(&dst->x);
	vec4_zero(&dst->y);
	vec4_zero(&dst->z);
	vec4_zero(&dst->t);

	dst->x.x =       nearx2 /  rml;
	dst->z.x = (left+right) / -rml;

	dst->y.y =       nearx2 / -bmt;
	dst->z.y = (bottom+top) /  bmt;

	dst->z.z =         zFar /  fmn;
	dst->t.z = (zNear*zFar) / -fmn;

	dst->z.w = 1.0f;
}

void device_projection_push(gs_device_t *device)
{
	mat4float mat;
	memcpy(&mat, &device->curProjMatrix, sizeof(matrix4));
	device->projStack.push_back(mat);
}

void device_projection_pop(gs_device_t *device)
{
	if (!device->projStack.size())
		return;

	mat4float *mat = device->projStack.data();
	size_t end = device->projStack.size()-1;

	/* XXX - does anyone know a better way of doing this? */
	memcpy(&device->curProjMatrix, mat+end, sizeof(matrix4));
	device->projStack.pop_back();
}

void gs_swapchain_destroy(gs_swapchain_t *swapchain)
{
	if (swapchain->device->curSwapChain == swapchain)
		device_load_swapchain(swapchain->device, nullptr);

	delete swapchain;
}

void gs_texture_destroy(gs_texture_t *tex)
{
	delete tex;
}

uint32_t gs_texture_get_width(const gs_texture_t *tex)
{
	if (tex->type != GS_TEXTURE_2D)
		return 0;

	return static_cast<const gs_texture_2d*>(tex)->width;
}

uint32_t gs_texture_get_height(const gs_texture_t *tex)
{
	if (tex->type != GS_TEXTURE_2D)
		return 0;

	return static_cast<const gs_texture_2d*>(tex)->height;
}

enum gs_color_format gs_texture_get_color_format(const gs_texture_t *tex)
{
	if (tex->type != GS_TEXTURE_2D)
		return GS_UNKNOWN;

	return static_cast<const gs_texture_2d*>(tex)->format;
}

bool gs_texture_map(gs_texture_t *tex, uint8_t **ptr, uint32_t *linesize)
{
	if (tex->type != GS_TEXTURE_2D)
		return false;

	gs_texture_2d *tex2d = static_cast<gs_texture_2d*>(tex);
	*ptr      = (uint8_t*)[tex2d->texture contents];
	*linesize = [tex2d->texture bufferBytesPerRow];
	return true;
}

void gs_texture_unmap(gs_texture_t *tex)
{
	/* does nothing in Metal */
	UNUSED_PARAMETER(tex);
}

void *gs_texture_get_obj(gs_texture_t *tex)
{
	if (tex->type != GS_TEXTURE_2D)
		return nullptr;

	gs_texture_2d *tex2d = static_cast<gs_texture_2d*>(tex);
	return tex2d->texture;
}


void gs_cubetexture_destroy(gs_texture_t *cubetex)
{
	delete cubetex;
}

uint32_t gs_cubetexture_get_size(const gs_texture_t *cubetex)
{
	if (cubetex->type != GS_TEXTURE_CUBE)
		return 0;

	const gs_texture_2d *tex = static_cast<const gs_texture_2d*>(cubetex);
	return tex->width;
}

enum gs_color_format gs_cubetexture_get_color_format(
		const gs_texture_t *cubetex)
{
	if (cubetex->type != GS_TEXTURE_CUBE)
		return GS_UNKNOWN;

	const gs_texture_2d *tex = static_cast<const gs_texture_2d*>(cubetex);
	return tex->format;
}


void gs_voltexture_destroy(gs_texture_t *voltex)
{
	delete voltex;
}

uint32_t gs_voltexture_get_width(const gs_texture_t *voltex)
{
	/* TODO */
	UNUSED_PARAMETER(voltex);
	return 0;
}

uint32_t gs_voltexture_get_height(const gs_texture_t *voltex)
{
	/* TODO */
	UNUSED_PARAMETER(voltex);
	return 0;
}

uint32_t gs_voltexture_get_depth(const gs_texture_t *voltex)
{
	/* TODO */
	UNUSED_PARAMETER(voltex);
	return 0;
}

enum gs_color_format gs_voltexture_get_color_format(const gs_texture_t *voltex)
{
	/* TODO */
	UNUSED_PARAMETER(voltex);
	return GS_UNKNOWN;
}


void gs_stagesurface_destroy(gs_stagesurf_t *stagesurf)
{
	delete stagesurf;
}

uint32_t gs_stagesurface_get_width(const gs_stagesurf_t *stagesurf)
{
	return stagesurf->width;
}

uint32_t gs_stagesurface_get_height(const gs_stagesurf_t *stagesurf)
{
	return stagesurf->height;
}

enum gs_color_format gs_stagesurface_get_color_format(
		const gs_stagesurf_t *stagesurf)
{
	return stagesurf->format;
}

bool gs_stagesurface_map(gs_stagesurf_t *stagesurf, uint8_t **data,
		uint32_t *linesize)
{
	*ptr      = (uint8_t*)[stagesurf->texture contents];
	*linesize = [stagesurf->texture bufferBytesPerRow];
	return true;
}

void gs_stagesurface_unmap(gs_stagesurf_t *stagesurf)
{
	/* does nothing in Metal */
	UNUSED_PARAMETER(stagesurf);
}


void gs_zstencil_destroy(gs_zstencil_t *zstencil)
{
	delete zstencil;
}


void gs_samplerstate_destroy(gs_samplerstate_t *samplerstate)
{
	if (!samplerstate)
		return;

	if (samplerstate->device)
		for (int i = 0; i < GS_MAX_TEXTURES; i++)
			if (samplerstate->device->curSamplers[i] ==
					samplerstate)
				samplerstate->device->curSamplers[i] = nullptr;

	delete samplerstate;
}


void gs_vertexbuffer_destroy(gs_vertbuffer_t *vertbuffer)
{
	if (vertbuffer && vertbuffer->device->lastVertexBuffer == vertbuffer)
		vertbuffer->device->lastVertexBuffer = nullptr;
	delete vertbuffer;
}

void gs_vertexbuffer_flush(gs_vertbuffer_t *vertbuffer)
{
	if (!vertbuffer->dynamic) {
		blog(LOG_ERROR, "gs_vertexbuffer_flush: vertex buffer is "
		                "not dynamic");
		return;
	}

	vertbuffer->FlushBuffer(vertbuffer->vertexBuffer,
			vertbuffer->vbd.data->points, sizeof(vec3));

	if (vertbuffer->normalBuffer)
		vertbuffer->FlushBuffer(vertbuffer->normalBuffer,
				vertbuffer->vbd.data->normals, sizeof(vec3));

	if (vertbuffer->tangentBuffer)
		vertbuffer->FlushBuffer(vertbuffer->tangentBuffer,
				vertbuffer->vbd.data->tangents, sizeof(vec3));

	if (vertbuffer->colorBuffer)
		vertbuffer->FlushBuffer(vertbuffer->colorBuffer,
				vertbuffer->vbd.data->colors, sizeof(uint32_t));

	for (size_t i = 0; i < vertbuffer->uvBuffers.size(); i++) {
		gs_tvertarray &tv = vertbuffer->vbd.data->tvarray[i];
		vertbuffer->FlushBuffer(vertbuffer->uvBuffers[i],
				tv.array, tv.width*sizeof(float));
	}
}

struct gs_vb_data *gs_vertexbuffer_get_data(const gs_vertbuffer_t *vertbuffer)
{
	return vertbuffer->vbd.data;
}


void gs_indexbuffer_destroy(gs_indexbuffer_t *indexbuffer)
{
	delete indexbuffer;
}

void gs_indexbuffer_flush(gs_indexbuffer_t *indexbuffer)
{
	if (!indexbuffer->dynamic)
		return;
	
	memcpy(map.pData, [indexbuffer->indexBuffer contents],
			indexbuffer->num * indexbuffer->indexSize);
}

void *gs_indexbuffer_get_data(const gs_indexbuffer_t *indexbuffer)
{
	return indexbuffer->indices.data;
}

size_t gs_indexbuffer_get_num_indices(const gs_indexbuffer_t *indexbuffer)
{
	return indexbuffer->num;
}

enum gs_index_type gs_indexbuffer_get_type(const gs_indexbuffer_t *indexbuffer)
{
	return indexbuffer->type;
}
