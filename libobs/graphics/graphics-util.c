#include "graphics-util.h"

static inline gsutil_geometry_t *geometry_create()
{
	return bzalloc(sizeof(gsutil_geometry_t));
}

static inline uint16_t *index_create(size_t count)
{
	return bzalloc(sizeof(uint16_t) * count * 3);
}

static inline size_t index_length(size_t count)
{
	return count * 3;
}

static inline void gs_index3i(uint16_t *ptr, size_t pos,
		uint16_t a, uint16_t b, uint16_t c)
{
	pos *= 3;
	ptr[pos    ] = a;
	ptr[pos + 1] = b;
	ptr[pos + 2] = c;
}

gsutil_geometry_t *circle_geometry_create(struct vec2 origin, float radius,
		uint8_t segments, float theta_start, float theta_size)
{
	gsutil_geometry_t *ret = geometry_create();

	gs_render_start(true);
	gs_vertex2v(&origin);

	struct vec2 buf;
	for (uint8_t s = 0; s <= segments; s++) {
		float seg = theta_start + (float)s / segments * theta_size;
		vec2_set(&buf,
				origin.x + radius * cosf(seg),
				origin.y + radius * sinf(seg));
		gs_vertex2v(&buf);
	}
	ret->vertex = gs_render_save();

	uint16_t *idx = index_create(segments);
	for (uint16_t i = 0; i < segments; i++) {
		gs_index3i(idx, i, 0, i + 1, i + 2);
	}
	ret->index = gs_indexbuffer_create(GS_UNSIGNED_SHORT, idx,
			index_length(segments), 0);
	
	return ret;
}

gsutil_geometry_t *line_geometry_create(struct vec2 s, struct vec2 e, float w)
{
	gsutil_geometry_t *ret = geometry_create();
	
	w *= 0.5f;

	const float angle = atan2f(e.y - s.y, e.x - s.x);
	const float wx = w * sinf(angle);
	const float wy = w * cosf(angle);
	gs_render_start(true);
	gs_vertex2f(s.x + wx - wy, s.y - wy - wx);
	gs_vertex2f(e.x + wx + wy, e.y - wy + wx);
	gs_vertex2f(e.x - wx + wy, e.y + wy + wx);
	gs_vertex2f(s.x - wx - wy, s.y + wy - wx);
	ret->vertex = gs_render_save();

	const size_t count = 2;
	uint16_t *idx = index_create(count);
	gs_index3i(idx, 0, 0, 1, 2);
	gs_index3i(idx, 1, 2, 3, 0);
	ret->index = gs_indexbuffer_create(GS_UNSIGNED_SHORT, idx,
			index_length(count), 0);
	
	return ret;
}

gsutil_geometry_t *rect_geometry_create(struct vec2 tl, struct vec2 tr,
		struct vec2 bl, struct vec2 br)
{
	gsutil_geometry_t *ret = geometry_create();

	gs_render_start(true);
	gs_vertex2v(&tl);
	gs_vertex2v(&tr);
	gs_vertex2v(&br);
	gs_vertex2v(&bl);
	ret->vertex = gs_render_save();

	const size_t count = 2;
	uint16_t *idx = index_create(count);
	gs_index3i(idx, 0, 0, 1, 2);
	gs_index3i(idx, 1, 2, 3, 0);
	ret->index = gs_indexbuffer_create(GS_UNSIGNED_SHORT, idx,
			index_length(count), 0);

	return ret;
}

gsutil_geometry_t *rectline_geometry_create(struct vec2 tl, struct vec2 tr,
		struct vec2 bl, struct vec2 br, float w)
{
	gsutil_geometry_t *ret = geometry_create();
	
	w *= 0.5f;
	
	gs_render_start(true);

	const float angle1 = atan2f(tr.y - tl.y, tr.x - tl.x);
	const float wx1 = w * sinf(angle1);
	const float wy1 = w * cosf(angle1);
	gs_vertex2f(tl.x + wx1 - wy1, tl.y - wy1 - wx1);
	gs_vertex2f(tr.x + wx1 + wy1, tr.y - wy1 + wx1);
	gs_vertex2f(tr.x - wx1 + wy1, tr.y + wy1 + wx1);
	gs_vertex2f(tl.x - wx1 - wy1, tl.y + wy1 - wx1);

	const float angle2 = atan2f(br.y - tr.y, br.x - tr.x);
	const float wx2 = w * sinf(angle2);
	const float wy2 = w * cosf(angle2);
	gs_vertex2f(br.x + wx2 - wy2, br.y - wy2 - wx2);
	gs_vertex2f(br.x - wx2 + wy2, br.y + wy2 + wx2);
	gs_vertex2f(tr.x - wx2 - wy2, tr.y + wy2 - wx2);

	const float angle3 = atan2f(br.y - bl.y, br.x - bl.x);
	const float wx3 = w * sinf(angle3);
	const float wy3 = w * cosf(angle3);
	gs_vertex2f(bl.x + wx3 - wy3, bl.y - wy3 - wx3);
	gs_vertex2f(br.x - wx3 + wy3, br.y + wy3 + wx3);
	gs_vertex2f(bl.x - wx3 + wy3, bl.y + wy3 + wx3);

	const float angle4 = atan2f(bl.y - tl.y, bl.x - tl.x);
	const float wx4 = w * sinf(angle4);
	const float wy4 = w * cosf(angle4);
	gs_vertex2f(bl.x - wx4 + wy4, bl.y + wy4 + wx4);
	gs_vertex2f(tl.x + wx4 + wy4, tl.y - wy4 + wx4);
	
	ret->vertex = gs_render_save();

	const size_t count = 8;
	uint16_t *idx = index_create(count);
	gs_index3i(idx, 0, 0, 1, 2);
	gs_index3i(idx, 1, 2, 3, 0);
	gs_index3i(idx, 2, 1, 4, 5);
	gs_index3i(idx, 3, 5, 6, 1);
	gs_index3i(idx, 4, 7, 4, 8);
	gs_index3i(idx, 5, 8, 9, 7);
	gs_index3i(idx, 6, 3, 10, 9);
	gs_index3i(idx, 7, 9, 11, 3);
	ret->index = gs_indexbuffer_create(GS_UNSIGNED_SHORT, idx,
			index_length(count), 0);
	
	return ret;
}
