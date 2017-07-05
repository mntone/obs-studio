#pragma once

#include "graphics.h"
#include "vec2.h"
#include "vec3.h"

#ifdef __cplusplus
extern "C" {
#endif

struct gsutil_geometry
{
	gs_vertbuffer_t  *vertex;
	gs_indexbuffer_t *index;
};

typedef struct gsutil_geometry gsutil_geometry_t;

EXPORT gsutil_geometry_t *circle_geometry_create(struct vec2 origin,
		float radius, uint8_t segments,
		float theta_start, float theta_size);
EXPORT gsutil_geometry_t *line_geometry_create(struct vec2 start,
		struct vec2 end, float width);
EXPORT gsutil_geometry_t *rect_geometry_create(struct vec2 topleft,
		struct vec2 topright, struct vec2 bottomleft,
		struct vec2 bottomright);
EXPORT gsutil_geometry_t *rectline_geometry_create(struct vec2 topleft,
		struct vec2 topright, struct vec2 bottomleft,
		struct vec2 bottomright, float width);

static inline void gsutil_load_geometry(gsutil_geometry_t *geometry)
{
	if (!geometry)
		return;

	gs_load_vertexbuffer(geometry->vertex);
	gs_load_indexbuffer(geometry->index);
}

static inline void gsutil_geometry_destroy(gsutil_geometry_t *geometry)
{
	if (!geometry)
		return;

	gs_vertexbuffer_destroy(geometry->vertex);
	gs_indexbuffer_destroy(geometry->index);
	bfree(geometry);
}

#ifdef __cplusplus
}
#endif
