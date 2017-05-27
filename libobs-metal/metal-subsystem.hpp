#pragma once

#include <util/AlignedNew.hpp>

#include <vector>
#include <string>
#include <memory>

#include <util/base.h>
#include <graphics/matrix4.h>
#include <graphics/graphics.h>
#include <graphics/device-exports.h>

#import <MetalKit/MetalKit.h>

struct shader_var;
struct shader_sampler;
struct gs_vertex_shader;

using namespace std;


static inline MTLPixelFormat ConvertGSTextureFormat(gs_color_format format)
{
	switch (format) {
	case GS_UNKNOWN:     return MTLPixelFormatInvalid;
	case GS_A8:          return MTLPixelFormatA8Unorm;
	case GS_R8:          return MTLPixelFormatR8Unorm;
	case GS_RGBA:        return MTLPixelFormatRGBA8Unorm;
	case GS_BGRX:        return MTLPixelFormatBGRA8Unorm;
	case GS_BGRA:        return MTLPixelFormatBGRA8Unorm;
	case GS_R10G10B10A2: return MTLPixelFormatRGB10A2Unorm;
	case GS_RGBA16:      return MTLPixelFormatRGBA16Unorm;
	case GS_R16:         return MTLPixelFormatR16Unorm;
	case GS_RGBA16F:     return MTLPixelFormatRGBA16Float;
	case GS_RGBA32F:     return MTLPixelFormatRGBA32Float;
	case GS_RG16F:       return MTLPixelFormatRG16Float;
	case GS_RG32F:       return MTLPixelFormatRG32Float;
	case GS_R16F:        return MTLPixelFormatR16Float;
	case GS_R32F:        return MTLPixelFormatR32Float;
	case GS_DXT1:        return MTLPixelFormatBC1_RGBA;
	case GS_DXT3:        return MTLPixelFormatBC2_RGBA;
	case GS_DXT5:        return MTLPixelFormatBC3_RGBA;
	}

	return MTLPixelFormatInvalid;
}

static inline gs_color_format ConvertDXGITextureFormat(MTLPixelFormat format)
{
	switch ((unsigned long)format) {
	case MTLPixelFormatA8Unorm:       return GS_A8;
	case MTLPixelFormatR8Unorm:       return GS_R8;
	case MTLPixelFormatRGBA8Unorm:    return GS_RGBA;
	case MTLPixelFormatBGRA8Unorm:    return GS_BGRA;
	case MTLPixelFormatRGB10A2Unorm:  return GS_R10G10B10A2;
	case MTLPixelFormatRGBA16Unorm:   return GS_RGBA16;
	case MTLPixelFormatR16Unorm:      return GS_R16;
	case MTLPixelFormatRGBA16Float:   return GS_RGBA16F;
	case MTLPixelFormatRGBA32Float:   return GS_RGBA32F;
	case MTLPixelFormatRG16Float:     return GS_RG16F;
	case MTLPixelFormatRG32Float:     return GS_RG32F;
	case MTLPixelFormatR16Float:      return GS_R16F;
	case MTLPixelFormatR32Float:      return GS_R32F;
	case MTLPixelFormatBC1_RGBA:      return GS_DXT1;
	case MTLPixelFormatBC2_RGBA:      return GS_DXT3;
	case MTLPixelFormatBC3_RGBA:      return GS_DXT5;
	}

	return GS_UNKNOWN;
}

static inline MTLPixelFormat ConvertGSZStencilFormat(gs_zstencil_format format)
{
	switch (format) {
	case GS_ZS_NONE:     return MTLPixelFormatInvalid;
	case GS_Z16:         return MTLPixelFormatDepth16Unorm;
	case GS_Z24_S8:      return MTLPixelFormatDepth24Unorm_Stencil8;
	case GS_Z32F:        return MTLPixelFormatDepth32Float;
	case GS_Z32F_S8X24:  return MTLPixelFormatDepth32Float_Stencil8;
	}

	return MTLPixelFormatInvalid;
}

static inline MTLCompareFunction ConvertGSDepthTest(gs_depth_test test)
{
	switch (test) {
	case GS_NEVER:    return MTLCompareFunctionNever;
	case GS_LESS:     return MTLCompareFunctionLess;
	case GS_LEQUAL:   return MTLCompareFunctionLessEqual;
	case GS_EQUAL:    return MTLCompareFunctionEqual;
	case GS_GEQUAL:   return MTLCompareFunctionGreaterEqual;
	case GS_GREATER:  return MTLCompareFunctionGreater;
	case GS_NOTEQUAL: return MTLCompareFunctionNotEqual;
	case GS_ALWAYS:   return MTLCompareFunctionAlways;
	}

	return MTLCompareFunctionNever;
}

