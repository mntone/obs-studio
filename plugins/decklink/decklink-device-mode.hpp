#pragma once

#include "platform.hpp"

#include <string>
#include <vector>

#define MODE_ID_AUTO  -1

class DeckLinkDeviceMode {
protected:
	long long                   id;
	IDeckLinkDisplayMode        *mode;
	std::string                 name;
	std::vector<BMDPixelFormat> formats;

public:
	DeckLinkDeviceMode(IDeckLinkDisplayMode *mode, long long id);
	DeckLinkDeviceMode(const std::string& name, long long id);
	virtual ~DeckLinkDeviceMode(void);

	void Init(IDeckLinkInput *input);

	BMDDisplayMode GetDisplayMode(void) const;
	BMDDisplayModeFlags GetDisplayModeFlags(void) const;
	BMDFieldDominance GetFieldDominance(void) const;
	long long GetId(void) const;
	const std::string& GetName(void) const;

	void SetMode(IDeckLinkDisplayMode *mode);
};
