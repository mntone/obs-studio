#pragma once

#include <graphics/shader-parser.h>

struct ShaderParser : shader_parser {
	inline ShaderParser()  {shader_parser_init(this);}
	inline ~ShaderParser() {shader_parser_free(this);}
};

#ifdef __OBJC__
struct ShaderProcessor {
	ShaderParser parser;

	void BuildVertexDesc(__weak MTLVertexDescriptor *vertexDesc);
	void BuildParamInfo(ShaderBufferInfo &info);
	void BuildParams(std::vector<gs_shader_param> &params);
	std::string BuildString(gs_shader_type type);
	void Process(const char *shader_string, const char *file);
};
#endif

extern std::string build_shader(gs_shader_type type, ShaderParser *parser);