static inline MTLStencilOperation ConvertGSStencilOp(gs_stencil_op_type op)
{
	switch (op) {
	case GS_KEEP:    return MTLStencilOperationKeep;
	case GS_ZERO:    return MTLStencilOperationZero;
	case GS_REPLACE: return MTLStencilOperationReplace;
	case GS_INCR:    return MTLStencilOperationIncrementWrap;
	case GS_DECR:    return MTLStencilOperationDecrementWrap;
	case GS_INVERT:  return MTLStencilOperationInvert;
	}

	return MTLStencilOperationKeep;
}

static inline MTLBlendFactor ConvertGSBlendType(gs_blend_type type)
{
	switch (type) {
	case GS_BLEND_ZERO:        return MTLBlendFactorZero;
	case GS_BLEND_ONE:         return MTLBlendFactorOne;
	case GS_BLEND_SRCCOLOR:    return MTLBlendFactorSourceColor;
	case GS_BLEND_INVSRCCOLOR: return MTLBlendFactorOneMinusSourceColor;
	case GS_BLEND_SRCALPHA:    return MTLBlendFactorSourceAlpha;
	case GS_BLEND_INVSRCALPHA: return MTLBlendFactorOneMinusSourceAlpha;
	case GS_BLEND_DSTCOLOR:    return MTLBlendFactorDestinationColor;
	case GS_BLEND_INVDSTCOLOR: return MTLBlendFactorOneMinusDestinationColor;
	case GS_BLEND_DSTALPHA:    return MTLBlendFactorDestinationAlpha;
	case GS_BLEND_INVDSTALPHA: return MTLBlendFactorOneMinusDestinationAlpha;
	case GS_BLEND_SRCALPHASAT: return MTLBlendFactorSourceAlphaSaturated;
	}

	return MTLBlendFactorOne;
}

static inline MTLCullMode ConvertGSCullMode(gs_cull_mode mode)
{
	switch (mode) {
	case GS_BACK:    return MTLCullModeBack;
	case GS_FRONT:   return MTLCullModeFront;
	case GS_NEITHER: return MTLCullModeNone;
	}

	return MTLCullModeBack;
}

static inline MTLPrimitiveType ConvertGSTopology(gs_draw_mode mode)
{
	switch (mode) {
	case GS_POINTS:    return MTLPrimitiveTypePoint;
	case GS_LINES:     return MTLPrimitiveTypeLine;
	case GS_LINESTRIP: return MTLPrimitiveTypeLineStrip;
	case GS_TRIS:      return MTLPrimitiveTypeTriangle;
	case GS_TRISTRIP:  return MTLPrimitiveTypeTriangleStrip;
	}

	return MTLPrimitiveTypePoint;
}

/* exception-safe RAII wrapper for vertex buffer data (NOTE: not copy-safe) */
struct VBDataPtr {
	gs_vb_data *data;

	inline VBDataPtr(gs_vb_data *data) : data(data) {}
	inline ~VBDataPtr() {gs_vbdata_destroy(data);}
};

enum class gs_type {
	gs_vertex_buffer,
	gs_index_buffer,
	gs_texture_2d,
	gs_zstencil_buffer,
	gs_stage_surface,
	gs_sampler_state,
	gs_vertex_shader,
	gs_pixel_shader,
	gs_swap_chain,
};

struct gs_obj {
	gs_device_t *device;
	gs_type obj_type;
	gs_obj *next;
	gs_obj **prev_next;

	inline gs_obj() :
		device(nullptr),
		next(nullptr),
		prev_next(nullptr)
	{}

	gs_obj(gs_device_t *device, gs_type type);
	virtual ~gs_obj();
};

struct gs_vertex_buffer : gs_obj {
	id<MTLBuffer>         vertexBuffer;
	id<MTLBuffer>         normalBuffer;
	id<MTLBuffer>         colorBuffer;
	id<MTLBuffer>         tangentBuffer;
	vector<id<MTLBuffer>> uvBuffers;

	bool           dynamic;
	VBDataPtr      vbd;
	size_t         numVerts;
	vector<size_t> uvSizes;

	void FlushBuffer(id<MTLBuffer> buffer, void *array,
			size_t elementSize);

	void MakeBufferList(gs_vertex_shader *shader,
			vector<id<MTLBuffer>> &buffers);

	void InitBuffer(const size_t elementSize,
			const size_t numVerts, void *array,
			id<MTLBuffer> &buffer);

