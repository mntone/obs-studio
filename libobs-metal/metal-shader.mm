#include <graphics/vec2.h>
#include <graphics/vec3.h>
#include <graphics/matrix3.h>
#include <graphics/matrix4.h>

#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

using namespace std;

static MTLCompileOptions *mtlCompileOptions = nil;

gs_vertex_shader::gs_vertex_shader(gs_device_t *device, const char *file,
		const char *shaderString)
	: gs_shader   (device, gs_type::gs_vertex_shader, GS_SHADER_VERTEX),
	  hasNormals  (false),
	  hasColors   (false),
	  hasTangents (false),
	  texUnits    (0)
{
	ShaderProcessor     processor;
	string              outputString;
	ShaderBufferInfo    info;
	MTLVertexDescriptor *vertdesc;
	
	vertdesc = [[MTLVertexDescriptor alloc] init];

	processor.Process(shaderString, file);
	outputString = processor.BuildString(type);
	processor.BuildParams(params);
	processor.BuildParamInfo(info);
	processor.BuildVertexDesc(vertdesc);
	BuildConstantBuffer();

	Compile(outputString);

	hasNormals  = info.normals;
	hasColors   = info.colors;
	hasTangents = info.tangents;
	texUnits    = info.texUnits;
	
	vertexDesc  = vertdesc;
	
	viewProj    = gs_shader_get_param_by_name(this, "ViewProj");
	world       = gs_shader_get_param_by_name(this, "World");
}

gs_pixel_shader::gs_pixel_shader(gs_device_t *device, const char *file,
		const char *shaderString)
	: gs_shader(device, gs_type::gs_pixel_shader, GS_SHADER_PIXEL)
{
	ShaderProcessor processor;
	string          outputString;
	
	processor.Process(shaderString, file);
	outputString = processor.BuildString(type);
	processor.BuildParams(params);
	BuildConstantBuffer();

	Compile(outputString);
}

void gs_shader::BuildConstantBuffer()
{
	for (size_t i = 0; i < params.size(); i++) {
		gs_shader_param &param = params[i];
		size_t       size   = 0;

		switch (param.type) {
		case GS_SHADER_PARAM_BOOL:
		case GS_SHADER_PARAM_INT:
		case GS_SHADER_PARAM_FLOAT:     size = sizeof(float);     break;
		case GS_SHADER_PARAM_INT2:
		case GS_SHADER_PARAM_VEC2:      size = sizeof(vec2);      break;
		case GS_SHADER_PARAM_INT3:
		case GS_SHADER_PARAM_VEC3:      size = sizeof(float) * 3; break;
		case GS_SHADER_PARAM_INT4:
		case GS_SHADER_PARAM_VEC4:      size = sizeof(vec4);      break;
		case GS_SHADER_PARAM_MATRIX4X4:
			size = sizeof(float) * 4 * 4;
			break;
		case GS_SHADER_PARAM_TEXTURE:
		case GS_SHADER_PARAM_STRING:
		case GS_SHADER_PARAM_UNKNOWN:
			continue;
		}

		/* checks to see if this constant needs to start at a new
		 * register */
		if (size && (constantSize & 15) != 0) {
			size_t alignMax = (constantSize + 15) & ~15;

			if ((size + constantSize) > alignMax)
				constantSize = alignMax;
		}

		param.pos     = constantSize;
		constantSize += size;
	}

	for (size_t i = 0; i < params.size(); i++)
		gs_shader_set_default(&params[i]);
	
	InitConstantBuffer();
}


void gs_shader::InitConstantBuffer()
{
	if (constantCapacity == 0)
		constantCapacity = 4;
	
	if (constantSize) {
		constantActualSize = (constantSize + 255) & ~255;
		
		NSUInteger length = constantActualSize * constantCapacity;
		MTLResourceOptions options =
				MTLResourceCPUCacheModeWriteCombined |
				MTLResourceStorageModeShared;
		
		constants = [device->device newBufferWithLength:length
				options:options];
		if (constants == nil)
			throw "Failed to create constant buffer";
		
		constants.label = @"constants";
	}
}

size_t gs_shader::NextConstantBufferOffset()
{
	if (constantSlot >= constantCapacity) {
		constantCapacity *= 2;
		
		oldConstants.push_back(constants);
		
		InitConstantBuffer();
	}
	
	return constantActualSize * constantSlot++;
}

void gs_shader::ResetState()
{
	oldConstants.clear();
	
	constantSlot = 0;
}

void gs_shader::Compile(string shaderString)
{
	if (mtlCompileOptions == nil) {
		mtlCompileOptions = [[MTLCompileOptions alloc] init];
		mtlCompileOptions.languageVersion = MTLLanguageVersion1_1;
	}
	
	NSString *nsShaderString = [[NSString alloc]
			initWithBytesNoCopy:(void*)shaderString.data()
			length:shaderString.length()
			encoding:NSUTF8StringEncoding freeWhenDone:NO];
	NSError *errors;
	id<MTLLibrary> lib = [device->device newLibraryWithSource:nsShaderString
			options:mtlCompileOptions error:&errors];
	if (lib == nil) {
		blog(LOG_DEBUG, "Converted shader program:\n%s\n------\n",
				shaderString.c_str());
		
		if (errors != nil)
			throw ShaderError(errors);
		else
			throw "Failed to compile shader";
	}
	
	id<MTLFunction> func = [lib newFunctionWithName:@"_main"];
	if (func == nil)
		throw "Failed to create function";
	
	library  = lib;
	function = func;
}

