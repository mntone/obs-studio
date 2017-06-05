#pragma once

#include <graphics/shader-parser.h>

struct ShaderParser : shader_parser {
	inline ShaderParser()  {shader_parser_init(this);}
	inline ~ShaderParser() {shader_parser_free(this);}
};

struct ShaderProcessor {
	gs_device_t  *device;
	ShaderParser parser;

	void BuildInputLayout(MTLVertexDescriptor *vertexDesc);
	void BuildParams(vector<gs_shader_param> &params);
	void BuildString(gs_shader_type type, string &outputString);
	void Process(const char *shader_string, const char *file);

	inline ShaderProcessor(gs_device_t *device) : device(device)
	{
	}
};
