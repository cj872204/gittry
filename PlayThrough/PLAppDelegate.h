//
//  PLAppDelegate.h
//  PlayThrough
//
//  Created by aa on 5/4/13.
//  Copyright (c) 2013 aa. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Audiobus.h"

typedef struct {
  AudioUnit rioUnit;
  AudioStreamBasicDescription asbd;
  float sineFrequency;
  float sinePhase;
  void* appPointer;
} EffectState;

typedef struct MySineWavePlayer {
  AudioUnit outputUnit;
  double startingFrameCount;
} MySineWavePlayer;

@interface PLAppDelegate : UIResponder <UIApplicationDelegate> {
  
  ABOutputPort* outputPort;
}

@property (strong, nonatomic) UIWindow *window;
@property (assign) EffectState effectState;
@property (assign) MySineWavePlayer mySineWavePlayer;

@property (strong, nonatomic) ABAudiobusController *audiobusController;
@property (strong, nonatomic) ABAudiobusAudioUnitWrapper *audiobusAudioUnitWrapper;
@property (strong, nonatomic) ABOutputPort* outputPort;

@end
