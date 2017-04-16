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

#include "format-conversion.h"
#include <xmmintrin.h>
#include <emmintrin.h>

/* ...surprisingly, if I don't use a macro to force inlining, it causes the
 * CPU usage to boost by a tremendous amount in debug builds. */

#define get_m128_32_0(val) (*((uint32_t*)&val))
#define get_m128_32_1(val) (*(((uint32_t*)&val)+1))

#define pack_shift(lum_plane, lum_pos0, lum_pos1, line1, line2, mask, sh)     \
do {                                                                          \
	__m128i pack_val = _mm_packs_epi32(                                   \
			_mm_srli_si128(_mm_and_si128(line1, mask), sh),       \
			_mm_srli_si128(_mm_and_si128(line2, mask), sh));      \
	pack_val = _mm_packus_epi16(pack_val, pack_val);                      \
                                                                              \
	*(uint32_t*)(lum_plane+lum_pos0) = get_m128_32_0(pack_val);           \
	*(uint32_t*)(lum_plane+lum_pos1) = get_m128_32_1(pack_val);           \
} while (false)

#define pack_val(lum_plane, lum_pos0, lum_pos1, line1, line2, mask)           \
do {                                                                          \
	__m128i pack_val = _mm_packs_epi32(                                   \
			_mm_and_si128(line1, mask),                           \
			_mm_and_si128(line2, mask));                          \
	pack_val = _mm_packus_epi16(pack_val, pack_val);                      \
                                                                              \
	*(uint32_t*)(lum_plane+lum_pos0) = get_m128_32_0(pack_val);           \
	*(uint32_t*)(lum_plane+lum_pos1) = get_m128_32_1(pack_val);           \
} while (false)

#define pack_ch_1plane(uv_plane, chroma_pos, line1, line2, uv_mask)           \
do {                                                                          \
	__m128i add_val = _mm_add_epi64(                                      \
			_mm_and_si128(line1, uv_mask),                        \
			_mm_and_si128(line2, uv_mask));                       \
	__m128i avg_val = _mm_add_epi64(                                      \
			add_val,                                              \
			_mm_shuffle_epi32(add_val, _MM_SHUFFLE(2, 3, 0, 1))); \
	avg_val = _mm_srai_epi16(avg_val, 2);                                 \
	avg_val = _mm_shuffle_epi32(avg_val, _MM_SHUFFLE(3, 1, 2, 0));        \
	avg_val = _mm_packus_epi16(avg_val, avg_val);                         \
                                                                              \
	*(uint32_t*)(uv_plane+chroma_pos) = get_m128_32_0(avg_val);           \
} while (false)

#define pack_ch_2plane(u_plane, v_plane, chroma_pos, line1, line2, uv_mask)   \
do {                                                                          \
	uint32_t packed_vals;                                                 \
                                                                              \
	__m128i add_val = _mm_add_epi64(                                      \
			_mm_and_si128(line1, uv_mask),                        \
			_mm_and_si128(line2, uv_mask));                       \
	__m128i avg_val = _mm_add_epi64(                                      \
			add_val,                                              \
			_mm_shuffle_epi32(add_val, _MM_SHUFFLE(2, 3, 0, 1))); \
	avg_val = _mm_srai_epi16(avg_val, 2);                                 \
	avg_val = _mm_shuffle_epi32(avg_val, _MM_SHUFFLE(3, 1, 2, 0));        \
	avg_val = _mm_shufflelo_epi16(avg_val, _MM_SHUFFLE(3, 1, 2, 0));      \
	avg_val = _mm_packus_epi16(avg_val, avg_val);                         \
                                                                              \
	packed_vals = get_m128_32_0(avg_val);                                 \
                                                                              \
	*(uint16_t*)(u_plane+chroma_pos) = (uint16_t)(packed_vals);           \
	*(uint16_t*)(v_plane+chroma_pos) = (uint16_t)(packed_vals>>16);       \
} while (false)

#define _MM_OR_SI128_OP3(x, y, z)    _mm_or_si128(_mm_or_si128(x, y), z)
#define _MM_OR_SI128_OP4(x, y, z, w) _mm_or_si128(_MM_OR_SI128_OP3(x, y, z), w)
#define _MM_AND_SLLI_EPI32(x, m, i)  _mm_slli_epi32(_mm_and_si128(x, m), i)
#define _MM_AND_SRLI_EPI32(x, m, i)  _mm_srli_epi32(_mm_and_si128(x, m), i)