	void BuildBuffers();

	inline void Release()
	{
		CFRelease(vertexBuffer);
		CFRelease(normalBuffer);
		CFRelease(colorBuffer);
		CFRelease(tangentBuffer);
		for (auto buffer : uvBuffers)
			CFRelease(buffer);
		uvBuffers.clear();
	}

	inline void Rebuild();

	gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data,
			uint32_t flags);
};

/* exception-safe RAII wrapper for index buffer data (NOTE: not copy-safe) */
struct DataPtr {
	void *data;

	inline DataPtr(void *data) : data(data) {}
	inline ~DataPtr() {bfree(data);}
};

struct gs_index_buffer : gs_obj {
	id<MTLBuffer> indexBuffer;
	bool          dynamic;
	gs_index_type type;
	size_t        num;
	DataPtr       indices;
	
	size_t        indexSize;
	MTLIndexType  indexType;

	void InitBuffer();

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release() {CFRelease(indexBuffer);}

	gs_index_buffer(gs_device_t *device, enum gs_index_type type,
			void *indices, size_t num, uint32_t flags);
};

struct gs_texture : gs_obj {
	gs_texture_type type;
	uint32_t        levels;
	gs_color_format format;

	inline void Rebuild(id<MTLDevice> dev);

	inline gs_texture(gs_texture_type type, uint32_t levels,
			gs_color_format format)
		: type   (type),
		  levels (levels),
		  format (format)
	{
	}

	inline gs_texture(gs_device *device, gs_type obj_type,
			gs_texture_type type)
		: gs_obj (device, obj_type),
		  type   (type)
	{
	}

	inline gs_texture(gs_device *device, gs_type obj_type,
			gs_texture_type type,
			uint32_t levels, gs_color_format format)
		: gs_obj (device, obj_type),
		  type   (type),
		  levels (levels),
		  format (format)
	{
	}
};

struct gs_texture_2d : gs_texture {
	id<MTLTexture> texture;

	uint32_t       width = 0, height = 0;
	MTLPixelFormat mtlPixelFormat = MTLPixelFormatInvalid;
	bool           isRenderTarget = false;
	bool           isDynamic = false;
	bool           isShared = false;
	bool           genMipmaps = false;
	
	vector<vector<uint8_t>> data;
	MTLTextureDescriptor *td = nil;

	void InitTexture(const uint8_t **data);
	void BackupTexture(const uint8_t **data);

	void RebuildSharedTextureFallback();
	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		CFRelease(texture);
	}

	inline gs_texture_2d()
		: gs_texture (GS_TEXTURE_2D, 0, GS_UNKNOWN)
	{
	}

	gs_texture_2d(gs_device_t *device, uint32_t width, uint32_t height,
			gs_color_format colorFormat, uint32_t levels,
			const uint8_t **data, uint32_t flags,
			gs_texture_type type, bool shared);

	gs_texture_2d(gs_device_t *device, uint32_t handle);
};

struct gs_zstencil_buffer : gs_obj {
	id<MTLTexture>                           texture;
	MTLTextureDescriptor                     *td   = nullptr;
	MTLRenderPassStencilAttachmentDescriptor *desc = nullptr;

	uint32_t           width, height;
	gs_zstencil_format format;
	MTLPixelFormat     mtlPixelFormat;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		CFRelease(texture);
		[td release];
		[desc release];
	}

	inline gs_zstencil_buffer()
		: width          (0),
		  height         (0),
		  mtlPixelFormat (MTLPixelFormatInvalid)
	{
	}

	gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height,
			gs_zstencil_format format);
};

struct gs_stage_surface : gs_obj {
	id<MTLTexture>  texture;
	MTLTextureDescriptor *td = nil;

	uint32_t        width, height;
	gs_color_format format;
	MTLPixelFormat  mtlPixelFormat;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		CFRelease(texture);
	}

	gs_stage_surface(gs_device_t *device, uint32_t width, uint32_t height,
			gs_color_format colorFormat);
};

struct gs_sampler_state : gs_obj {
	id<MTLSamplerState>  state;
	MTLSamplerDescriptor *sd = nil;
	
	gs_sampler_info      info;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		CFRelease(state);
		[sd release];
	}

	gs_sampler_state(gs_device_t *device, const gs_sampler_info *info);
};

struct gs_shader_param {
	string                         name;
	gs_shader_param_type           type;

	uint32_t                       textureID;
	struct gs_sampler_state        *nextSampler = nullptr;

	int                            arrayCount;

	size_t                         pos;

	vector<uint8_t>                curValue;
	vector<uint8_t>                defaultValue;
	bool                           changed;

