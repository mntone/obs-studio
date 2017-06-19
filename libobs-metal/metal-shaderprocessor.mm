#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

#include <sstream>
#include <map>
#include <set>
using namespace std;

static inline void AddInputLayoutVar(shader_var *var,
		MTLVertexAttributeDescriptor *vad,
		MTLVertexBufferLayoutDescriptor *vbld)
{
	if (strcmp(var->mapping, "COLOR") == 0) {
		vad.format = MTLVertexFormatUChar4Normalized;
		vbld.stride = sizeof(vec4);

	} else if (strcmp(var->mapping, "POSITION") == 0 ||
	           strcmp(var->mapping, "NORMAL")   == 0 ||
	           strcmp(var->mapping, "TANGENT")  == 0) {
		vad.format = MTLVertexFormatFloat4;
		vbld.stride = sizeof(vec4);
		
	} else if (astrcmp_n(var->mapping, "TEXCOORD", 8) == 0) {
		/* type is always a 'float' type */
		switch (var->type[5]) {
		case 0:
			vad.format = MTLVertexFormatFloat;
			vbld.stride = sizeof(float);
			break;
		
		case '2':
			vad.format = MTLVertexFormatFloat2;
			vbld.stride = sizeof(float) * 2;
			break;
				
		case '3':
			vad.format = MTLVertexFormatFloat3;
			vbld.stride = sizeof(vec3);
			break;
				
		case '4':
			vad.format = MTLVertexFormatFloat4;
			vbld.stride = sizeof(vec4);
			break;
		}
	}
}

static inline void BuildVertexDescFromVars(shader_parser *parser, darray *vars,
		MTLVertexDescriptor *vd, size_t &index)
{
	shader_var *array = (shader_var*)vars->array;

	for (size_t i = 0; i < vars->num; i++) {
		shader_var *var = array + i;

		if (var->mapping) {
			vd.attributes[index].bufferIndex = index;
			AddInputLayoutVar(var, vd.attributes[index],
					vd.layouts[index++]);
		} else {
			shader_struct *st = shader_parser_getstruct(parser,
					var->type);
			if (st)
				BuildVertexDescFromVars(parser, &st->vars.da,
						vd, index);
		}
	}
}

void ShaderProcessor::BuildVertexDesc(MTLVertexDescriptor *vertexDesc)
{
	shader_func *func = shader_parser_getfunc(&parser, "main");
	if (!func)
		throw "Failed to find 'main' shader function";

	size_t index = 0;
	BuildVertexDescFromVars(&parser, &func->params.da, vertexDesc, index);
}

static inline void BuildParamInfoFromVars(shader_parser *parser, darray *vars,
		ShaderBufferInfo &info)
{
	shader_var *array = (shader_var*)vars->array;
	
	for (size_t i = 0; i < vars->num; i++) {
		shader_var *var = array + i;
		
		if (var->mapping) {
			if (strcmp(var->mapping, "NORMAL") == 0)
				info.normals = true;
			else if (strcmp(var->mapping, "TANGENT") == 0)
				info.tangents = true;
			else if (strcmp(var->mapping, "COLOR") == 0)
				info.colors = true;
			else if (astrcmp_n(var->mapping, "TEXCOORD", 8) == 0)
				info.texUnits++;

		} else {
			shader_struct *st = shader_parser_getstruct(parser,
					var->type);
			if (st)
				BuildParamInfoFromVars(parser, &st->vars.da,
						info);
		}
	}
}