static FORCE_INLINE uint32_t min_uint32(uint32_t a, uint32_t b)
{
	return a < b ? a : b;
}

void compress_uyvx_to_i420(
		const uint8_t *input, uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output[], const uint32_t out_linesize[])
{
	uint8_t  *lum_plane   = output[0];
	uint8_t  *u_plane     = output[1];
	uint8_t  *v_plane     = output[2];
	uint32_t width        = min_uint32(in_linesize, out_linesize[0]);
	uint32_t y;

	__m128i lum_mask = _mm_set1_epi32(0x0000FF00);
	__m128i uv_mask  = _mm_set1_epi16(0x00FF);

	for (y = start_y; y < end_y; y += 2) {
		uint32_t y_pos        = y      * in_linesize;
		uint32_t chroma_y_pos = (y>>1) * out_linesize[1];
		uint32_t lum_y_pos    = y      * out_linesize[0];
		uint32_t x;

		for (x = 0; x < width; x += 4) {
			const uint8_t *img = input + y_pos + x*4;
			uint32_t lum_pos0  = lum_y_pos + x;
			uint32_t lum_pos1  = lum_pos0 + out_linesize[0];

			__m128i line1 = _mm_load_si128((const __m128i*)img);
			__m128i line2 = _mm_load_si128(
					(const __m128i*)(img + in_linesize));

			pack_shift(lum_plane, lum_pos0, lum_pos1,
					line1, line2, lum_mask, 1);
			pack_ch_2plane(u_plane, v_plane,
					chroma_y_pos + (x>>1),
					line1, line2, uv_mask);
		}
	}
}

void compress_uyvx_to_nv12(
		const uint8_t *input, uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output[], const uint32_t out_linesize[])
{
	uint8_t *lum_plane    = output[0];
	uint8_t *chroma_plane = output[1];
	uint32_t width        = min_uint32(in_linesize, out_linesize[0]);
	uint32_t y;

	__m128i lum_mask = _mm_set1_epi32(0x0000FF00);
	__m128i uv_mask  = _mm_set1_epi16(0x00FF);

	for (y = start_y; y < end_y; y += 2) {
		uint32_t y_pos        = y      * in_linesize;
		uint32_t chroma_y_pos = (y>>1) * out_linesize[1];
		uint32_t lum_y_pos    = y      * out_linesize[0];
		uint32_t x;

		for (x = 0; x < width; x += 4) {
			const uint8_t *img = input + y_pos + x*4;
			uint32_t lum_pos0  = lum_y_pos + x;
			uint32_t lum_pos1  = lum_pos0 + out_linesize[0];

			__m128i line1 = _mm_load_si128((const __m128i*)img);
			__m128i line2 = _mm_load_si128(
					(const __m128i*)(img + in_linesize));

			pack_shift(lum_plane, lum_pos0, lum_pos1,
					line1, line2, lum_mask, 1);
			pack_ch_1plane(chroma_plane, chroma_y_pos + x,
					line1, line2, uv_mask);
		}
	}
}

void convert_uyvx_to_i444(
		const uint8_t *input, uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output[], const uint32_t out_linesize[])
{
	uint8_t  *lum_plane   = output[0];
	uint8_t  *u_plane     = output[1];
	uint8_t  *v_plane     = output[2];
	uint32_t width        = min_uint32(in_linesize, out_linesize[0]);
	uint32_t y;

	__m128i lum_mask = _mm_set1_epi32(0x0000FF00);
	__m128i u_mask   = _mm_set1_epi32(0x000000FF);
	__m128i v_mask   = _mm_set1_epi32(0x00FF0000);

	for (y = start_y; y < end_y; y += 2) {
		uint32_t y_pos        = y      * in_linesize;
		uint32_t lum_y_pos    = y      * out_linesize[0];
		uint32_t x;

		for (x = 0; x < width; x += 4) {
			const uint8_t *img = input + y_pos + x*4;
			uint32_t lum_pos0  = lum_y_pos + x;
			uint32_t lum_pos1  = lum_pos0 + out_linesize[0];

			__m128i line1 = _mm_load_si128((const __m128i*)img);
			__m128i line2 = _mm_load_si128(
					(const __m128i*)(img + in_linesize));

			pack_shift(lum_plane, lum_pos0, lum_pos1,
					line1, line2, lum_mask, 1);
			pack_val(u_plane, lum_pos0, lum_pos1,
					line1, line2, u_mask);
			pack_shift(v_plane, lum_pos0, lum_pos1,
					line1, line2, v_mask, 2);
		}
	}
}