	gs_shader_param(shader_var &var, uint32_t &texCounter);
};

struct ShaderError {
	NSError *error;

	inline ShaderError(NSError *error)
		: error (error)
	{
	}
};

struct gs_shader : gs_obj {
	gs_shader_type          type;
	vector<gs_shader_param> params;
	id<MTLBuffer>           constants;
	size_t                  constantSize;

	vector<uint8_t>         data;

	inline void UpdateParam(vector<uint8_t> &constData,
			gs_shader_param &param, bool &upload);
	void UploadParams();

	void BuildConstantBuffer();
	void Compile(const char *shaderStr, id<MTLLibrary> &library);

	inline gs_shader(gs_device_t *device, gs_type obj_type,
			gs_shader_type type)
		: gs_obj       (device, obj_type),
		  type         (type),
		  constantSize (0)
	{
	}

	virtual ~gs_shader() {}
};

struct ShaderSampler {
	string           name;
	gs_sampler_state sampler;

	inline ShaderSampler(const char *name, gs_device_t *device,
			gs_sampler_info *info)
		: name    (name),
		  sampler (device, info)
	{
	}
};

struct gs_vertex_shader : gs_shader {
	ComPtr<ID3D11VertexShader> shader;
	ComPtr<ID3D11InputLayout>  layout;

	gs_shader_param *world, *viewProj;

	vector<D3D11_INPUT_ELEMENT_DESC> layoutData;

	bool     hasNormals;
	bool     hasColors;
	bool     hasTangents;
	uint32_t nTexUnits;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		shader.Release();
		layout.Release();
		constants.Release();
	}

	inline uint32_t NumBuffersExpected() const
	{
		uint32_t count = nTexUnits + 1;
		if (hasNormals)  count++;
		if (hasColors)   count++;
		if (hasTangents) count++;

		return count;
	}

	void GetBuffersExpected(const vector<D3D11_INPUT_ELEMENT_DESC> &inputs);

	gs_vertex_shader(gs_device_t *device, const char *file,
			const char *shaderString);
};

struct gs_pixel_shader : gs_shader {
	ComPtr<ID3D11PixelShader> shader;
	vector<unique_ptr<ShaderSampler>> samplers;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		shader.Release();
		constants.Release();
	}

	inline void GetSamplerStates(ID3D11SamplerState **states)
	{
		size_t i;
		for (i = 0; i < samplers.size(); i++)
			states[i] = samplers[i]->sampler.state;
		for (; i < GS_MAX_TEXTURES; i++)
			states[i] = NULL;
	}

	gs_pixel_shader(gs_device_t *device, const char *file,
			const char *shaderString);
};

struct gs_swap_chain : gs_obj {
	uint32_t           numBuffers;
	NSView             *view = nil;
	gs_init_data       initData;
	MTKView            *metalView;

	void Resize(uint32_t cx, uint32_t cy);
	void Init();

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		view = nil;
		CFRelease(metalView);
	}

	gs_swap_chain(gs_device *device, const gs_init_data *data);
};

struct BlendState {
	bool          blendEnabled;
	gs_blend_type srcFactorC;
	gs_blend_type destFactorC;
	gs_blend_type srcFactorA;
	gs_blend_type destFactorA;

	bool          redEnabled;
	bool          greenEnabled;
	bool          blueEnabled;
	bool          alphaEnabled;

	inline BlendState()
		: blendEnabled (true),
		  srcFactorC   (GS_BLEND_SRCALPHA),
		  destFactorC  (GS_BLEND_INVSRCALPHA),
		  srcFactorA   (GS_BLEND_ONE),
		  destFactorA  (GS_BLEND_ONE),
		  redEnabled   (true),
		  greenEnabled (true),
		  blueEnabled  (true),
		  alphaEnabled (true)
	{
	}

	inline BlendState(const BlendState &state)
	{
		memcpy(this, &state, sizeof(BlendState));
	}
};

struct SavedBlendState : BlendState {
	MTLRenderPipelineColorAttachmentDescriptor *cad = nil;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		[cad release];
	}

	inline SavedBlendState(const BlendState &val,
			MTLRenderPipelineColorAttachmentDescriptor *cad)
		: BlendState(val), cad(cad)
	{
	}
};

struct StencilSide {
	gs_depth_test test;
	gs_stencil_op_type fail;
	gs_stencil_op_type zfail;
	gs_stencil_op_type zpass;

	inline StencilSide()
		: test  (GS_ALWAYS),
		  fail  (GS_KEEP),
		  zfail (GS_KEEP),
		  zpass (GS_KEEP)
	{
	}
};

