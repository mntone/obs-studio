#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

#include <string>
#include <sstream>
#include <set>
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

constexpr const char *UNIFORM_DATA_NAME = "UniformData";

struct ShaderBuilder
{
	const gs_shader_type type;
	ShaderParser         *parser;
	ostringstream        output;

	set<string>          constantNames;
	vector<struct shader_var*> textureVars;
	
	string Build();
	
	ShaderBuilder(gs_shader_type type, ShaderParser *parser)
		: type(type),
		  parser(parser)
	{
	}
	
private:
	bool WriteType(const string &type);
	void WriteType(const char *type);
	bool WriteTypeToken(struct cf_token *token);
	void WriteMapping(const char *mapping);
	bool WriteMul(struct cf_token *&token);
	bool WriteConstantVariable(struct cf_token *token);
	bool WriteIntrinsic(struct cf_token *&token);
	void WriteFunctionContent(struct cf_token *&token, const char *end);
	
	void WriteVariable(const shader_var *var);
	void WriteStruct(const shader_struct *str);
	void WriteFunction(const shader_func *func);
	
	void WriteInclude();
	void WriteVariables();
	void WriteStructs();
	void WriteFunctions();
};

inline bool ShaderBuilder::WriteType(const string &type)
{
	if (type == "texture2d")
		output << "texture2d<float>";
	else if (type == "texture3d")
		output << "texture3d<float>";
	else if (type == "texture_cube")
		output << "texturecube<float>";
	else if (type == "texture_rect")
		throw "texture_rect is not supported in Metal";
	else if (type == "min10float")
		throw "min10float is not supported in Metal";
	else if (type == "double")
		throw "double is not supported in Metal";
	else if (type == "min16int")
		output << "short";
	else if (type == "min16uint")
		output << "ushort";
	else if (type == "min12int")
		throw "min12int is not supported in Metal";
	else
		return false;
	
	return true;
}

inline void ShaderBuilder::WriteType(const char *rawType)
{
	string type(rawType);
	if (!WriteType(type))
		output << type;
}

inline bool ShaderBuilder::WriteTypeToken(struct cf_token *token)
{
	string type(token->str.array, token->str.len);
	return WriteType(type);
}

inline void ShaderBuilder::WriteMapping(const char *rawMapping)
{
	if (rawMapping == nullptr)
		return;
	
	string mapping(rawMapping);
	if (mapping == "POSITION")
		output << " [[position]]";
	else if (mapping == "COLOR")
		output << " [[color(0)]]";
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

inline void ShaderBuilder::WriteVariables()
{
	if (parser->params.num == 0)
		return;
	
	output << "struct " << UNIFORM_DATA_NAME << " {" << endl;
	for (struct shader_var *var = parser->params.array;
	     var != parser->params.array + parser->params.num;
	     var++) {
		if (astrcmp_n("texture", var->type, 7) != 0) {
			output << '\t';
			WriteVariable(var);
			WriteMapping(var->mapping);
			output << ';' << endl;
			
			constantNames.emplace(var->name);
		} else
			textureVars.emplace_back(var);
	}
	output << "};" << endl << endl;
}

inline void ShaderBuilder::WriteStruct(const shader_struct *str)
{
	output << "struct " << str->name << " {" << endl;
	for (struct shader_var *var = str->vars.array;
	     var != str->vars.array + str->vars.num;
	     var++) {
		output << '\t';
		WriteVariable(var);
		WriteMapping(var->mapping);
		output << ';' << endl;
	}
	output << "};" << endl << endl;
}

inline void ShaderBuilder::WriteStructs()
{
	for (struct shader_struct *str = parser->structs.array;
	     str != parser->structs.array + parser->structs.num;
	     str++) {
		WriteStruct(str);
	}
}

/*
 * NOTE: HLSL-> Metal Shading Language intrinsic conversions
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
		/*struct shader_var *var = sp_getparam(glsp, token);
		if (var && astrcmp_n(var->type, "texture", 7) == 0)
			written = WriteTextureCode(token, var);
		else*/
			written = false;
	}
	
	return written;
}

inline void ShaderBuilder::WriteFunctionContent(struct cf_token *&token,
		const char *end)
{
	if (token->type != CFTOKEN_NAME ||
	    (!WriteTypeToken(token) && !WriteIntrinsic(token) &&
	     !WriteConstantVariable(token)))
		output.write(token->str.array, token->str.len);
	
	while (token->type != CFTOKEN_NONE) {
		token++;
		
		if (strref_cmp(&token->str, end) == 0)
			break;
		
		if (token->type == CFTOKEN_NAME) {
			if (!WriteTypeToken(token) && !WriteIntrinsic(token) &&
			    !WriteConstantVariable(token))
				output.write(token->str.array, token->str.len);
			
		} else if (token->type == CFTOKEN_OTHER) {
			if (*token->str.array == '{')
				WriteFunctionContent(token, "}");
			else if (*token->str.array == '(')
				WriteFunctionContent(token, ")");
			
			output.write(token->str.array, token->str.len);
			
		} else
			output.write(token->str.array, token->str.len);
	}
}

inline void ShaderBuilder::WriteFunction(const shader_func *func)
{
	const bool isMain = strcmp(func->name, "main") == 0;
	const bool isPixelShader = type == GS_SHADER_PIXEL;
	if (isMain) {
		if (type == GS_SHADER_VERTEX)
			output << "vertex ";
		else if (isPixelShader)
			output << "fragment ";
		else
			throw "Failed to add shader prefix";
	}
	
	output << func->return_type << ' ' << func->name << '(';
	
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
	
	if (constantNames.size() != 0)
	{
		if (!isFirst)
			output << ", ";
	
		output << "constant " << UNIFORM_DATA_NAME << " &uniforms";
		
		if (isMain)
			output << " [[buffer(1)]]";
		
		if (isFirst)
			isFirst = false;
	}
	
	if (isPixelShader)
	{
		size_t textureId = 0;
		for (auto var = textureVars.cbegin();
		     var != textureVars.cend();
		     var++) {
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
	
	struct cf_token *token = func->start;
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
	WriteVariables();
	WriteStructs();
	WriteFunctions();
	return output.str();
}

void ShaderProcessor::BuildString(gs_shader_type type, string &outputString)
{
	outputString = ShaderBuilder(type, &parser).Build();
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