void decompress_420(
		const uint8_t *const input[], const uint32_t in_linesize[],
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t start_y_d2 = start_y/2;
	uint32_t width_d2   = min_uint32(in_linesize[0], out_linesize)/2;
	uint32_t height_d2  = end_y/2;
	uint32_t y;

	for (y = start_y_d2; y < height_d2; y++) {
		const uint8_t *chroma0 = input[1] + y * in_linesize[1];
		const uint8_t *chroma1 = input[2] + y * in_linesize[2];
		register const uint8_t *lum0, *lum1;
		register uint32_t *output0, *output1;
		uint32_t x;

		lum0 = input[0] + y * 2 * in_linesize[0];
		lum1 = lum0 + in_linesize[0];
		output0 = (uint32_t*)(output + y * 2 * in_linesize[0]);
		output1 = (uint32_t*)((uint8_t*)output0 + in_linesize[0]);

		for (x = 0; x < width_d2; x++) {
			uint32_t out;
			out = (*(chroma0++) << 8) | (*(chroma1++) << 16);

			*(output0++) = *(lum0++) | out;
			*(output0++) = *(lum0++) | out;

			*(output1++) = *(lum1++) | out;
			*(output1++) = *(lum1++) | out;
		}
	}
}

void decompress_nv12(
		const uint8_t *const input[], const uint32_t in_linesize[],
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t start_y_d2 = start_y/2;
	uint32_t width_d2   = min_uint32(in_linesize[0], out_linesize)/2;
	uint32_t height_d2  = end_y/2;
	uint32_t y;

	for (y = start_y_d2; y < height_d2; y++) {
		const uint16_t *chroma;
		register const uint8_t *lum0, *lum1;
		register uint32_t *output0, *output1;
		uint32_t x;

		chroma = (const uint16_t*)(input[1] + y * in_linesize[1]);
		lum0 = input[0] + y * 2 * in_linesize[0];
		lum1 = lum0 + in_linesize[0];
		output0 = (uint32_t*)(output + y * 2 * out_linesize);
		output1 = (uint32_t*)((uint8_t*)output0 + out_linesize);

		for (x = 0; x < width_d2; x++) {
			uint32_t out = *(chroma++) << 8;

			*(output0++) = *(lum0++) | out;
			*(output0++) = *(lum0++) | out;

			*(output1++) = *(lum1++) | out;
			*(output1++) = *(lum1++) | out;
		}
	}
}

void decompress_422(
		const uint8_t *input, uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize,
		bool leading_lum)
{
	uint32_t width_d2 = min_uint32(in_linesize, out_linesize)/2;
	uint32_t y;

	register const uint32_t *input32;
	register const uint32_t *input32_end;
	register uint32_t       *output32;

	if (leading_lum) {
		for (y = start_y; y < end_y; y++) {
			input32     = (const uint32_t*)(input + y*in_linesize);
			input32_end = input32 + width_d2;
			output32    = (uint32_t*)(output + y*out_linesize);

			while(input32 < input32_end) {
				register uint32_t dw = *input32;

				output32[0] = dw;
				dw &= 0xFFFFFF00;
				dw |= (uint8_t)(dw>>16);
				output32[1] = dw;

				output32 += 2;
				input32++;
			}
		}
	} else {
		for (y = start_y; y < end_y; y++) {
			input32     = (const uint32_t*)(input + y*in_linesize);
			input32_end = input32 + width_d2;
			output32    = (uint32_t*)(output + y*out_linesize);

			while (input32 < input32_end) {
				register uint32_t dw = *input32;

				output32[0] = dw;
				dw &= 0xFFFF00FF;
				dw |= (dw>>16) & 0xFF00;
				output32[1] = dw;

				output32 += 2;
				input32++;
			}
		}
	}
}