inline void gs_shader::UpdateParam(uint8_t *data, gs_shader_param &param)
{
	if (param.type != GS_SHADER_PARAM_TEXTURE) {
		if (!param.curValue.size())
			throw "Not all shader parameters were set";
		
		//if (param.changed) {
			memcpy(data + param.pos, param.curValue.data(),
					param.curValue.size());
		//	param.changed = false;
		//}

	} else if (param.curValue.size() == sizeof(gs_texture_t*)) {
		gs_texture_t *tex;
		memcpy(&tex, param.curValue.data(), sizeof(gs_texture_t*));
		device_load_texture(device, tex, param.textureID);

		/*if (param.nextSampler) {
			ID3D11SamplerState *state = param.nextSampler->state;
			device->context->PSSetSamplers(param.textureID, 1,
					&state);
			param.nextSampler = nullptr;
		}*/
	}
}

void gs_shader::UploadParams(id<MTLRenderCommandEncoder> commandEncoder)
{
	uint8_t *data;
	size_t offset;
	
	offset = NextConstantBufferOffset();
	data = (uint8_t *)constants.contents + offset;
	
	for (size_t i = 0; i < params.size(); i++)
		UpdateParam(data, params[i]);
	
	if (type == GS_SHADER_VERTEX)
		[commandEncoder setVertexBuffer:constants
				offset:offset atIndex:30];
	else if (type == GS_SHADER_PIXEL)
		[commandEncoder setFragmentBuffer:constants
				offset:offset atIndex:30];
	else
		throw "This is unknown shader type";
}

void gs_shader_destroy(gs_shader_t *shader)
{
	assert(shader != nullptr);
	
	if (shader->device->lastVertexShader == shader)
		shader->device->lastVertexShader = nullptr;
	
	delete shader;
}

int gs_shader_get_num_params(const gs_shader_t *shader)
{
	assert(shader != nullptr);
	
	return (int)shader->params.size();
}

gs_sparam_t *gs_shader_get_param_by_idx(gs_shader_t *shader, uint32_t param)
{
	assert(shader != nullptr);
	
	return &shader->params[param];
}

gs_sparam_t *gs_shader_get_param_by_name(gs_shader_t *shader, const char *name)
{
	for (size_t i = 0; i < shader->params.size(); i++) {
		gs_shader_param &param = shader->params[i];
		if (strcmp(param.name.c_str(), name) == 0)
			return &param;
	}

	return nullptr;
}

gs_sparam_t *gs_shader_get_viewproj_matrix(const gs_shader_t *shader)
{
	assert(shader != nullptr);
	
	if (shader->type != GS_SHADER_VERTEX)
		return nullptr;

	return static_cast<const gs_vertex_shader*>(shader)->viewProj;
}

gs_sparam_t *gs_shader_get_world_matrix(const gs_shader_t *shader)
{
	assert(shader != nullptr);
	
	if (shader->type != GS_SHADER_VERTEX)
		return nullptr;

	return static_cast<const gs_vertex_shader*>(shader)->world;
}

void gs_shader_get_param_info(const gs_sparam_t *param,
		struct gs_shader_param_info *info)
{
	if (!param)
		return;

	info->name = param->name.c_str();
	info->type = param->type;
}

static inline void shader_setval_inline(gs_shader_param *param,
		const void *data, size_t size)
{
	assert(param);
	
	if (!param)
		return;

	bool size_changed = param->curValue.size() != size;
	if (size_changed)
		param->curValue.resize(size);

	if (size_changed || memcmp(param->curValue.data(), data, size) != 0) {
		memcpy(param->curValue.data(), data, size);
		param->changed = true;
	}
}

void gs_shader_set_bool(gs_sparam_t *param, bool val)
{
	int b_val = (int)val;
	shader_setval_inline(param, &b_val, sizeof(int));
}

void gs_shader_set_float(gs_sparam_t *param, float val)
{
	shader_setval_inline(param, &val, sizeof(float));
}

void gs_shader_set_int(gs_sparam_t *param, int val)
{
	shader_setval_inline(param, &val, sizeof(int));
}

void gs_shader_set_matrix3(gs_sparam_t *param, const struct matrix3 *val)
{
	struct matrix4 mat;
	matrix4_from_matrix3(&mat, val);
	shader_setval_inline(param, &mat, sizeof(matrix4));
}

void gs_shader_set_matrix4(gs_sparam_t *param, const struct matrix4 *val)
{
	shader_setval_inline(param, val, sizeof(matrix4));
}

void gs_shader_set_vec2(gs_sparam_t *param, const struct vec2 *val)
{
	shader_setval_inline(param, val, sizeof(vec2));
}

void gs_shader_set_vec3(gs_sparam_t *param, const struct vec3 *val)
{
	shader_setval_inline(param, val, sizeof(float) * 3);
}

void gs_shader_set_vec4(gs_sparam_t *param, const struct vec4 *val)
{
	shader_setval_inline(param, val, sizeof(vec4));
}

void gs_shader_set_texture(gs_sparam_t *param, gs_texture_t *val)
{
	shader_setval_inline(param, &val, sizeof(gs_texture_t*));
}

void gs_shader_set_val(gs_sparam_t *param, const void *val, size_t size)
{
	shader_setval_inline(param, val, size);
}

void gs_shader_set_default(gs_sparam_t *param)
{
	if (param->defaultValue.size())
		shader_setval_inline(param, param->defaultValue.data(),
				param->defaultValue.size());
}

void gs_shader_set_next_sampler(gs_sparam_t *param, gs_samplerstate_t *sampler)
{
	param->nextSampler = sampler;
}
