#include <graphics/graphics-util.h>

#ifdef __cplusplus

#include <memory>

namespace _gsutil_deleter {
	struct gsutil_geometry_deleter
	{
		void operator()(gsutil_geometry_t* geometry) const
		{
			gsutil_geometry_destroy(geometry);
		}
	};
}

using geometry_unique_ptr = std::unique_ptr<gsutil_geometry_t,
		_gsutil_deleter::gsutil_geometry_deleter>;

#endif