void ShaderProcessor::BuildParamInfo(ShaderBufferInfo &info)
{
	shader_func *func = shader_parser_getfunc(&parser, "main");
	if (!func)
		throw "Failed to find 'main' shader function";
	
	BuildParamInfoFromVars(&parser, &func->params.da, info);
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

constexpr const char *UNIFORM_DATA_NAME = "UniformData";

enum class ShaderTextureCallType
{
	Sample,
	SampleBias,
	SampleGrad,
	SampleLevel,
	Load
};

struct ShaderFunctionInfo
{
	bool           useUniform;
	vector<string> useTextures;
};

struct ShaderBuilder
{
	const gs_shader_type            type;
	
	ShaderParser                    *parser;
	ostringstream                   output;

	set<string>                     constantNames;
	vector<struct shader_var*>      textureVars;
	map<string, ShaderFunctionInfo> functionInfo;
	
	string Build();
	
	ShaderBuilder(gs_shader_type type, ShaderParser *parser)
		: type(type),
		  parser(parser)
	{
	}
	
	bool isVertexShader() const {return type == GS_SHADER_VERTEX;}
	bool isPixelShader() const {return type == GS_SHADER_PIXEL;}
	
private:
	struct shader_var *GetVariable(struct cf_token *token);
	
	void AnalysisFunction(struct cf_token *&token, const char *end,
			ShaderFunctionInfo &info);
	
	void WriteType(const char *type);
	bool WriteTypeToken(struct cf_token *token);
	bool WriteMul(struct cf_token *&token);
	bool WriteConstantVariable(struct cf_token *token);
	bool WriteTextureCall(struct cf_token *&token,
			ShaderTextureCallType type);
	bool WriteTextureCode(struct cf_token *&token, struct shader_var *var);
	bool WriteIntrinsic(struct cf_token *&token);
	void WriteFunctionAdditionalParam(string funcionName);
	void WriteFunctionContent(struct cf_token *&token, const char *end);
	void WriteSamplerParamDelimitter(bool &first);
	void WriteSamplerFilter(enum gs_sample_filter filter, bool &first);
	void WriteSamplerAddress(enum gs_address_mode address,
			const char key, bool &first);
	void WriteSamplerMaxAnisotropy(int maxAnisotropy, bool &first);
	void WriteSamplerBorderColor(uint32_t borderColor, bool &first);
	
	void WriteVariable(const shader_var *var);
	void WriteSampler(shader_sampler *sampler);
	void WriteStruct(const shader_struct *str);
	void WriteFunction(const shader_func *func);
	
	void WriteInclude();
	void WriteVariables();
	void WriteSamplers();
	void WriteStructs();
	void WriteFunctions();
};

static inline const char *GetType(const string &type)
{
	if (type == "texture2d")
		return "texture2d<float>";
	else if (type == "texture3d")
		return "texture3d<float>";
	else if (type == "texture_cube")
		return "texturecube<float>";
	else if (type == "texture_rect")
		throw "texture_rect is not supported in Metal";
	else if (type == "min10float")
		throw "min10float is not supported in Metal";
	else if (type == "double")
		throw "double is not supported in Metal";
	else if (type == "min16int")
		return "short";
	else if (type == "min16uint")
		return "ushort";
	else if (type == "min12int")
		throw "min12int is not supported in Metal";
	
	return nullptr;
}

inline void ShaderBuilder::WriteType(const char *rawType)
{
	string type(rawType);
	const char *newType = GetType(string(rawType));
	output << (newType != nullptr ? newType : type);
}

inline bool ShaderBuilder::WriteTypeToken(struct cf_token *token)
{
	string type(token->str.array, token->str.len);
	const char *newType = GetType(type);
	if (newType == nullptr)
		return false;

	output << newType;
	return true;
}

inline void ShaderBuilder::WriteInclude()
{
	output << "#include <metal_stdlib>" << endl
	       << "using namespace metal;" << endl
	       << endl;
}

inline void ShaderBuilder::WriteVariable(const shader_var *var)
{
	if (var->var_type == SHADER_VAR_CONST)
		output << "constant ";
	
	WriteType(var->type);
	
	output << ' ' << var->name;
}

static inline const char *GetMapping(const char *rawMapping)
{
	if (rawMapping == nullptr)
		return nullptr;
	
	string mapping(rawMapping);
	if (mapping == "POSITION")
		return "position";
	if (mapping == "COLOR")
		return "color(0)";
	
	return nullptr;
}

inline void ShaderBuilder::WriteVariables()
{
	if (parser->params.num == 0)
		return;
	
	bool isFirst = true;
	for (struct shader_var *var = parser->params.array;
	     var != parser->params.array + parser->params.num;
	     var++) {
		if (astrcmp_n("texture", var->type, 7) != 0) {
			if (isFirst) {
				output << "struct " << UNIFORM_DATA_NAME
				       << " {" << endl;
				isFirst = false;
			}
			
			output << '\t';
			WriteVariable(var);
			
			const char* mapping = GetMapping(var->mapping);
			if (mapping != nullptr)
				output << " [[" << mapping << "]]";
			
			output << ';' << endl;
			
			constantNames.emplace(var->name);
			
		} else
			textureVars.emplace_back(var);
	}
	if (!isFirst)
		output << "};" << endl << endl;
}

inline void ShaderBuilder::WriteSamplerParamDelimitter(bool &first)
{
	if (!first)
		output << "," << endl;
	else
		first = false;
}

inline void ShaderBuilder::WriteSamplerFilter(enum gs_sample_filter filter,
		bool &first)
{
	if (filter != GS_FILTER_POINT) {
		WriteSamplerParamDelimitter(first);
		
		switch (filter) {
		case GS_FILTER_LINEAR:
		case GS_FILTER_ANISOTROPIC:
			output << "\tfilter::linear";
			break;
		case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
			output << "\tmag_filter::nearest," << endl
			       << "\tmin_filter::nearest," << endl
			       << "\tmip_filter::linear";
			break;
		case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
			output << "\tmag_filter::nearest," << endl
			       << "\tmin_filter::nearest," << endl
			       << "\tmip_filter::linear";
			break;
		case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
			output << "\tmag_filter::linear," << endl
			       << "\tmin_filter::nearest," << endl
			       << "\tmip_filter::linear";
			break;
		case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
			output << "\tmag_filter::nearest," << endl
			       << "\tmin_filter::linear," << endl
			       << "\tmip_filter::nearest";
			break;
		case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
			output << "\tmag_filter::nearest," << endl
			       << "\tmin_filter::linear," << endl
			       << "\tmip_filter::linear";
			break;
		case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
			output << "\tmag_filter::linear," << endl
			       << "\tmin_filter::linear," << endl
			       << "\tmip_filter::nearest";
			break;
		case GS_FILTER_POINT:
		default:
			throw "Unknown error";
		}
	}
}

inline void ShaderBuilder::WriteSamplerAddress(enum gs_address_mode address,
		const char key, bool &first)
{
	if (address != GS_ADDRESS_CLAMP) {
		WriteSamplerParamDelimitter(first);
		
		output << "\t" << key << "_address::";
		switch (address)
		{
		case GS_ADDRESS_WRAP:
			output << "repeat";
			break;
		case GS_ADDRESS_MIRROR:
			output << "mirrored_repeat";
			break;
		case GS_ADDRESS_BORDER:
			output << "clamp_to_border";
			break;
		case GS_ADDRESS_MIRRORONCE:
			throw "Not to support mirrored_clamp_to_edge";
		default:
		case GS_ADDRESS_CLAMP:
			throw "Unknown error";
		}
	}
}

inline void ShaderBuilder::WriteSamplerMaxAnisotropy(int maxAnisotropy,
		bool &first)
{
	if (maxAnisotropy >= 2 && maxAnisotropy <= 16) {
		WriteSamplerParamDelimitter(first);
		
		output << "\tmax_anisotropy(" << maxAnisotropy << ")";
	}
}

inline void ShaderBuilder::WriteSamplerBorderColor(uint32_t borderColor,
		bool &first)
{
	const bool isNotTransBlack = (borderColor & 0x000000FF) != 0;
	const bool isOpaqueWhite = borderColor == 0xFFFFFFFF;
	if (isNotTransBlack || isOpaqueWhite) {
		WriteSamplerParamDelimitter(first);
		
		output << "\tborder_color::";
		
		if (isOpaqueWhite)
			output << "opaque_white";
		else if (isNotTransBlack)
			output << "opaque_black";
	}
}

inline void ShaderBuilder::WriteSampler(shader_sampler *sampler)
{
	gs_sampler_info si;
	shader_sampler_convert(sampler, &si);
	
	output << "constexpr sampler " << sampler->name << "(" << endl;
	
	bool isFirst = true;
	WriteSamplerFilter(si.filter, isFirst);
	WriteSamplerAddress(si.address_u, 's', isFirst);
	WriteSamplerAddress(si.address_v, 't', isFirst);
	WriteSamplerAddress(si.address_w, 'r', isFirst);
	WriteSamplerMaxAnisotropy(si.max_anisotropy, isFirst);
	WriteSamplerBorderColor(si.border_color, isFirst);
	
	output << ");" << endl << endl;
	
}

inline void ShaderBuilder::WriteSamplers()
{
	if (isPixelShader()) {
		for (struct shader_sampler *sampler = parser->samplers.array;
		     sampler != parser->samplers.array + parser->samplers.num;
		     sampler++)
			WriteSampler(sampler);
	}
}

inline void ShaderBuilder::WriteStruct(const shader_struct *str)
{
	output << "struct " << str->name << " {" << endl;
	
	size_t attributeId = 0;
	for (struct shader_var *var = str->vars.array;
	     var != str->vars.array + str->vars.num;
	     var++) {
		output << '\t';
		WriteVariable(var);
		
		const char* mapping = GetMapping(var->mapping);
		if (isVertexShader()) {
			output << " [[attribute(" << attributeId++
			<< ")";
			if (mapping != nullptr)
				output << ", " << mapping;
			output << "]]";
		} /*else if (mapping != nullptr)
			output << " [[" << mapping << "]]";*/
			
		output << ';' << endl;
	}
	
	output << "};" << endl << endl;
}

inline void ShaderBuilder::WriteStructs()
{
	for (struct shader_struct *str = parser->structs.array;
	     str != parser->structs.array + parser->structs.num;
	     str++)
		WriteStruct(str);
}

/*
 * NOTE: HLSL -> MSL intrinsic conversions
 *   clip     -> (unsupported)
 *   ddx      -> dfdx
 *   ddy      -> dfdy
 *   frac     -> fract
 *   lerp     -> mix
 *   mul      -> (change to operator)
 *   tex*     -> texture
 *   tex*grad -> textureGrad
 *   tex*lod  -> textureLod
 *   tex*bias -> (use optional 'bias' value)
 *   tex*proj -> textureProj
 *
 *   All else can be left as-is
 */

inline bool ShaderBuilder::WriteMul(struct cf_token *&token)
{
	struct cf_parser *cfp = &parser->cfp;
	cfp->cur_token = token;
	
	if (!cf_next_token(cfp))    return false;
	if (!cf_token_is(cfp, "(")) return false;
	
	output << '(';
	WriteFunctionContent(cfp->cur_token, ",");
	output << ") * (";
	cf_next_token(cfp);
	WriteFunctionContent(cfp->cur_token, ")");
	output << "))";
	
	token = cfp->cur_token;
	return true;
}

inline bool ShaderBuilder::WriteConstantVariable(struct cf_token *token)
{
	string str(token->str.array, token->str.len);
	if (constantNames.find(str) != constantNames.end()) {
		output << "uniforms." << str;
		return true;
	}
	return false;
}

inline bool ShaderBuilder::WriteTextureCall(struct cf_token *&token,
		ShaderTextureCallType type)
{
	struct cf_parser *cfp = &parser->cfp;
	cfp->cur_token = token;
	
	/* ( */
	if (!cf_next_token(cfp))    return false;
	if (!cf_token_is(cfp, "(")) return false;
	
	/* sampler */
	if (type != ShaderTextureCallType::Load) {
		output << "sample(";
		
		if (!cf_next_token(cfp))    return false;
		if (cfp->cur_token->type != CFTOKEN_NAME) return false;
		output.write(cfp->cur_token->str.array,
				cfp->cur_token->str.len);
		
		if (!cf_next_token(cfp))    return false;
		if (!cf_token_is(cfp, ",")) return false;
		output << ", ";
	} else
		output << "read((u";
	
	/* location */
	if (!cf_next_token(cfp))    return false;
	if (type != ShaderTextureCallType::Sample &&
	    type != ShaderTextureCallType::Load) {
		WriteFunctionContent(cfp->cur_token, ",");
	
		/* bias, gradient2d, level */
		switch (type)
		{
		case ShaderTextureCallType::SampleBias:
			output << "bias(";
			if (!cf_next_token(cfp))    return false;
			WriteFunctionContent(cfp->cur_token, ")");
			output << ')';
			break;
			
		case ShaderTextureCallType::SampleGrad:
			output << "gradient2d(";
			if (!cf_next_token(cfp))    return false;
			WriteFunctionContent(cfp->cur_token, ",");
			if (!cf_next_token(cfp))    return false;
			WriteFunctionContent(cfp->cur_token, ")");
			output << ')';
			break;
			
		case ShaderTextureCallType::SampleLevel:
			output << "level(";
			if (!cf_next_token(cfp))    return false;
			WriteFunctionContent(cfp->cur_token, ")");
			output << ')';
			break;
		}
	} else
		WriteFunctionContent(cfp->cur_token, ")");
	
	/* ) */
	if (type == ShaderTextureCallType::Load)
		output << ").xy)";
	else
		output << ')';
	
	return true;
}

inline bool ShaderBuilder::WriteTextureCode(struct cf_token *&token,
		struct shader_var *var)
{
	struct cf_parser *cfp = &parser->cfp;
	bool succeeded = false;
	cfp->cur_token = token;
	
	if (!cf_next_token(cfp))    return false;
	if (!cf_token_is(cfp, ".")) return false;
	output << var->name << ".";
	
	if (!cf_next_token(cfp))    return false;
	if (cf_token_is(cfp, "Sample"))
		succeeded = WriteTextureCall(cfp->cur_token,
				ShaderTextureCallType::Sample);
	else if (cf_token_is(cfp, "SampleBias"))
		succeeded = WriteTextureCall(cfp->cur_token,
				ShaderTextureCallType::SampleBias);
	else if (cf_token_is(cfp, "SampleGrad"))
		succeeded = WriteTextureCall(cfp->cur_token,
				ShaderTextureCallType::SampleGrad);
	else if (cf_token_is(cfp, "SampleLevel"))
		succeeded = WriteTextureCall(cfp->cur_token,
				ShaderTextureCallType::SampleLevel);
	else if (cf_token_is(cfp, "Load"))
		succeeded = WriteTextureCall(cfp->cur_token,
				ShaderTextureCallType::Load);
	
	if (!succeeded)
		throw "Failed to write texture code";
	
	token = cfp->cur_token;
	return true;
}

inline struct shader_var *ShaderBuilder::GetVariable(struct cf_token *token)
{
	for (struct shader_var *var = parser->params.array;
	     var != parser->params.array + parser->params.num;
	     var++) {
		if (strref_cmp(&token->str, var->name) == 0)
			return var;
	}
	
	return nullptr;
}

inline bool ShaderBuilder::WriteIntrinsic(struct cf_token *&token)
{
	bool written = true;
	
	if (strref_cmp(&token->str, "ddx") == 0)
		output << "dfdx";
	else if (strref_cmp(&token->str, "ddy") == 0)
		output << "dfdy";
	else if (strref_cmp(&token->str, "frac") == 0)
		output << "fract";
	else if (strref_cmp(&token->str, "lerp") == 0)
		output << "mix";
	else if (strref_cmp(&token->str, "mul") == 0)
		written = WriteMul(token);
	else {
		struct shader_var *var = GetVariable(token);
		if (var != nullptr && astrcmp_n(var->type, "texture", 7) == 0)
			written = WriteTextureCode(token, var);
		else
			written = false;
	}
	
	return written;
}

inline void ShaderBuilder::AnalysisFunction(struct cf_token *&token,
		const char *end, ShaderFunctionInfo &info)
{
	while (token->type != CFTOKEN_NONE) {
		token++;
		
		if (strref_cmp(&token->str, end) == 0)
			break;
		
		if (token->type == CFTOKEN_NAME) {
			string name(token->str.array, token->str.len);
			
			/* Check function */
			auto fi = functionInfo.find(name);
			if (fi != functionInfo.end()) {
				if (fi->second.useUniform)
					info.useUniform = true;
				info.useTextures.insert(info.useTextures.end(),
						fi->second.useTextures.begin(),
						fi->second.useTextures.end());
				continue;
			}
			
			/* Check UniformData */
			if (!info.useUniform &&
			    constantNames.find(name) != constantNames.end()) {
				info.useUniform = true;
				continue;
			}
			
			/* Check texture */
			if (isPixelShader()) {
				for (auto tex = textureVars.cbegin();
				     tex != textureVars.cend();
				     tex++) {
					if (name == (*tex)->name) {
						info.useTextures.emplace_back(
								name);
						break;
					}
				}
			}
			
		} else if (token->type == CFTOKEN_OTHER) {
			if (*token->str.array == '{')
				AnalysisFunction(token, "}", info);
			else if (*token->str.array == '(')
				AnalysisFunction(token, ")", info);
		}
	}
}

inline void ShaderBuilder::WriteFunctionAdditionalParam(string funcionName)
{
	auto fi = functionInfo.find(funcionName);
	if (fi != functionInfo.end()) {
		if (fi->second.useUniform)
			output << ", uniforms";
		
		auto &textures = fi->second.useTextures;
		for (auto var = textureVars.cbegin();
		     var != textureVars.cend();
		     var++) {
			for (auto tex = textures.cbegin();
			     tex != textures.cend();
			     tex++) {
				if (*tex == (*var)->name) {
					output << ", " << *tex;
					break;
				}
			}
		}
	}
}

inline void ShaderBuilder::WriteFunctionContent(struct cf_token *&token,
		const char *end)
{
	string temp;
	if (token->type != CFTOKEN_NAME)
		output.write(token->str.array, token->str.len);
	
	else if((!WriteTypeToken(token) && !WriteIntrinsic(token) &&
	     !WriteConstantVariable(token))) {
		temp = string(token->str.array, token->str.len);
		output << temp;
	}
	
	bool dot = false;
	while (token->type != CFTOKEN_NONE) {
		token++;
		
		if (strref_cmp(&token->str, end) == 0)
			break;
		
		if (token->type == CFTOKEN_NAME) {
			if (!WriteTypeToken(token) && !WriteIntrinsic(token) &&
			    (dot || !WriteConstantVariable(token))) {
				if (dot)
					dot = false;
				
				temp = string(token->str.array, token->str.len);
				output << temp;
			}
			
		} else if (token->type == CFTOKEN_OTHER) {
			if (*token->str.array == '{')
				WriteFunctionContent(token, "}");
			else if (*token->str.array == '(') {
				WriteFunctionContent(token, ")");
				WriteFunctionAdditionalParam(temp);
			} else if (*token->str.array == '.')
				dot = true;
			
			output.write(token->str.array, token->str.len);
			
		} else
			output.write(token->str.array, token->str.len);
	}
}

inline void ShaderBuilder::WriteFunction(const shader_func *func)
{
	string funcName(func->name);
	
	const bool isMain = funcName == "main";
	if (isMain) {
		if (isVertexShader())
			output << "vertex ";
		else if (isPixelShader())
			output << "fragment ";
		else
			throw "Failed to add shader prefix";
		
		funcName = "_main";
	}
	
	ShaderFunctionInfo info;
	struct cf_token *token = func->start;
	AnalysisFunction(token, "}", info);
	unique(info.useTextures.begin(), info.useTextures.end());
	functionInfo.emplace(funcName, info);
	
	output << func->return_type << ' ' << funcName << '(';
	
	bool isFirst = true;
	for (struct shader_var *param = func->params.array;
	     param != func->params.array + func->params.num;
	     param++) {
		if (!isFirst)
			output << ", ";
		
		WriteVariable(param);
		
		if (isMain) {
			if (!isFirst)
				throw "Failed to add type";
			output << " [[stage_in]]";
				
		}
		
		if (isFirst)
			isFirst = false;
	}
	
	if (constantNames.size() != 0 && (isMain || info.useUniform))
	{
		if (!isFirst)
			output << ", ";
	
		output << "constant " << UNIFORM_DATA_NAME << " &uniforms";
		
		if (isMain)
			output << " [[buffer(30)]]";
		
		if (isFirst)
			isFirst = false;
	}
	
	if (isPixelShader())
	{
		size_t textureId = 0;
		for (auto var = textureVars.cbegin();
		     var != textureVars.cend();
		     var++) {
			if (!isMain) {
				bool additional = false;
				for (auto tex = info.useTextures.cbegin();
				     tex != info.useTextures.cend();
				     tex++) {
					if (*tex == (*var)->name) {
						additional = true;
						break;
					}
				}
				if (!additional)
					continue;
			}
			
			if (!isFirst)
				output << ", ";
			
			WriteVariable(*var);
			
			if (isMain)
				output << " [[texture(" << textureId++ << ")]]";
			
			if (isFirst)
				isFirst = false;
		}
	}
	
	output << ")" << endl;
	
	token = func->start;
	WriteFunctionContent(token, "}");
	
	output << '}' << endl << endl;
}

inline void ShaderBuilder::WriteFunctions()
{
	for (struct shader_func *func = parser->funcs.array;
	     func != parser->funcs.array + parser->funcs.num;
	     func++)
		WriteFunction(func);
}

string ShaderBuilder::Build()
{
	WriteInclude();
	WriteSamplers();
	WriteVariables();
	WriteStructs();
	WriteFunctions();
	return output.str();
}

string ShaderProcessor::BuildString(gs_shader_type type)
{
	return ShaderBuilder(type, &parser).Build();
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