void decompress_v210(
		const uint8_t *input, uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width_d = min_uint32(in_linesize / 4, out_linesize / 6);
	uint32_t y;

	register const uint32_t *input0;
	register const uint32_t *input0_end;
	register uint32_t       *output0;

	for (y = start_y; y < end_y; y++) {
		input0     = (const uint32_t*)(input + y*in_linesize);
		input0_end = input0 + width_d;
		output0    = (uint32_t*)(output + y*out_linesize);

		while (input0 < input0_end) {
			register uint32_t tmp0, tmp1;

			tmp0 = *(input0++);
			tmp1 = *(input0++);

			*(output0++) =  (tmp0 & 0x000003FF) << 10 |
					(tmp0 & 0x000FFC00) >> 10 |
					(tmp0 & 0x3FF00000);
			*(output0++) =  (tmp0 & 0x000003FF) << 10 |
					(tmp0 & 0x3FF00000) |
					(tmp1 & 0x000003FF);

			tmp0 = *(input0++);

			*(output0++) =  (tmp1 & 0x000FFC00) |
					(tmp1 & 0x3FF00000) >> 20 | 
					(tmp0 & 0x000003FF) << 20;
			*(output0++) =  (tmp1 & 0x000FFC00) |
					(tmp0 & 0x000FFC00) >> 10 |
					(tmp0 & 0x000003FF) << 20;

			tmp1 = *(input0++);

			*(output0++) =  (tmp0 & 0x3FF00000) >> 10 |
					(tmp1 & 0x000003FF) |
					(tmp1 & 0x000FFC00) << 10;
			*(output0++) =  (tmp0 & 0x3FF00000) >> 10 |
					(tmp1 & 0x3FF00000) >> 20 |
					(tmp1 & 0x000FFC00) << 10;
		}
	}
}

void decompress_r210(
		const uint8_t *input, const uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width_d4 = min_uint32(in_linesize, out_linesize) / 16;
	uint32_t y;

	const __m128i base    = _mm_set1_epi32(0xC0000000);
	const __m128i mask_r0 = _mm_set1_epi32(0x0000003F);
	const __m128i mask_r1 = _mm_set1_epi32(0x0000F000);
	const __m128i mask_g0 = _mm_set1_epi32(0x00000F00);
	const __m128i mask_g1 = _mm_set1_epi32(0x00FC0000);
	const __m128i mask_b0 = _mm_set1_epi32(0x00030000);
	const __m128i mask_b1 = _mm_set1_epi32(0xFF000000);

	for (y = start_y; y < end_y; y++) {
		const __m128i *input0;
		register __m128i *output0;
		uint32_t x;

		input0 = (const __m128i*)(input + y * in_linesize);
		output0 = (__m128i*)(output + y * out_linesize);

		for (x = 0; x < width_d4; x++) {
			const __m128i tmp = _mm_load_si128(input0++);
			const __m128i r0 = _MM_AND_SLLI_EPI32(tmp, mask_r0,  4);
			const __m128i r1 = _MM_AND_SRLI_EPI32(tmp, mask_r1, 12);
			const __m128i g0 = _MM_AND_SLLI_EPI32(tmp, mask_g0,  8);
			const __m128i g1 = _MM_AND_SRLI_EPI32(tmp, mask_g1,  8);
			const __m128i b0 = _MM_AND_SLLI_EPI32(tmp, mask_b0, 12);
			const __m128i b1 = _MM_AND_SRLI_EPI32(tmp, mask_b1,  4);

			_mm_stream_si128(output0++, _MM_OR_SI128_OP4(base,
					_mm_or_si128(r0, r1),
					_mm_or_si128(g0, g1),
					_mm_or_si128(b0, b1)));
		}
	}
}

