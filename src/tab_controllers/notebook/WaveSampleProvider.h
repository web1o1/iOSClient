//
//  WaveSampleProvider.h
//  CoreAudioTest
//
//  Created by Gyetván András on 6/22/12.
//  Copyright (c) 2012 DroidZONE. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

@class WaveSampleProvider;

@protocol WaveSampleProviderDelegate <NSObject>
- (void) sampleProcessed:(WaveSampleProvider *)provider;
- (void) statusUpdated:(WaveSampleProvider *)provider;
- (void) setAudioLength:(float)seconds;
@end

typedef enum {
	LOADING,
	LOADED,
	ERROR
} WaveSampleStatus;

@interface WaveSampleProvider : NSObject 
{
	ExtAudioFileRef extAFRef;
	Float64 extAFRateRatio;
	int extAFNumChannels;
	BOOL extAFReachedEOF;
	NSString *_path;
	WaveSampleStatus status;
	NSString *statusMessage;
	NSMutableArray *sampleData;
	NSMutableArray *normalizedData;
	int binSize;
	//int lengthInSec;
	int minute;
	int sec;
	NSURL *audioURL;
	NSString *title;
    float **maximumAudioSamples;
}

@property (readonly, nonatomic) WaveSampleStatus status;
@property (readonly, nonatomic) NSString *statusMessage;
@property (readonly, nonatomic) NSURL *audioURL;
@property (assign, nonatomic) int binSize;
@property (assign, nonatomic) int minute;
@property (assign, nonatomic) int sec;
@property (readonly) NSString *title;

- (id) initWithURL:(NSURL *)u delegate:(id<WaveSampleProviderDelegate>)d;
- (void) createSampleData;
- (float *)dataForResolution:(int)pixelWide lenght:(int *)length;

@end
