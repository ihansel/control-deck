/*
Copyright 2026 ControlDeck contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <CoreAudio/AudioServerPlugIn.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

enum
{
	kDualSenseMicrophoneDeviceObjectID = 3,
	kDualSenseMicrophoneInputStreamObjectID = 4,
	kDualSenseMicrophoneOutputStreamObjectID = 8
};

typedef void* (*DualSenseMicrophoneFactory)(CFAllocatorRef, CFUUIDRef);

static int BuffersAreEqual(const Float32* inLeft, const Float32* inRight, UInt32 inSampleCount)
{
	for(UInt32 theIndex = 0; theIndex < inSampleCount; ++theIndex)
	{
		if(inLeft[theIndex] != inRight[theIndex])
		{
			return 0;
		}
	}
	return 1;
}

static int BufferIsSilent(const Float32* inBuffer, UInt32 inSampleCount)
{
	for(UInt32 theIndex = 0; theIndex < inSampleCount; ++theIndex)
	{
		if(inBuffer[theIndex] != 0.0f)
		{
			return 0;
		}
	}
	return 1;
}

static int VerifyPublishedContract(AudioServerPlugInDriverRef inDriver, AudioServerPlugInDriverInterface* inInterface)
{
	AudioObjectPropertyAddress theAddress = {
		kAudioDevicePropertyDeviceUID,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMain
	};
	CFStringRef theString = NULL;
	UInt32 theDataSize = sizeof(theString);
	UInt32 theOutputSize = 0;
	OSStatus theStatus = inInterface->GetPropertyData(
		inDriver,
		kDualSenseMicrophoneDeviceObjectID,
		0,
		&theAddress,
		0,
		NULL,
		theDataSize,
		&theOutputSize,
		&theString);
	if((theStatus != 0) ||
	   (theOutputSize != sizeof(theString)) ||
	   (theString == NULL) ||
	   (CFStringCompare(theString, CFSTR("com.ianhansel.controldeck.dualsense-microphone.virtual"), 0) != kCFCompareEqualTo))
	{
		fprintf(stderr, "Driver published an unexpected device UID\n");
		return 0;
	}

	theAddress.mSelector = kAudioObjectPropertyName;
	theString = NULL;
	theOutputSize = 0;
	theStatus = inInterface->GetPropertyData(
		inDriver,
		kDualSenseMicrophoneDeviceObjectID,
		0,
		&theAddress,
		0,
		NULL,
		theDataSize,
		&theOutputSize,
		&theString);
	if((theStatus != 0) ||
	   (theString == NULL) ||
	   (CFStringCompare(theString, CFSTR("DualSense Microphone"), 0) != kCFCompareEqualTo))
	{
		fprintf(stderr, "Driver published an unexpected device name\n");
		return 0;
	}

	theAddress.mSelector = kAudioDevicePropertyNominalSampleRate;
	Float64 theSampleRate = 0.0;
	theDataSize = sizeof(theSampleRate);
	theOutputSize = 0;
	theStatus = inInterface->GetPropertyData(
		inDriver,
		kDualSenseMicrophoneDeviceObjectID,
		0,
		&theAddress,
		0,
		NULL,
		theDataSize,
		&theOutputSize,
		&theSampleRate);
	if((theStatus != 0) || (theSampleRate != 48000.0))
	{
		fprintf(stderr, "Driver did not publish a 48 kHz nominal sample rate\n");
		return 0;
	}

	theAddress.mSelector = kAudioStreamPropertyVirtualFormat;
	AudioStreamBasicDescription theFormat = { 0 };
	theDataSize = sizeof(theFormat);
	theOutputSize = 0;
	theStatus = inInterface->GetPropertyData(
		inDriver,
		kDualSenseMicrophoneInputStreamObjectID,
		0,
		&theAddress,
		0,
		NULL,
		theDataSize,
		&theOutputSize,
		&theFormat);
	if((theStatus != 0) ||
	   (theFormat.mSampleRate != 48000.0) ||
	   (theFormat.mFormatID != kAudioFormatLinearPCM) ||
	   (theFormat.mChannelsPerFrame != 2) ||
	   (theFormat.mBitsPerChannel != 32) ||
	   (theFormat.mBytesPerFrame != 8) ||
	   ((theFormat.mFormatFlags & kAudioFormatFlagIsFloat) == 0))
	{
		fprintf(stderr, "Input stream format contract is incorrect\n");
		return 0;
	}

	memset(&theFormat, 0, sizeof(theFormat));
	theOutputSize = 0;
	theStatus = inInterface->GetPropertyData(
		inDriver,
		kDualSenseMicrophoneOutputStreamObjectID,
		0,
		&theAddress,
		0,
		NULL,
		theDataSize,
		&theOutputSize,
		&theFormat);
	if((theStatus != 0) ||
	   (theFormat.mSampleRate != 48000.0) ||
	   (theFormat.mChannelsPerFrame != 2) ||
	   (theFormat.mBytesPerFrame != 8))
	{
		fprintf(stderr, "Output stream format contract is incorrect\n");
		return 0;
	}

	return 1;
}

int main(int argc, const char* argv[])
{
	if(argc != 2)
	{
		fprintf(stderr, "Usage: %s /path/to/DualSenseMicrophone\n", argv[0]);
		return 64;
	}

	void* theBundle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
	if(theBundle == NULL)
	{
		fprintf(stderr, "Unable to load driver binary: %s\n", dlerror());
		return 1;
	}

	DualSenseMicrophoneFactory theFactory = (DualSenseMicrophoneFactory)dlsym(theBundle, "NullAudio_Create");
	if(theFactory == NULL)
	{
		fprintf(stderr, "Unable to find AudioServerPlugIn factory: %s\n", dlerror());
		dlclose(theBundle);
		return 1;
	}

	AudioServerPlugInDriverRef theDriver = (AudioServerPlugInDriverRef)theFactory(NULL, kAudioServerPlugInTypeUUID);
	if(theDriver == NULL)
	{
		fprintf(stderr, "Factory rejected the AudioServerPlugIn type UUID\n");
		dlclose(theBundle);
		return 1;
	}

	AudioServerPlugInDriverInterface* theInterface = *theDriver;
	if(!VerifyPublishedContract(theDriver, theInterface))
	{
		dlclose(theBundle);
		return 1;
	}

	OSStatus theStatus = theInterface->StartIO(theDriver, kDualSenseMicrophoneDeviceObjectID, 1);
	if(theStatus != 0)
	{
		fprintf(stderr, "StartIO failed: %d\n", theStatus);
		dlclose(theBundle);
		return 1;
	}

	AudioServerPlugInIOCycleInfo theCycle = { 0 };
	theCycle.mIOCycleCounter = 1;
	theCycle.mNominalIOBufferFrameSize = 4;
	theCycle.mInputTime.mFlags = kAudioTimeStampSampleTimeValid;
	theCycle.mOutputTime.mFlags = kAudioTimeStampSampleTimeValid;
	theCycle.mInputTime.mSampleTime = 16383.0;
	theCycle.mOutputTime.mSampleTime = 16383.0;

	Float32 theWrittenSamples[8] = { 0.125f, 0.125f, -0.25f, -0.25f, 0.5f, 0.5f, -0.75f, -0.75f };
	Float32 theReadSamples[8] = { 0 };
	theStatus = theInterface->DoIOOperation(
		theDriver,
		kDualSenseMicrophoneDeviceObjectID,
		kDualSenseMicrophoneOutputStreamObjectID,
		1,
		kAudioServerPlugInIOOperationWriteMix,
		4,
		&theCycle,
		theWrittenSamples,
		NULL);
	if(theStatus == 0)
	{
		theStatus = theInterface->DoIOOperation(
			theDriver,
			kDualSenseMicrophoneDeviceObjectID,
			kDualSenseMicrophoneInputStreamObjectID,
			1,
			kAudioServerPlugInIOOperationReadInput,
			4,
			&theCycle,
			theReadSamples,
			NULL);
	}
	if((theStatus != 0) || !BuffersAreEqual(theWrittenSamples, theReadSamples, 8))
	{
		fprintf(stderr, "Sample-time loopback failed across the ring boundary\n");
		theInterface->StopIO(theDriver, kDualSenseMicrophoneDeviceObjectID, 1);
		dlclose(theBundle);
		return 1;
	}

	theCycle.mIOCycleCounter = 2;
	theCycle.mInputTime.mSampleTime = 8192.0;
	memset(theReadSamples, 0x7f, sizeof(theReadSamples));
	theStatus = theInterface->DoIOOperation(
		theDriver,
		kDualSenseMicrophoneDeviceObjectID,
		kDualSenseMicrophoneInputStreamObjectID,
		1,
		kAudioServerPlugInIOOperationReadInput,
		4,
		&theCycle,
		theReadSamples,
		NULL);
	if((theStatus != 0) || !BufferIsSilent(theReadSamples, 8))
	{
		fprintf(stderr, "Unwritten frames did not return silence\n");
		theInterface->StopIO(theDriver, kDualSenseMicrophoneDeviceObjectID, 1);
		dlclose(theBundle);
		return 1;
	}

	theStatus = theInterface->StopIO(theDriver, kDualSenseMicrophoneDeviceObjectID, 1);
	dlclose(theBundle);
	if(theStatus != 0)
	{
		fprintf(stderr, "StopIO failed: %d\n", theStatus);
		return 1;
	}

	puts("Loopback smoke test passed");
	return 0;
}
