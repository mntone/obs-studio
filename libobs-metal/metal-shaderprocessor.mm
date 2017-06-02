#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

#include <string>
#include <sstream>
using namespace std;

static void AddInputLayoutVar(shader_var *var,
		MTLVertexAttributeDescriptor *vad, size_t &currentOffset)
{
	vad.bufferIndex = 0;
	vad.offset = currentOffset;
	
	if (strcmp(var->mapping, "COLOR") == 0) {
		vad.format = MTLVertexFormatUChar4Normalized;
		currentOffset += 4;

	} else if (strcmp(var->mapping, "POSITION") == 0 ||
	           strcmp(var->mapping, "NORMAL")   == 0 ||
	           strcmp(var->mapping, "TANGENT")  == 0) {
		vad.format = MTLVertexFormatFloat4;
		currentOffset += 16;

	} else if (astrcmp_n(var->mapping, "TEXCOORD", 8) == 0) {
		/* type is always a 'float' type */
		switch (var->type[5]) {
		case 0:
			vad.format = MTLVertexFormatFloat;
			currentOffset += 4;
			break;
		
		case '2':
			vad.format = MTLVertexFormatFloat2;
			currentOffset += 8;
			break;
				
		case '3':
		case '4':
			vad.format = MTLVertexFormatFloat4;
			currentOffset += 16;
			break;
		}
	}
}

static void BuildInputLayoutFromVars(shader_parser *parser, darray *vars,
		MTLVertexDescriptor *vd, size_t &index, size_t &offset)
{
	shader_var *array = (shader_var*)vars->array;

	for (size_t i = 0; i < vars->num; i++) {
		shader_var *var = array + i;

		if (var->mapping) {
			AddInputLayoutVar(var, vd.attributes[index++], offset);
		} else {
			shader_struct *st = shader_parser_getstruct(parser,
					var->type);
			if (st)
				BuildInputLayoutFromVars(parser, &st->vars.da,
						vd, index, offset);
		}
	}
}

void ShaderProcessor::BuildInputLayout(MTLVertexDescriptor *vertexDesc)
{
	shader_func *func = shader_parser_getfunc(&parser, "main");
	if (!func)
		throw "Failed to find 'main' shader function";

	size_t index = 0, offset = 0;
	BuildInputLayoutFromVars(&parser, &func->params.da, vertexDesc,
			index, offset);
	
	vertexDesc.layouts[0].stride = offset;
}

gs_shader_param::gs_shader_param(shader_var &var, uint32_t &texCounter)
	: name       (var.name),
	  type       (get_shader_param_type(var.type)),
	  textureID  (texCounter),
	  arrayCount (var.array_count),
	  changed    (false)
{
	defaultValue.resize(var.default_val.num);
	memcpy(defaultValue.data(), var.default_val.array, var.default_val.num);

	if (type == GS_SHADER_PARAM_TEXTURE)
		texCounter++;
	else
		textureID = 0;
}

static inline void AddParam(shader_var &var, vector<gs_shader_param> &params,
		uint32_t &texCounter)
{
	if (var.var_type != SHADER_VAR_UNIFORM ||
	    strcmp(var.type, "sampler") == 0)
		return;

	params.push_back(gs_shader_param(var, texCounter));
}

void ShaderProcessor::BuildParams(vector<gs_shader_param> &params)
{
	uint32_t texCounter = 0;

	for (size_t i = 0; i < parser.params.num; i++)
		AddParam(parser.params.array[i], params, texCounter);
}

static inline void AddSampler(gs_device_t *device, shader_sampler &sampler,
		vector<unique_ptr<ShaderSampler>> &samplers)
{
	gs_sampler_info si;
	shader_sampler_convert(&sampler, &si);
	samplers.emplace_back(new ShaderSampler(sampler.name, device, &si));
}

void ShaderProcessor::BuildSamplers(vector<unique_ptr<ShaderSampler>> &samplers)
{
	for (size_t i = 0; i < parser.samplers.num; i++)
		AddSampler(device, parser.samplers.array[i], samplers);
}

class ShaderBuilder
{
	ShaderParser *parser;
	stringstream output;
	
	bool hasConstant = false;
	
	void Build();
	
private:
	void WriteType(const char *type);
	void WriteParam(shader_var *param);
	
	void WriteInclude();
	void WriteParams();
};

inline void ShaderBuilder::WriteType(const char *tempType)
{
	string type(tempType);
	if (type == "texture2d")
		output << "texture2d<float>";
	else if (type == "texture3d")
		output << "texture3d<float>";
	else if (type == "texture_cube")
		output << "texturecube<float>";
	else if (type == "texture_rect")
		throw "texture_rect is not supported in Metal";
	else
		output << type;
}

inline void ShaderBuilder::WriteInclude()
{
	
}

inline void ShaderBuilder::WriteParam(shader_var *param)
{
	output << '\t';
	
	if (param->var_type == SHADER_VAR_CONST)
		output << "constant ";
	
	WriteType(param->type);
	
	output << ' ' << param->name << ';' << endl;
}

inline void ShaderBuilder::WriteParams()
{
	if (parser->params.num == 0)
		return;
	
	output << "struct UniformData {" << endl;
	for (struct shader_var *param = parser->params.array;
	     param != parser->params.array + parser->params.num;
	     param++) {
		if (astrcmp_n("texture", param->type, 7) != 0)
			WriteParam(param);
	}
	output << "};" << endl;
	
	hasConstant = true;
}

void ShaderBuilder::Build()
{
	WriteInclude();
	WriteParams();
}

void ShaderProcessor::BuildString(string &outputString)
{
	stringstream output;
	cf_token *token = cf_preprocessor_get_tokens(&parser.cfp.pp);
	while (token->type != CFTOKEN_NONE) {
		/* cheaply just replace specific tokens */
		if (strref_cmp(&token->str, "POSITION") == 0)
			output << "position";
		else if (strref_cmp(&token->str, "TARGET") == 0)
			output << "color(0)";
		else if (strref_cmp(&token->str, "texture2d") == 0)
			output << "texture2d";
		else if (strref_cmp(&token->str, "texture3d") == 0)
			output << "texture3d";
		else if (strref_cmp(&token->str, "texture_cube") == 0)
			output << "texturecube";
		else if (strref_cmp(&token->str, "texture_rect") == 0)
			throw "texture_rect is not supported in Metal";
		else if (strref_cmp(&token->str, "sampler_state") == 0)
			output << "SamplerState";
		else
			output.write(token->str.array, token->str.len);

		token++;
	}

	outputString = move(output.str());
}

void ShaderProcessor::Process(const char *shader_string, const char *file)
{
	bool success = shader_parse(&parser, shader_string, file);
	char *str = shader_parser_geterrors(&parser);
	if (str) {
		blog(LOG_WARNING, "Shader parser errors/warnings:\n%s\n", str);
		bfree(str);
	}

	if (!success)
		throw "Failed to parse shader";
}