void decompress_r10b(
		const uint8_t *input, const uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width_d4 = min_uint32(in_linesize, out_linesize) / 16;
	uint32_t y;

	const __m128i base    = _mm_set1_epi32(0xC0000000);
	const __m128i mask_r0 = _mm_set1_epi32(0x000000FF);
	const __m128i mask_r1 = _mm_set1_epi32(0x0000C000);
	const __m128i mask_g0 = _mm_set1_epi32(0x00003F00);
	const __m128i mask_g1 = _mm_set1_epi32(0x00F00000);
	const __m128i mask_b0 = _mm_set1_epi32(0x000F0000);
	const __m128i mask_b1 = _mm_set1_epi32(0xFC000000);

	for (y = start_y; y < end_y; y++) {
		const __m128i *input0;
		register __m128i *output0;
		uint32_t x;

		input0 = (const __m128i*)(input + y * in_linesize);
		output0 = (__m128i*)(output + y * out_linesize);

		for (x = 0; x < width_d4; x++) {
			const __m128i tmp = _mm_load_si128(input0++);
			const __m128i r0 = _MM_AND_SLLI_EPI32(tmp, mask_r0,  2);
			const __m128i r1 = _MM_AND_SRLI_EPI32(tmp, mask_r1, 14);
			const __m128i g0 = _MM_AND_SLLI_EPI32(tmp, mask_g0,  6);
			const __m128i g1 = _MM_AND_SRLI_EPI32(tmp, mask_g1, 10);
			const __m128i b0 = _MM_AND_SLLI_EPI32(tmp, mask_b0, 10);
			const __m128i b1 = _MM_AND_SRLI_EPI32(tmp, mask_b1,  6);

			_mm_stream_si128(output0++, _MM_OR_SI128_OP4(base,
					_mm_or_si128(r0, r1),
					_mm_or_si128(g0, g1),
					_mm_or_si128(b0, b1)));
		}
	}
}

void decompress_r10l(
		const uint8_t *input, const uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width_d4 = min_uint32(in_linesize, out_linesize) / 16;
	uint32_t y;

	const __m128i base   = _mm_set1_epi32(0xC0000000);
	const __m128i mask_r = _mm_set1_epi32(0xFFC00000);
	const __m128i mask_g = _mm_set1_epi32(0x003FF000);
	const __m128i mask_b = _mm_set1_epi32(0x00000FFC);

	for (y = start_y; y < end_y; y++) {
		const __m128i *input0;
		register __m128i *output0;
		uint32_t x;

		input0 = (const __m128i*)(input + y * in_linesize);
		output0 = (__m128i*)(output + y * out_linesize);

		for (x = 0; x < width_d4; x++) {
			const __m128i tmp = _mm_load_si128(input0++);
			const __m128i r = _MM_AND_SRLI_EPI32(tmp, mask_r, 22);
			const __m128i g = _MM_AND_SRLI_EPI32(tmp, mask_g,  2);
			const __m128i b = _MM_AND_SLLI_EPI32(tmp, mask_b, 18);

			_mm_stream_si128(output0++,
					_MM_OR_SI128_OP4(base, r, g, b));
		}
	}
}