struct ZStencilState {
	bool          depthEnabled;
	bool          depthWriteEnabled;
	gs_depth_test depthFunc;

	bool          stencilEnabled;
	bool          stencilWriteEnabled;
	StencilSide   stencilFront;
	StencilSide   stencilBack;

	inline ZStencilState()
		: depthEnabled        (true),
		  depthWriteEnabled   (true),
		  depthFunc           (GS_LESS),
		  stencilEnabled      (false),
		  stencilWriteEnabled (true)
	{
	}

	inline ZStencilState(const ZStencilState &state)
	{
		memcpy(this, &state, sizeof(ZStencilState));
	}
};

struct SavedZStencilState : ZStencilState {
	id<MTLDepthStencilState>  state;
	MTLDepthStencilDescriptor *dsd = nil;

	inline void Rebuild(id<MTLDevice> dev);

	inline void Release()
	{
		CFRelease(state);
		[dsd release];
	}

	inline SavedZStencilState(const ZStencilState &val,
			MTLDepthStencilDescriptor *dsd)
		: ZStencilState (val),
		  dsd           (dsd)
	{
	}
};

struct RasterState {
	gs_cull_mode cullMode;
	bool         scissorEnabled;

	inline RasterState()
		: cullMode       (GS_BACK),
		  scissorEnabled (false)
	{
	}

	inline RasterState(const RasterState &state)
	{
		memcpy(this, &state, sizeof(RasterState));
	}
};

struct SavedRasterState : RasterState {
	ComPtr<ID3D11RasterizerState> state;
	D3D11_RASTERIZER_DESC         rd;

	inline void Rebuild(ID3D11Device *dev);

	inline void Release()
	{
		state.Release();
	}

	inline SavedRasterState(const RasterState &val,
			D3D11_RASTERIZER_DESC &desc)
	       : RasterState (val),
	         rd          (desc)
	{
	}
};

struct mat4float {
	float mat[16];
};

struct gs_device {
	id<MTLDevice>               device;
	id<MTLCommandQueue>         commandQueue;
	id<MTLCommandBuffer>        commandBuffer;
	MTLRenderPipelineDescriptor *pipelineDesc;
	MTLRenderPassDescriptor     *passDesc;
    
	uint32_t                    devIdx = 0;

	gs_texture_2d               *curRenderTarget = nullptr;
	gs_zstencil_buffer          *curZStencilBuffer = nullptr;
	int                         curRenderSide = 0;
	gs_texture                  *curTextures[GS_MAX_TEXTURES];
	gs_sampler_state            *curSamplers[GS_MAX_TEXTURES];
	gs_vertex_buffer            *curVertexBuffer = nullptr;
	gs_index_buffer             *curIndexBuffer = nullptr;
	gs_vertex_shader            *curVertexShader = nullptr;
	gs_pixel_shader             *curPixelShader = nullptr;
	gs_swap_chain               *curSwapChain = nullptr;

	bool                        zstencilStateChanged = true;
	bool                        rasterStateChanged = true;
	bool                        blendStateChanged = true;
	ZStencilState               zstencilState;
	RasterState                 rasterState;
	BlendState                  blendState;
	vector<SavedZStencilState>  zstencilStates;
	vector<SavedRasterState>    rasterStates;
	vector<SavedBlendState>     blendStates;
	ID3D11DepthStencilState     *curDepthStencilState = nullptr;
	ID3D11RasterizerState       *curRasterState = nullptr;
	ID3D11BlendState            *curBlendState = nullptr;

	gs_rect                     viewport;

	vector<mat4float>           projStack;

	matrix4                     curProjMatrix;
	matrix4                     curViewMatrix;
	matrix4                     curViewProjMatrix;

	gs_obj                      *first_obj
    
	void InitDevice(uint32_t adapterIdx);

	id<MTLDepthStencilState> AddZStencilState();
	ID3D11RasterizerState   *AddRasterState();
	ID3D11BlendState        *AddBlendState();
	void UpdateZStencilState();
	void UpdateRasterState();
	void UpdateBlendState();

	void LoadVertexBufferData(id<MTLRenderCommandEncoder> commandEncoder);

	inline void CopyTex(ID3D11Texture2D *dst,
			uint32_t dst_x, uint32_t dst_y,
			gs_texture_t *src, uint32_t src_x, uint32_t src_y,
			uint32_t src_w, uint32_t src_h);

	void UpdateViewProjMatrix();

	void RebuildDevice();

	gs_device(uint32_t adapterIdx);
	~gs_device();
};
