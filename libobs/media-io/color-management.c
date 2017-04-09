#include "color-management.h"

#include <string.h>

#include "../util/base.h"

//#define COMPUTE_YUV_MATRICES
//#define COMPUTE_RGB_MATRICES
#define COMPUTE_COLORPRIM

#if defined(COMPUTE_YUV_MATRICES) || \
	defined(COMPUTE_RGB_MATRICES) || \
	defined(COMPUTE_COLORPRIM)
#define COMPUTE_MATRICES
#endif

#ifdef COMPUTE_MATRICES
#include "../graphics/matrix3.h"
#endif

static struct matrix3 unit_matrix = {
	1.0, 0.0, 0.0, 0.0,
	0.0, 1.0, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.0, 0.0, 0.0, 1.0
};

#define FULL_RANGE    (0)
#define LIMITED_RANGE (1)

#define COLOR_8BIT  (0)
#define COLOR_10BIT (1)
#define COLOR_12BIT (2)

static struct
{
	enum video_colormatrix_type const colormatrix;
	float const kb, kr;

	float matrix[6][16];

} colormatrix_info[] = {
	{ VIDEO_CM_FCC,      0.11f,   0.30f,
#ifndef COMPUTE_YUV_MATRICES
	{
		{
			1.000000,  0.000000,  1.405512, -0.705512,
			1.000000, -0.333171, -0.714667,  0.525974,
			1.000000,  1.787008,  0.000000, -0.897008,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.164384,  0.000000,  1.593750, -0.873059,
			1.164384, -0.377792, -0.810381,  0.523357,
			1.164384,  2.026339,  0.000000, -1.090202,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.401370, -0.701370,
			1.000000, -0.332189, -0.712561,  0.522886,
			1.000000,  1.781742,  0.000000, -0.891742,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.167808,  0.000000,  1.598437, -0.873059,
			1.167808, -0.378903, -0.812765,  0.523357,
			1.167808,  2.032299,  0.000000, -1.090202,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.400342, -0.700342,
			1.000000, -0.331945, -0.712038,  0.522119,
			1.000000,  1.780435,  0.000000, -0.890435,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.168664,  0.000000,  1.599609, -0.873059,
			1.168664, -0.379181, -0.813361,  0.523357,
			1.168664,  2.033789,  0.000000, -1.090202,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
	}
#endif
	},
	{ VIDEO_CM_BT601_6,  0.114f,  0.299f,
#ifndef COMPUTE_YUV_MATRICES
	{
		{
			1.000000,  0.000000,  1.407520, -0.706520,
			1.000000, -0.345491, -0.716948,  0.533303,
			1.000000,  1.778976,  0.000000, -0.892976,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.164384,  0.000000,  1.596027, -0.874202,
			1.164384, -0.391762, -0.812968,  0.531668,
			1.164384,  2.017232,  0.000000, -1.085631,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.403372, -0.702372,
			1.000000, -0.344473, -0.714835,  0.530172,
			1.000000,  1.773734,  0.000000, -0.887734,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.167808,  0.000000,  1.600721, -0.874202,
			1.167808, -0.392915, -0.815359,  0.531668,
			1.167808,  2.023165,  0.000000, -1.085631,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.402342, -0.701342,
			1.000000, -0.344220, -0.714311,  0.529395,
			1.000000,  1.772433,  0.000000, -0.886433,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.168664,  0.000000,  1.601894, -0.874202,
			1.168664, -0.393203, -0.815956,  0.531668,
			1.168664,  2.024648,  0.000000, -1.085631,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
	}
#endif
	},
	{ VIDEO_CM_BT709_6,  0.0722f, 0.2126f,
#ifndef COMPUTE_YUV_MATRICES
	{
		{
			1.000000,  0.000000,  1.581000, -0.793600,
			1.000000, -0.188062, -0.469967,  0.330305,
			1.000000,  1.862906,  0.000000, -0.935106,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.164384,  0.000000,  1.792741, -0.972945,
			1.164384, -0.213249, -0.532909,  0.301483,
			1.164384,  2.112402,  0.000000, -1.133402,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.576341, -0.788941,
			1.000000, -0.187508, -0.468582,  0.328366,
			1.000000,  1.857416,  0.000000, -0.929616,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.167808,  0.000000,  1.798014, -0.972945,
			1.167808, -0.213876, -0.534477,  0.301483,
			1.167808,  2.118615,  0.000000, -1.133402,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.575185, -0.787785,
			1.000000, -0.187370, -0.468239,  0.327884,
			1.000000,  1.856053,  0.000000, -0.928253,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.168664,  0.000000,  1.799332, -0.972945,
			1.168664, -0.214033, -0.534869,  0.301483,
			1.168664,  2.120168,  0.000000, -1.133402,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
	}
#endif
	},
	{ VIDEO_CM_BT2020NC, 0.0593f, 0.2627f,
#ifndef COMPUTE_YUV_MATRICES
	{
		{
			1.000000,  0.000000,  1.480406, -0.743106,
			1.000000, -0.165201, -0.573603,  0.370850,
			1.000000,  1.888807,  0.000000, -0.948107,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.164384,  0.000000,  1.678674, -0.915688,
			1.164384, -0.187326, -0.650424,  0.347459,
			1.164384,  2.141772,  0.000000, -1.148145,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.476043, -0.738743,
			1.000000, -0.164714, -0.571912,  0.368673,
			1.000000,  1.883241,  0.000000, -0.942541,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.167808,  0.000000,  1.683611, -0.915688,
			1.167808, -0.187877, -0.652337,  0.347458,
			1.167808,  2.148072,  0.000000, -1.148145,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.000000,  0.000000,  1.474960, -0.737660,
			1.000000, -0.164593, -0.571493,  0.368133,
			1.000000,  1.881860,  0.000000, -0.941160,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
		{
			1.168664,  0.000000,  1.684846, -0.915688,
			1.168664, -0.188015, -0.652816,  0.347459,
			1.168664,  2.149647,  0.000000, -1.148145,
			0.000000,  0.000000,  0.000000,  1.000000,
		},
	}
#endif
	},
};
#define COLORMATRIX_COUNT (sizeof(colormatrix_info)/sizeof(colormatrix_info[0]))

static struct
{
	float matrix[16];
} rgblimitedmatrix_info[3]
#ifndef COMPUTE_RGB_MATRICES
= {
	{
		1.164384,  0.000000,  0.000000, -0.073059,
		0.000000,  1.164384,  0.000000, -0.073059,
		0.000000,  0.000000,  1.164384, -0.073059,
		0.000000,  0.000000,  0.000000,  1.000000,
	},
	{
		1.167808,  0.000000,  0.000000, -0.073059,
		0.000000,  1.167808,  0.000000, -0.073059,
		0.000000,  0.000000,  1.167808, -0.073059,
		0.000000,  0.000000,  0.000000,  1.000000,
	},
	{
		1.168664,  0.000000,  0.000000, -0.073059,
		0.000000,  1.168664,  0.000000, -0.073059,
		0.000000,  0.000000,  1.168664, -0.073059,
		0.000000,  0.000000,  0.000000,  1.000000,
	},
}
#endif
;
#define RGBLIMITEDMATRIX_COUNT (sizeof(rgblimitedmatrix_info)/sizeof(rgblimitedmatrix_info[0]))

enum illuminant_type {
	ILLUMINANT_C,
	ILLUMINANT_D50,
	ILLUMINANT_D65,
	ILLUMINANT_D93,
	ILLUMINANT_OTHER,
};

/*static struct
{
	enum illuminant_type const illuminant;
	float const x, y;
} illuminant_info[] = {
	{ILLUMINANT_C,   0.31006f, 0.31616f},
	{ILLUMINANT_D50, 0.3357f,  0.3586f},
	{ILLUMINANT_D60, 0.3217f,  0.3377f},
	{ILLUMINANT_D65, 0.3128f,  0.3290f},
	{ILLUMINANT_D75, 0.2991f,  0.3149f},
	{ILLUMINANT_D93, 0.2831f,  0.2970f},
};*/

static struct _colorprim_info_type
{
	enum video_colorprim_type const colorprim;
	float const rx, ry, gx, gy, bx, by, wx, wy;
	enum illuminant_type illuminant;

	float rgb2xyz[16];
	float xyz2rgb[16];
} colorprim_info[] = {
	{VIDEO_CP_BT709_5,        0.640,  0.330,  0.300,  0.600,  0.150,  0.060,  0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_BT470_6,        0.67,   0.33,   0.21,   0.71,   0.14,   0.08,   0.310,  0.316,  ILLUMINANT_C},
	{VIDEO_CP_PAL,            0.64,   0.33,   0.29,   0.60,   0.15,   0.06,   0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_NTSC,           0.630,  0.340,  0.310,  0.595,  0.155,  0.070,  0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_FILM,           0.681,  0.319,  0.243,  0.692,  0.145,  0.049,  0.310,  0.316,  ILLUMINANT_C},
	{VIDEO_CP_BT2020_2,       0.708,  0.292,  0.265,  0.690,  0.150,  0.060,  0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_SMPTE_RP431_2,  0.680,  0.320,  0.265,  0.690,  0.150,  0.060,  0.314,  0.351,  ILLUMINANT_OTHER},
	{VIDEO_CP_SMPTE_RP432_1,  0.680,  0.320,  0.265,  0.690,  0.150,  0.060,  0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_EBU_TECH3213_E, 0.630,  0.340,  0.295,  0.605,  0.155,  0.077,  0.3127, 0.3290, ILLUMINANT_D65},

	{VIDEO_CP_NTSC_J,         0.630,  0.340,  0.310,  0.595,  0.155,  0.070,  0.2831, 0.2970, ILLUMINANT_D93},
	{VIDEO_CP_ADOBE_RGB,      0.6400, 0.3300, 0.2100, 0.7100, 0.1500, 0.0600, 0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_DCI_P3_D65,     0.680,  0.320,  0.265,  0.690,  0.150,  0.060,  0.3127, 0.3290, ILLUMINANT_D65},
	{VIDEO_CP_DCI_P3,         0.680,  0.320,  0.265,  0.690,  0.150,  0.060,  0.314,  0.351,  ILLUMINANT_OTHER},
};
#define COLORPRIM_COUNT (sizeof(colorprim_info)/sizeof(colorprim_info[0]))

static struct _const_parameter
{
	double const max_value;
	int const range_min[2];   /* nominal range min */
	int const range_max[2];   /* nominal range max */
	int const range_data_min; /* video data range min */
	int const range_data_max; /* video data range max */
	int const black_levels[2];

	float float_range_data_min_yuv[3];
	float float_range_data_max_yuv[3];
	float float_range_data_min_rgb[3];
	float float_range_data_max_rgb[3];
} parameters[] = {
	{  255, {  0,   0}, { 255,  255},  0,  255, {  0,  128} },
	{  255, { 16,  16}, { 235,  240},  1,  254, { 16,  128} },
	{ 1023, {  0,   0}, {1023, 1023},  0, 1024, {  0,  512} },
	{ 1023, { 64,  64}, { 940,  960},  4, 1019, { 64,  512} },
	{ 4095, {  0,   0}, {4095, 4095},  0, 4096, {  0, 2048} },
	{ 4095, {256, 256}, {3760, 3840}, 16, 4079, {256, 2048} },
};
#define PARAMETERS_COUNT (sizeof(parameters)/sizeof(parameters[0]))

#ifdef COMPUTE_MATRICES
static void log_matrix(float const matrix[16])
{
	blog(LOG_DEBUG, "\n% f, % f, % f, % f" \
			"\n% f, % f, % f, % f" \
			"\n% f, % f, % f, % f" \
			"\n% f, % f, % f, % f",
			matrix[ 0], matrix[ 1], matrix[ 2], matrix[ 3],
			matrix[ 4], matrix[ 5], matrix[ 6], matrix[ 7],
			matrix[ 8], matrix[ 9], matrix[10], matrix[11],
			matrix[12], matrix[13], matrix[14], matrix[15]);
}

static void initialize_parameters()
{
	for (size_t i = 0; i < PARAMETERS_COUNT; i++) {
		double max = parameters[i].max_value;
		float yuvmin[3] = {
			parameters[i].range_min[0] / max,
			parameters[i].range_min[1] / max,
			parameters[i].range_min[1] / max,
		};
		float yuvmax[3] = {
			parameters[i].range_max[0] / max,
			parameters[i].range_max[1] / max,
			parameters[i].range_max[1] / max,
		};
		float rgbmin[3] = {
			parameters[i].range_min[0] / max,
			parameters[i].range_min[0] / max,
			parameters[i].range_min[0] / max,
		};
		float rgbmax[3] = {
			parameters[i].range_max[0] / max,
			parameters[i].range_max[0] / max,
			parameters[i].range_max[0] / max,
		};

		memcpy(parameters[i].float_range_data_min_yuv,
				yuvmin, sizeof(float) * 3);
		memcpy(parameters[i].float_range_data_max_yuv,
				yuvmax, sizeof(float) * 3);
		memcpy(parameters[i].float_range_data_min_rgb,
				rgbmin, sizeof(float) * 3);
		memcpy(parameters[i].float_range_data_max_rgb,
				rgbmax, sizeof(float) * 3);
	}
}

static void initialize_colorprim(struct _colorprim_info_type *info)
{
	struct vec3 vec;
	struct matrix3 colorprim, mat;

	vec3_set(&colorprim.x, info->rx, info->gx, info->bx);
	vec3_set(&colorprim.y, info->ry, info->gy, info->by);
	vec3_set(&colorprim.z, 1.0, 1.0, 1.0);
	vec3_sub(&colorprim.z, &colorprim.z, &colorprim.x);
	vec3_sub(&colorprim.z, &colorprim.z, &colorprim.y);
	vec3_set(&vec, info->wx / info->wy, 1.0f,
			(1.0 - info->wx - info->wy) / info->wy);

	matrix3_inv(&mat, &colorprim);
	vec3_rotate(&vec, &vec, &mat);

	vec3_set(&mat.x, vec.x, 0.0, 0.0);
	vec3_set(&mat.y, 0.0, vec.y, 0.0);
	vec3_set(&mat.z, 0.0, 0.0, vec.z);
	matrix3_mul(&mat, &colorprim, &mat);

	memcpy(info->rgb2xyz, &mat, 12 * sizeof(float));
	info->rgb2xyz[12] = info->rgb2xyz[13] = info->rgb2xyz[14] = 0.0;
	info->rgb2xyz[15] = 1.0;
	log_matrix(info->rgb2xyz);

	matrix3_inv(&mat, &mat);

	memcpy(info->xyz2rgb, &mat, 12 * sizeof(float));
	info->xyz2rgb[12] = info->xyz2rgb[13] = info->xyz2rgb[14] = 0.0;
	info->xyz2rgb[15] = 1.0;
	log_matrix(info->xyz2rgb);
}

static void initialize_colormatrix(float const Kb, float const Kr,
		struct _const_parameter const parameter, float matrix[16])
{
	struct matrix3 color_matrix;

	double max = parameter.max_value;
	int yvals  = parameter.range_max[0] - parameter.range_min[0];
	int uvvals = (parameter.range_max[1] - parameter.range_min[1]) / 2;

	vec3_set(&color_matrix.x, max/yvals,
			0.,
			max/uvvals * (1. - Kr));
	vec3_set(&color_matrix.y, max/yvals,
			max/uvvals * (Kb - 1.) * Kb / (1. - Kb - Kr),
			max/uvvals * (Kr - 1.) * Kr / (1. - Kb - Kr));
	vec3_set(&color_matrix.z, max/yvals,
			max/uvvals * (1. - Kb),
			0.);

	struct vec3 offsets, multiplied;
	vec3_set(&offsets,
			-parameter.black_levels[0]/max,
			-parameter.black_levels[1]/max,
			-parameter.black_levels[1]/max);
	vec3_rotate(&multiplied, &offsets, &color_matrix);

	matrix[ 0] = color_matrix.x.x;
	matrix[ 1] = color_matrix.x.y;
	matrix[ 2] = color_matrix.x.z;
	matrix[ 3] = multiplied.x;

	matrix[ 4] = color_matrix.y.x;
	matrix[ 5] = color_matrix.y.y;
	matrix[ 6] = color_matrix.y.z;
	matrix[ 7] = multiplied.y;

	matrix[ 8] = color_matrix.z.x;
	matrix[ 9] = color_matrix.z.y;
	matrix[10] = color_matrix.z.z;
	matrix[11] = multiplied.z;

	matrix[12] = matrix[13] = matrix[14] = 0.;
	matrix[15] = 1.;

	log_matrix(matrix);
}

static void initialize_rgblimitedmatrix(struct _const_parameter const parameter,
		float matrix[16])
{
	struct matrix3 color_matrix;

	double max = parameter.max_value;
	int dvals = parameter.range_max[0] - parameter.range_min[0];

	vec3_set(&color_matrix.x, max/dvals,        0.,        0.);
	vec3_set(&color_matrix.y,        0., max/dvals,        0.);
	vec3_set(&color_matrix.z,        0.,        0., max/dvals);

	struct vec3 offsets, multiplied;
	vec3_set(&offsets,
			-parameter.range_min[0]/max,
			-parameter.range_min[0]/max,
			-parameter.range_min[0]/max);
	vec3_rotate(&multiplied, &offsets, &color_matrix);

	matrix[ 0] = color_matrix.x.x;
	matrix[ 1] = color_matrix.x.y;
	matrix[ 2] = color_matrix.x.z;
	matrix[ 3] = multiplied.x;

	matrix[ 4] = color_matrix.y.x;
	matrix[ 5] = color_matrix.y.y;
	matrix[ 6] = color_matrix.y.z;
	matrix[ 7] = multiplied.y;

	matrix[ 8] = color_matrix.z.x;
	matrix[ 9] = color_matrix.z.y;
	matrix[10] = color_matrix.z.z;
	matrix[11] = multiplied.z;

	matrix[12] = matrix[13] = matrix[14] = 0.;
	matrix[15] = 1.;

	log_matrix(matrix);
}

static void initialize_matrices()
{
	initialize_parameters();
#ifdef COMPUTE_COLORPRIM
	for (size_t i = 0; i < COLORPRIM_COUNT; i++) {
		initialize_colorprim(&colorprim_info[i]);
	}
#endif
#ifdef COMPUTE_YUV_MATRICES
	for (size_t i = 0; i < COLORMATRIX_COUNT; i++) {
		for (int j = 0; j < 3; j++) {
			float const kb = colormatrix_info[i].kb;
			float const kr = colormatrix_info[i].kr;

			initialize_colormatrix(kb, kr,
					parameters[j*2],
					colormatrix_info[j*2].matrix[j]);
			initialize_colormatrix(kr, kr,
					parameters[j*2 + 1],
					colormatrix_info[j*2 + 1].matrix[j]);
		}
	}
#endif
#ifdef COMPUTE_RGB_MATRICES
	for (size_t i = 0; i < RGBLIMITEDMATRIX_COUNT; i++) {
		initialize_rgblimitedmatrix(
				parameters[2*i + 1],
				rgblimitedmatrix_info[i].matrix);
	}
#endif
}

static bool matrices_initialized = false;
#endif

static inline int get_colorbit_index(int bit)
{
	switch (bit) {
	case 10: return COLOR_10BIT;
	case 12: return COLOR_12BIT;

	case 8:
	default:
		return COLOR_8BIT;
	}
}

static inline void get_target_parameter(bool limited, int bit,
		struct _const_parameter const **parameter)
{
	int const f1 = limited ? LIMITED_RANGE : FULL_RANGE;
	int const f2 = get_colorbit_index(bit);

	*parameter = &parameters[f2*2 + f1];
}

static inline enum video_transfer_type get_default_transfer()
{
	return VIDEO_TRANS_BT709_5;
}
static inline enum video_transfer_type get_unified_transfer(
		enum video_transfer_type type)
{
	switch (type) {
	case VIDEO_TRANS_NTSC:
	case VIDEO_TRANS_PAL:
	case VIDEO_TRANS_SMPTE_240M:
	case VIDEO_TRANS_LINEAR:
	case VIDEO_TRANS_LOG:
	case VIDEO_TRANS_XVYCC:
	case VIDEO_TRANS_BT1361_0:
	case VIDEO_TRANS_SRGB:
	case VIDEO_TRANS_ADOBERGB:
		return type;

	case VIDEO_TRANS_DEFAULT:
	case VIDEO_TRANS_BT709_5:
	case VIDEO_TRANS_UNSPECIFIED:
	case VIDEO_TRANS_BT601_6:
	case VIDEO_TRANS_BT2020_2_10:
	case VIDEO_TRANS_BT2020_2_12:
	default:
		return VIDEO_TRANS_BT709_5;
	}
}

static inline enum video_colorprim_type get_default_colorprim(
		int width, int height)
{
	if (width <= 720 && height <= 486)
		return VIDEO_CP_NTSC;
	else if (width <= 720 && height <= 576)
		return VIDEO_CP_PAL;
	else if (width >= 3840 && height >= 2160)
		return VIDEO_CP_BT2020_2;
	else
		return VIDEO_CP_BT709_5;
}
static inline enum video_colorprim_type get_unified_colorprim(
		enum video_colorprim_type type)
{
	switch (type) {
	case VIDEO_CP_NTSC:
	case VIDEO_CP_SMPTE240M:
		return VIDEO_CP_NTSC;

	case VIDEO_CP_BT470_6:
	case VIDEO_CP_PAL:
	case VIDEO_CP_FILM:
	case VIDEO_CP_BT2020_2:
	case VIDEO_CP_SMPTE_428_1:
	case VIDEO_CP_SMPTE_RP431_2:
	case VIDEO_CP_SMPTE_RP432_1:
	case VIDEO_CP_EBU_TECH3213_E:
	case VIDEO_CP_NTSC_J:
	case VIDEO_CP_ADOBE_RGB:
	case VIDEO_CP_DCI_P3_D65:
	case VIDEO_CP_DCI_P3:
		return type;

	case VIDEO_CP_DEFAULT:
	case VIDEO_CP_BT709_5:
	case VIDEO_CP_UNSPECIFIED:
	default:
		return VIDEO_CP_BT709_5;
	}
}

static inline int get_target_colorprim(enum video_colorprim_type type,
		struct _colorprim_info_type **info)
{
	for (size_t i = 0; i < COLORPRIM_COUNT; i++) {
		if (colorprim_info[i].colorprim == type) {
			*info = &colorprim_info[i];
			return 0;
		}
	}
	return -1;
}

static inline enum video_colormatrix_type get_default_colormatrix(int height)
{
	if (height < 720)
		return VIDEO_CM_BT601_6;
	else if (height >= 2160)
		return VIDEO_CM_BT2020NC;
	else
		return VIDEO_CM_BT709_6;
}
static inline enum video_colormatrix_type get_unified_colormatrix(
		enum video_colormatrix_type type)
{
	switch (type) {
	case VIDEO_CM_PAL:
	case VIDEO_CM_NTSC:
		return VIDEO_CM_NTSC;

	case VIDEO_CM_FCC:
	case VIDEO_CM_SMPTE_240M:
		return type;

	case VIDEO_CM_DEFAULT:
	case VIDEO_CM_GBR:
	case VIDEO_CM_BT709_6:
	case VIDEO_CM_UNSPECIFIED:
	case VIDEO_CM_YCGCO:
	case VIDEO_CM_YDZDX:
	default:
		return VIDEO_CM_BT709_6;
	}
}

static inline int get_target_colormatrix(enum video_colormatrix_type type,
		bool limited, int bit, float colormatrix[16])
{
	int const f1 = limited ? LIMITED_RANGE : FULL_RANGE;
	int const f2 = get_colorbit_index(bit);

	for (size_t i = 0; i < COLORMATRIX_COUNT; i++) {
		if (colormatrix_info[i].colormatrix == type) {
			memcpy(colormatrix, &colormatrix_info[i].matrix[f2*2 + f1],
					16 * sizeof(float));
			return 0;
		}
	}
	return -1;
}


int get_transfer(enum video_transfer_type t1,
		enum video_transfer_type t2, const char** technique)
{
	if (t2 != VIDEO_TRANS_BT709_5)
		return -1;

	if (t1 == VIDEO_TRANS_DEFAULT)
		t1 = get_default_transfer();

	switch (t1) {
	case VIDEO_TRANS_NTSC:          *technique = "DrawNtsc";      break;
	case VIDEO_TRANS_PAL:           *technique = "DrawPal";       break;
	case VIDEO_TRANS_SMPTE_240M:    *technique = "DrawSmpte240m"; break;
	case VIDEO_TRANS_LINEAR:        *technique = "DrawLinear";    break;
	case VIDEO_TRANS_LOG:           *technique = "DrawLog";       break;
	case VIDEO_TRANS_LOG_SQRT:      *technique = "DrawLogSqrt";   break;
	case VIDEO_TRANS_XVYCC:         *technique = "DrawXvycc";     break;
	case VIDEO_TRANS_BT1361_0:      *technique = "DrawBt1361";    break;
	case VIDEO_TRANS_SRGB:          *technique = "DrawSrgb";      break;
	case VIDEO_TRANS_ADOBERGB:      *technique = "DrawAdobergb";  break;

	case VIDEO_TRANS_PQ:
	case VIDEO_TRANS_SMPTE_ST428_1:
	case VIDEO_TRANS_HLG:
		return -1;

	case VIDEO_TRANS_DEFAULT:
	case VIDEO_TRANS_BT709_5:
	case VIDEO_TRANS_UNSPECIFIED:
	case VIDEO_TRANS_BT601_6:
	case VIDEO_TRANS_BT2020_2_10:
	case VIDEO_TRANS_BT2020_2_12:
	default:
		*technique = "DrawBt709";
		break;
	}
	return 0;
}

int get_colorprim(int width, int height,
		enum video_colorprim_type t1,
		enum video_colorprim_type t2, float colorprim[16])
{
#ifdef COMPUTE_MATRICES
	if (!matrices_initialized) {
		initialize_matrices();
		matrices_initialized = true;
	}
#endif

	struct matrix3 m1, m2;
	struct _colorprim_info_type *i1, *i2;

	if (t1 == VIDEO_CS_DEFAULT)
		t1 = get_default_colorprim(width, height);
	else
		t1 = get_unified_colorprim(t1);
	
	t2 = get_unified_colorprim(t2);

	if (t1 == t2) {
		memcpy(colorprim, &unit_matrix, sizeof(float) * 16);
		return 0;
	}
	
	if (get_target_colorprim(t1, &i1) != 0)
		return -1;
	if (get_target_colorprim(t2, &i2) != 0)
		return -1;

	memcpy(&m1, i1->rgb2xyz, sizeof(float) * 16);
	memcpy(&m2, i2->xyz2rgb, sizeof(float) * 16);
	matrix3_transpose(&m1, &m1);
	matrix3_mul(&m2, &m2, &m1);

	memcpy(colorprim, &m2, sizeof(float) * 12);
	colorprim[12] = colorprim[13] = colorprim[14] = 0.0;
	colorprim[15] = 1.0;

	return 0;
}

int get_yuv_colormatrix(int width, int height, bool limited, int bit,
		enum video_colormatrix_type type, float colormatrix[16],
		float range_min[3], float range_max[3])
{
#ifdef COMPUTE_MATRICES
	if (!matrices_initialized) {
		initialize_matrices();
		matrices_initialized = true;
	}
#endif
	int ret;
	struct _const_parameter *p;

	if (type == VIDEO_CM_DEFAULT)
		type = get_default_colormatrix(height);
	else
		type = get_unified_colormatrix(type);

	get_target_parameter(limited, bit, &p);

	ret = get_target_colormatrix(type, limited, bit, colormatrix);
	memcpy(range_min, p->float_range_data_min_yuv,
			sizeof(float) * 3);
	memcpy(range_max, p->float_range_data_max_yuv,
			sizeof(float) * 3);
	return ret;
}

int get_rgb_colormatrix(bool limited, int bit, float colormatrix[16],
		float range_min[3], float range_max[3])
{
#ifdef COMPUTE_MATRICES
	if (!matrices_initialized) {
		initialize_matrices();
		matrices_initialized = true;
	}
#endif
	struct _const_parameter *p;
	int const f = get_colorbit_index(bit);

	get_target_parameter(limited, bit, &p);
	
	if (limited)
		memcpy(colormatrix, &rgblimitedmatrix_info[f].matrix,
				sizeof(float) * 16);
	else
		memcpy(colormatrix, &unit_matrix, sizeof(float) * 16);

	memcpy(range_min, p->float_range_data_min_rgb,
			sizeof(float) * 3);
	memcpy(range_max, p->float_range_data_max_rgb,
			sizeof(float) * 3);
	return 0;
}

int get_colorpref(int width, int height, bool limited, int bit, bool yuv,
		enum video_transfer_type tt1, enum video_transfer_type tt2,
		enum video_colorprim_type cp1, enum video_colorprim_type cp2,
		enum video_colormatrix_type cm,
		const char** technique, float colorprim[16],
		float colormatrix[16], float range_min[3], float range_max[3])
{
	int ret = 0;
	bool matrix_only = false;

	tt1 = get_unified_transfer(tt1);
	tt2 = get_unified_transfer(tt2);

	if (cp1 == VIDEO_CP_DEFAULT)
		cp1 = get_default_colorprim(width, height);
	else
		cp1 = get_unified_colorprim(cp1);

	cp2 = get_unified_colorprim(cp2);

	if (cm == VIDEO_CM_DEFAULT)
		cm = get_default_colormatrix(height);
	else
		cm = get_unified_colormatrix(cm);

	if (tt1 == tt2 && cp1 == cp2) {
		if (!yuv && !limited) {
			*technique = "Draw";
			return 0;
		} else {
			*technique = "DrawMatrix";
			matrix_only = true;
		}
	}

	if (yuv) {
		ret = get_yuv_colormatrix(width, height, limited, bit,
				cm, colormatrix, range_min, range_max);
	} else {
		ret = get_rgb_colormatrix(limited, bit, colormatrix,
				range_min, range_max);
	}
	if (ret > 0 || matrix_only)
		return ret;

	ret = get_transfer(tt1, tt2, technique);
	if (ret > 0)
		return ret;


	return get_colorprim(width, height, cp1, cp2, colorprim);
}