void decompress_r12b(
		const uint8_t *input, const uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width = min_uint32(in_linesize / 36, out_linesize / 64);
	uint32_t y;

	for (y = start_y; y < end_y; y++) {
		const uint32_t *input0;
		register uint64_t *output0;
		uint32_t x;

		input0 = (const uint32_t*)(input + y * in_linesize);
		output0 = (uint64_t*)(output + y * out_linesize);

		for (x = 0; x < width; x++) {
			uint64_t out = *(input0++);

			*(output0) = 0xFFFF000000000000 |
					((out & 0xFF000000) >> 20) |
					((out & 0x000F0000) >>  4) |
					((out & 0x00F00000) >>  4) |
					((out & 0x0000FF00) << 16) |
					((out & 0x000000FF) << 36);

			out = *(input0++);

			*(output0++) |= ((out & 0x0F000000) << 20);
			*(output0) = 0xFFFF000000000000 |
					((out & 0xF0000000) >> 24) |
					((out & 0x00FF0000) >>  8) |
					((out & 0x0000FF00) << 12) |
					((out & 0x0000000F) << 28) |
					((out & 0x000000F0) << 32);

			out = *(input0++);

			*(output0++) |= ((out & 0xFF000000) << 16);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x00FF0000) >> 12) |
					((out & 0x00000F00) <<  4) |
					((out & 0x0000F000) <<  8) |
					((out & 0x000000FF) << 24);

			out = *(input0++);

			*(output0++) |= ((out & 0xFF000000) << 12) |
					((out & 0x000F0000) << 28);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x00F00000) >> 16) |
					((out & 0x0000FF00)      ) |
					((out & 0x000000FF) << 20);

			out = *(input0++);

			*(output0++) |= ((out & 0x0F000000) <<  4) |
					((out & 0xF0000000) <<  8) |
					((out & 0x00FF0000) << 24);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x0000FF00) >>  4) |
					((out & 0x0000000F) << 12) |
					((out & 0x000000F0) >> 16);

			out = *(input0++);

			*(output0++) |= ((out & 0xFF000000)      ) |
					((out & 0x00FF0000) << 20) |
					((out & 0x00000F00) << 36);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x0000F000) >>  8) |
					((out & 0x000000FF) <<  8);

			out = *(input0++);

			*(output0++) |= ((out & 0xFF000000) >>  4) |
					((out & 0x000F0000) << 12) |
					((out & 0x00F00000) << 16) |
					((out & 0x0000FF00) << 32);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x000000FF) <<  4);

			out = *(input0++);

			*(output0++) |= ((out & 0x0F000000) >> 12) |
					((out & 0xF0000000) >>  8) |
					((out & 0x00FF0000) <<  8) |
					((out & 0x0000FF00) << 28) |
					((out & 0x0000000F) << 44);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x000000F0)      );

			out = *(input0++);

			*(output0++) |= ((out & 0xFF000000) >> 16) |
					((out & 0x00FF0000) <<  4) |
					((out & 0x00000F00) << 20) |
					((out & 0x0000F000) << 24) |
					((out & 0x000000FF) << 40);
		}
	}
}

void decompress_r12l(
		const uint8_t *input, const uint32_t in_linesize,
		uint32_t start_y, uint32_t end_y,
		uint8_t *output, uint32_t out_linesize)
{
	uint32_t width = min_uint32(in_linesize / 36, out_linesize / 64);
	uint32_t y;

	for (y = start_y; y < end_y; y++) {
		const uint32_t *input0;
		register uint64_t *output0;
		uint32_t x;

		input0 = (const uint32_t*)(input + y * in_linesize);
		output0 = (uint64_t*)(output + y * out_linesize);

		for (x = 0; x < width; x++) {
			uint64_t out = *(input0++);

			*(output0) = 0xFFFF000000000000 |
					((out & 0x00000FFF) <<  4) |
					((out & 0x00FFF000) <<  8) |
					((out & 0xFF000000) << 12);

			out = *(input0++);

			*(output0++) |= ((out & 0x0000000F) << 44);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x0000FFF0)      ) |
					((out & 0x0FFF0000) <<  4) |
					((out & 0xF0000000) <<  8);

			out = *(input0++);

			*(output0++) |= ((out & 0x000000FF) << 40);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x000FFF00) >>  4) |
					((out & 0xFFF00000)      );

			out = *(input0++);

			*(output0++) |= ((out & 0x00000FFF) << 36);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x00FFF000) >>  8) |
					((out & 0xFF000000) >>  4);

			out = *(input0++);

			*(output0++) |= ((out & 0x0000000F) << 28) |
					((out & 0x0000FFF0) << 32);
			*(output0) = 0xFFFF000000000000 |
					((out & 0x0FFF0000) >> 12) |
					((out & 0xF0000000) >>  8);

			out = *(input0++);

			*(output0++) |= ((out & 0x000000FF) << 24) |
					((out & 0x000FFF00) << 28);
			*(output0) = 0xFFFF000000000000 |
					((out & 0xFFF00000) >> 16);

			out = *(input0++);

			*(output0++) |= ((out & 0x00000FFF) << 20) |
					((out & 0x00FFF000) << 24);
			*(output0) = 0xFFFF000000000000 |
					((out & 0xFF000000) >> 20);

			out = *(input0++);

			*(output0++) |= ((out & 0x0000000F) << 12) |
					((out & 0x0000FFF0) << 16) |
					((out & 0x0FFF0000) << 20);
			*(output0) = 0xFFFF000000000000 |
					((out & 0xF0000000) >> 24);

			out = *(input0++);

			*(output0++) |= ((out & 0x000000FF) <<  8) |
					((out & 0x000FFF00) << 12) |
					((out & 0xFFF00000) << 16);
		}
	}
}
