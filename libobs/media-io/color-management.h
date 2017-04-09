#pragma once

#include "../util/c99defs.h"
#include "video-io.h"

#ifdef __cplusplus
extern "C" {
#endif

EXPORT int get_transfer(enum video_transfer_type t1,
		enum video_transfer_type t2, const char** technique);

EXPORT int get_colorprim(int width, int height,
		enum video_colorprim_type t1,
		enum video_colorprim_type t2, float colorprim[16]);
	
EXPORT int get_yuv_colormatrix(int width, int height, bool limited, int bit,
		enum video_colormatrix_type type, float colormatrix[16],
		float range_min[3], float range_max[3]);
	
EXPORT int get_rgb_colormatrix(bool limited, int bit, float colormatrix[16],
		float range_min[3], float range_max[3]);

EXPORT int get_colorpref(int width, int height, bool limited, int bit, bool yuv,
		enum video_transfer_type tt1, enum video_transfer_type tt2,
		enum video_colorprim_type cp1, enum video_colorprim_type cp2,
		enum video_colormatrix_type cm,
		const char** technique, float colorprim[16],
		float colormatrix[16], float range_min[3], float range_max[3]);

#ifdef __cplusplus
}
#endif
