#include "decklink-device-mode.hpp"

DeckLinkDeviceMode::DeckLinkDeviceMode(IDeckLinkDisplayMode *mode,
		long long id) : id(id), mode(mode)
{
	if (mode == nullptr)
		return;

	mode->AddRef();

	decklink_string_t decklinkStringName;
	if (mode->GetName(&decklinkStringName) == S_OK)
		DeckLinkStringToStdString(decklinkStringName, name);
}

DeckLinkDeviceMode::DeckLinkDeviceMode(const std::string& name, long long id) :
	id(id), mode(nullptr), name(name)
{
}

DeckLinkDeviceMode::~DeckLinkDeviceMode(void)
{
	if (mode != nullptr)
		mode->Release();
}

void DeckLinkDeviceMode::Init(IDeckLinkInput *input)
{
	static BMDPixelFormat const checkFormats[] =
	{
		bmdFormat8BitYUV,
		bmdFormat10BitYUV,
		bmdFormat8BitBGRA,
		bmdFormat10BitRGBXLE
	};
	static int32_t const formatCount =
			sizeof(checkFormats) / sizeof(checkFormats[0]);

	if (mode == nullptr)
		return;

	BMDDisplayMode displayMode = GetDisplayMode();
	for (int32_t i = 0; i < formatCount; ++i) {
		BMDDisplayModeSupport support;
		if (input->DoesSupportVideoMode(displayMode, checkFormats[i],
				bmdVideoInputFlagDefault, &support,
				nullptr) == S_OK) {
			if (support != bmdDisplayModeNotSupported)
				formats.push_back(checkFormats[i]);
		}
	}
}

BMDDisplayMode DeckLinkDeviceMode::GetDisplayMode(void) const
{
	if (mode != nullptr)
		return mode->GetDisplayMode();

	return bmdModeUnknown;
}

BMDDisplayModeFlags DeckLinkDeviceMode::GetDisplayModeFlags(void) const
{
	if (mode != nullptr)
		return mode->GetFlags();

	return (BMDDisplayModeFlags)0;
}

BMDFieldDominance DeckLinkDeviceMode::GetFieldDominance(void) const
{
	if (mode != nullptr)
		return mode->GetFieldDominance();

	return bmdUnknownFieldDominance;
}

long long DeckLinkDeviceMode::GetId(void) const
{
	return id;
}

const std::string& DeckLinkDeviceMode::GetName(void) const
{
	return name;
}

void DeckLinkDeviceMode::SetMode(IDeckLinkDisplayMode *mode_)
{
	IDeckLinkDisplayMode *old = mode;
	if (old != nullptr)
		old->Release();

	mode = mode_;
	if (mode != nullptr)
		mode->AddRef();
}
