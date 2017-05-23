#pragma once

#include <graphics/shader-parser.h>

struct ShaderParser : shader_parser {
	inline ShaderParser()  {shader_parser_init(this);}
	inline ~ShaderParser() {shader_parser_free(this);}
};

struct ShaderProcessor {
	gs_device_t *device;
	ShaderParser parser;

	void BuildInputLayout(vector<D3D11_INPUT_ELEMENT_DESC> &inputs);
	void BuildParams(vector<gs_shader_param> &params);
	void BuildSamplers(vector<unique_ptr<ShaderSampler>> &samplers);
	void BuildString(string &outputString);
	void Process(const char *shader_string, const char *file);

	inline ShaderProcessor(gs_device_t *device) : device(device)
	{
	}
};
