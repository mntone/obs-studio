/******************************************************************************
    Copyright (C) 2013 by Hugh Bailey <obs.jim@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
******************************************************************************/

#pragma once

#include "media-io-defs.h"

#ifdef __cplusplus
extern "C" {
#endif

struct video_frame;

/* Base video output component.  Use this to create a video output track. */

struct video_output;
typedef struct video_output video_t;

enum video_format {
	VIDEO_FORMAT_NONE,

	/* planar 420 format */
	VIDEO_FORMAT_I420, /* three-plane */
	VIDEO_FORMAT_NV12, /* two-plane, luma and packed chroma */

	/* packed 422 formats */
	VIDEO_FORMAT_YVYU,
	VIDEO_FORMAT_YUY2, /* YUYV */
	VIDEO_FORMAT_UYVY,

	/* packed uncompressed formats */
	VIDEO_FORMAT_RGBA,
	VIDEO_FORMAT_BGRA,
	VIDEO_FORMAT_BGRX,
	VIDEO_FORMAT_Y800, /* grayscale */

	/* packed uncompressed 10-bit formats */
	VIDEO_FORMAT_R210, /* A2BGR10 */
	VIDEO_FORMAT_R10B, /* RGB10X2 */
	VIDEO_FORMAT_R10L, /* RGB10X2 (LE) */

	/* planar 4:4:4 */
	VIDEO_FORMAT_I444,
};

enum video_colorspace {
	VIDEO_CS_DEFAULT,
	VIDEO_CS_601,
	VIDEO_CS_709,
};

/*
 * Default: BT.709
 */
enum video_transfer_type {
	VIDEO_TRANS_DEFAULT       = -1,
	VIDEO_TRANS_BT709_5       =  1,  /* BT.709-5 */
	VIDEO_TRANS_UNSPECIFIED   =  2,
	VIDEO_TRANS_NTSC          =  4,  /* BT.470-6 System M  */
	VIDEO_TRANS_PAL           =  5,  /* BT.470-6 System B, G */
	VIDEO_TRANS_BT601_6       =  6,  /* same as 1 */
	VIDEO_TRANS_SMPTE_240M    =  7,  /* SMPTE 240M */
	VIDEO_TRANS_LINEAR        =  8,
	VIDEO_TRANS_LOG           =  9,
	VIDEO_TRANS_LOG_SQRT      = 10,
	VIDEO_TRANS_XVYCC         = 11,  /* IEC 61966-2-4 */
	VIDEO_TRANS_BT1361_0      = 12,  /* BT.1361-0 */
	VIDEO_TRANS_SRGB          = 13,  /* IEC 61966-2-1 */
	VIDEO_TRANS_BT2020_2_10   = 14,  /* BT.2020 10-bit, same as 1 */
	VIDEO_TRANS_BT2020_2_12   = 15,  /* BT.2020 12-bit, same as 1 */

	/* HDR; no support */
	VIDEO_TRANS_PQ            = 16,  /* SMPTE ST 2084, BT.2100 */
	VIDEO_TRANS_SMPTE_ST428_1 = 17,  /* SMPTE ST 428-1 */
	VIDEO_TRANS_HLG           = 18,  /* ARIB STD-B67 */
	
	/* internal use only */
	VIDEO_TRANS_ADOBERGB      = 1000,
};

/*
 * Default:
 * <= 720 x <= 486: NTSC
 * <= 720 x <= 576: PAL
 * >=3840 x >=2160: BT.2020
 * other          : BT.709
 */
enum video_colorprim_type {
	VIDEO_CP_DEFAULT        = -1,
	VIDEO_CP_BT709_5        =  1,  /* BT.709-5, sRGB */
	VIDEO_CP_UNSPECIFIED    =  2,
	VIDEO_CP_BT470_6        =  4,  /* BT.470-6 System M (NTSC 1953) */
	VIDEO_CP_PAL            =  5,  /* BT.601-6 625 (BT.470-6 System B, G) */
	VIDEO_CP_NTSC           =  6,  /* BT.601-6 525 (SMPTE ST 170M) */
	VIDEO_CP_SMPTE240M      =  7,  /* SMPTE 240M, same as 6 */
	VIDEO_CP_FILM           =  8,
	VIDEO_CP_BT2020_2       =  9,  /* BT.2020-2 */
	VIDEO_CP_SMPTE_428_1    = 10,  /* SMPTE 428-1, no support */
	VIDEO_CP_SMPTE_RP431_2  = 11,  /* SMPTE RP 431-2 */
	VIDEO_CP_SMPTE_RP432_1  = 12,  /* SMPTE RP 432-1 */
	VIDEO_CP_EBU_TECH3213_E = 22,  /* EBU Tech. 3213-E */

	/* internal use only */
	VIDEO_CP_NTSC_J         = 1000, /* NTSC + D93 */
	VIDEO_CP_ADOBE_RGB,             /* Adobe RGB */
	VIDEO_CP_DCI_P3_D65,            /* DCI-P3 D65 */
	VIDEO_CP_DCI_P3,                /* DCI-P3 */
};

/*
 * Default:
 * <   720: BT.601
 * >=  720: BT.709
 * >= 2160: BT.2020NC
 */
enum video_colormatrix_type {
	VIDEO_CM_DEFAULT      = -1,
	VIDEO_CM_GBR          =  0,  /* no support */
	VIDEO_CM_BT709_6      =  1,
	VIDEO_CM_UNSPECIFIED  =  2,
	VIDEO_CM_FCC          =  4,
	VIDEO_CM_PAL          =  5,  /* BT.601-6 625 (BT.470-6 System B, G), same as 6 */
	VIDEO_CM_NTSC         =  6,  /* BT.601-6 525 (SMPTE ST 170M), same as 5 */
	VIDEO_CM_SMPTE_240M   =  7,  /* SMPTE 240M */
	VIDEO_CM_YCGCO        =  8,  /* no support */
	VIDEO_CM_BT2020NC     =  9,  /* BT.2020 Non-constant luminance */
	VIDEO_CM_BT2020C      = 10,  /* BT.2020 Constant luminance */
	VIDEO_CM_YDZDX        = 11,  /* no support */

	VIDEO_CM_BT601_6      = VIDEO_CM_NTSC,
};

enum video_range_type {
	VIDEO_RANGE_DEFAULT,
	VIDEO_RANGE_PARTIAL,
	VIDEO_RANGE_FULL
};

struct video_data {
	uint8_t           *data[MAX_AV_PLANES];
	uint32_t          linesize[MAX_AV_PLANES];
	uint64_t          timestamp;
};

struct video_output_info {
	const char        *name;

	enum video_format format;
	uint32_t          fps_num;
	uint32_t          fps_den;
	uint32_t          width;
	uint32_t          height;
	size_t            cache_size;

	enum video_colorspace colorspace;
	enum video_range_type range;
};

static inline bool format_is_yuv(enum video_format format)
{
	switch (format) {
	case VIDEO_FORMAT_I420:
	case VIDEO_FORMAT_NV12:
	case VIDEO_FORMAT_YVYU:
	case VIDEO_FORMAT_YUY2:
	case VIDEO_FORMAT_UYVY:
	case VIDEO_FORMAT_I444:
		return true;
	case VIDEO_FORMAT_NONE:
	case VIDEO_FORMAT_RGBA:
	case VIDEO_FORMAT_BGRA:
	case VIDEO_FORMAT_BGRX:
	case VIDEO_FORMAT_Y800:
	case VIDEO_FORMAT_R210:
	case VIDEO_FORMAT_R10B:
	case VIDEO_FORMAT_R10L:
		return false;
	}

	return false;
}

static inline const char *get_video_format_name(enum video_format format)
{
	switch (format) {
	case VIDEO_FORMAT_I420: return "I420";
	case VIDEO_FORMAT_NV12: return "NV12";
	case VIDEO_FORMAT_YVYU: return "YVYU";
	case VIDEO_FORMAT_YUY2: return "YUY2";
	case VIDEO_FORMAT_UYVY: return "UYVY";
	case VIDEO_FORMAT_RGBA: return "RGBA";
	case VIDEO_FORMAT_BGRA: return "BGRA";
	case VIDEO_FORMAT_BGRX: return "BGRX";
	case VIDEO_FORMAT_I444: return "I444";
	case VIDEO_FORMAT_Y800: return "Y800";
	case VIDEO_FORMAT_R210: return "r210";
	case VIDEO_FORMAT_R10B: return "R10b";
	case VIDEO_FORMAT_R10L: return "R10l";
	case VIDEO_FORMAT_NONE:;
	}

	return "None";
}

static inline int get_video_colorbit(enum video_format format)
{
	switch (format) {
	case VIDEO_FORMAT_I420:
	case VIDEO_FORMAT_NV12:
	case VIDEO_FORMAT_YVYU:
	case VIDEO_FORMAT_YUY2:
	case VIDEO_FORMAT_UYVY:
	case VIDEO_FORMAT_I444:
	case VIDEO_FORMAT_RGBA:
	case VIDEO_FORMAT_BGRA:
	case VIDEO_FORMAT_BGRX:
	case VIDEO_FORMAT_Y800:
		return 8;

	case VIDEO_FORMAT_R210:
	case VIDEO_FORMAT_R10B:
	case VIDEO_FORMAT_R10L:
		return 10;
	}

	return 8;
}

enum video_scale_type {
	VIDEO_SCALE_DEFAULT,
	VIDEO_SCALE_POINT,
	VIDEO_SCALE_FAST_BILINEAR,
	VIDEO_SCALE_BILINEAR,
	VIDEO_SCALE_BICUBIC,
};

struct video_scale_info {
	enum video_format     format;
	uint32_t              width;
	uint32_t              height;
	enum video_range_type range;
	enum video_colorspace colorspace;
};

EXPORT enum video_format video_format_from_fourcc(uint32_t fourcc);

EXPORT bool video_format_get_parameters(enum video_colorspace color_space,
		enum video_range_type range, float matrix[16],
		float min_range[3], float max_range[3]);

#define VIDEO_OUTPUT_SUCCESS       0
#define VIDEO_OUTPUT_INVALIDPARAM -1
#define VIDEO_OUTPUT_FAIL         -2

EXPORT int video_output_open(video_t **video, struct video_output_info *info);
EXPORT void video_output_close(video_t *video);

EXPORT bool video_output_connect(video_t *video,
		const struct video_scale_info *conversion,
		void (*callback)(void *param, struct video_data *frame),
		void *param);
EXPORT void video_output_disconnect(video_t *video,
		void (*callback)(void *param, struct video_data *frame),
		void *param);

EXPORT bool video_output_active(const video_t *video);

EXPORT const struct video_output_info *video_output_get_info(
		const video_t *video);
EXPORT bool video_output_lock_frame(video_t *video, struct video_frame *frame,
		int count, uint64_t timestamp);
EXPORT void video_output_unlock_frame(video_t *video);
EXPORT uint64_t video_output_get_frame_time(const video_t *video);
EXPORT void video_output_stop(video_t *video);
EXPORT bool video_output_stopped(video_t *video);

EXPORT enum video_format video_output_get_format(const video_t *video);
EXPORT uint32_t video_output_get_width(const video_t *video);
EXPORT uint32_t video_output_get_height(const video_t *video);
EXPORT double video_output_get_frame_rate(const video_t *video);

EXPORT uint32_t video_output_get_skipped_frames(const video_t *video);
EXPORT uint32_t video_output_get_total_frames(const video_t *video);


#ifdef __cplusplus
}
#endif
