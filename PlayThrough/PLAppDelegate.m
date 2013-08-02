//
//  PLAppDelegate.m
//  PlayThrough
//
//  Created by aa on 5/4/13.
//  Copyright (c) 2013 aa. All rights reserved.
//

#import "PLAppDelegate.h"

@implementation PLAppDelegate

#define sineFreq 880.0

#pragma mark - synthesizes
// 10.18

@synthesize window = _window;
@synthesize effectState = _effectState;
@synthesize mySineWavePlayer = _mySineWavePlayer;

@synthesize audiobusController = _audiobusController;
@synthesize audiobusAudioUnitWrapper = _audiobusAudioUnitWrapper;

@synthesize outputPort = _outputPort;


// testing git one two three four five


#pragma mark helpers
// 4.2
// generic error handler - if error is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	
	char errorString[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(errorString, "%d", (int)error);
	
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
	
	exit(1);
}


// 10.28 - 10.30

static OSStatus InputModulatingRenderCallback(void* inRefCon,
                                              AudioUnitRenderActionFlags* ioActionFlags,
                                              const AudioTimeStamp* inTimeStamp,
                                              UInt32 inBusNumber,
                                              UInt32 inNumberFrames,
                                              AudioBufferList* ioData) {
  
  
  EffectState* effectState = (EffectState*) inRefCon;
  PLAppDelegate* appPointer = (__bridge PLAppDelegate*)effectState->appPointer;
  UInt32 bus1 = 1;
  AudioUnitRender(effectState->rioUnit, ioActionFlags, inTimeStamp, bus1, inNumberFrames, ioData);
  AudioSampleType sample = 0;
  UInt32 bytesPerChannel = effectState->asbd.mBytesPerFrame / effectState->asbd.mChannelsPerFrame;
  for(int bufCount = 0; bufCount < ioData->mNumberBuffers; bufCount++) {
    AudioBuffer buf = ioData->mBuffers[bufCount];
    NSLog(@"mNumberBuffers:%i inNumberFrames:%i mNumberChannels:%i", (unsigned int)ioData->mNumberBuffers, (unsigned int)inNumberFrames, (unsigned int)buf.mNumberChannels);
    int currentFrame = 0;
    while (currentFrame < inNumberFrames) {
      // copy sample to buffer across all channels
      //NSLog(@"buf.mNumberChannels is %i", buf.mNumberChannels);
      for(int currentChannel = 0; currentChannel < buf.mNumberChannels; currentChannel++) {
        memcpy(&sample, buf.mData +
               (currentFrame * effectState->asbd.mBytesPerFrame) +
               (currentChannel * bytesPerChannel),
               sizeof(AudioSampleType));
        float theta = effectState->sinePhase * M_PI * 2;
        sample = (sin(theta) * sample);
        sample = (arc4random() % 10000);
        memcpy(buf.mData +
               (currentFrame * effectState->asbd.mBytesPerFrame) +
               (currentChannel * bytesPerChannel), &sample, sizeof(AudioSampleType));
        
        effectState->sinePhase += 1.0 / (effectState->asbd.mSampleRate / effectState->sineFrequency);
        if(effectState->sinePhase > 1.0) {
          effectState->sinePhase -= 1.0;
        };
      };
      currentFrame++;
    };
  };
  
  ABOutputPortSendAudio(appPointer.outputPort, ioData, inNumberFrames, inTimeStamp, NULL);
  if ( ABOutputPortGetConnectedPortAttributes(appPointer.outputPort) & ABInputPortAttributePlaysLiveAudio ) {
    // Mute your audio output if the connected port plays it for us instead
    for ( int i=0; i<ioData->mNumberBuffers; i++ ) {
      memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
    }
  }
  
  return noErr;
}

#pragma mark callbacks
// 10.27

static void MyInterruptionListener(void* inUserData, UInt32 inInterruptionState) {
  printf("interrupted - state is %ld\n", inInterruptionState);
  PLAppDelegate* appDelegate = (__bridge PLAppDelegate*)inUserData;
  switch (inInterruptionState) {
    case kAudioSessionBeginInterruption:
      
      break;
      
    case kAudioSessionEndInterruption:
      AudioSessionSetActive(true);
      AudioUnitInitialize(appDelegate.effectState.rioUnit);
      AudioOutputUnitStart(appDelegate.effectState.rioUnit);
      break;
      
    default:
      break;
  }
}

#pragma mark app lifecycle



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  
  // setup audio session
  // 10.19
  AudioSessionInitialize(NULL, kCFRunLoopDefaultMode, MyInterruptionListener, (__bridge void *)(self));
  UInt32 category = kAudioSessionCategory_PlayAndRecord;
  AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
  
  UInt32 allowMixing = YES;
  AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
  
  /*
   MTM2NjU2NjQ1NSoqKlBsYXlUaHJvdWdoKioqcGxheXRocm91Z2guYXVkaW9idXM6Ly8=:Eq2GFDU6rX9FL64rqbtW6dWOirU5C7tH2yTdBLvwmm0d8H1jD9vWb3/vDPWLmTVRhqIU0Xfy56fFcyFlBRW1f+MwuDPaduKi8+tMVc8kZtxVem8E9dr/xGW8xMl2cLxc
   */
  

  // is audio in available?
  // 10.20
  
  UInt32 ui32PropertySize = sizeof(UInt32);
  UInt32 inputAvailable;
  AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &ui32PropertySize, &inputAvailable);
  
  if(!inputAvailable) {
    NSLog(@"itz fukd");
    NSAssert(2 == 4, @"fukd");
  };
  
  // get hw sample rate
  // 10.21
  
  Float64 hardwareSampleRate;
  UInt32 propSize = sizeof(hardwareSampleRate);
  AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &propSize, &hardwareSampleRate);
  
  // get rio unit from audio component manager
  // 10.22
  
  AudioComponentDescription audioCompDesc;
  audioCompDesc.componentType = kAudioUnitType_Output;
  audioCompDesc.componentSubType = kAudioUnitSubType_RemoteIO;
  audioCompDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
  audioCompDesc.componentFlags = 0;
  audioCompDesc.componentFlagsMask = 0;
  
  // get the rio unit from the audio component manager
  AudioComponent rioComponent = AudioComponentFindNext(NULL, &audioCompDesc);
  AudioComponentInstanceNew(rioComponent, &_effectState.rioUnit);
  
  // configure rio unit
  // 10.23 - 10.24
  
  UInt32 oneFlag = 1;
  AudioUnitElement bus0 = 0;
  AudioUnitSetProperty(_effectState.rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, bus0, &oneFlag, sizeof(oneFlag));
  
  AudioUnitElement bus1 = 1;
  AudioUnitSetProperty(_effectState.rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, bus1, &oneFlag, sizeof(oneFlag));
  
  // setup asbd in iphone conanical format
  AudioStreamBasicDescription myASBD;
  memset(&myASBD, 0, sizeof(myASBD));
  myASBD.mSampleRate = hardwareSampleRate;
  myASBD.mFormatID = kAudioFormatLinearPCM;
  myASBD.mFormatFlags = kAudioFormatFlagsCanonical;
  myASBD.mBytesPerPacket = 4;
  myASBD.mFramesPerPacket = 1;
  myASBD.mBytesPerFrame = 4;
  myASBD.mChannelsPerFrame = 2;
  myASBD.mBitsPerChannel = 16;
  
  // set format for output bus 0 on rios input scope
  AudioUnitSetProperty(_effectState.rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus0, &myASBD, sizeof(myASBD));
  
  // SET ASBD FOR MIC INPUT BUS 1 ON rios output scope
  AudioUnitSetProperty(_effectState.rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, &myASBD, sizeof(myASBD));
  
  self.audiobusController = [[ABAudiobusController alloc]
                             initWithAppLaunchURL:[NSURL URLWithString:@"playthrough.audiobus://"]
                             apiKey:@"MTM2NjU2NjQ1NSoqKlBsYXlUaHJvdWdoKioqcGxheXRocm91Z2guYXVkaW9idXM6Ly8=:Eq2GFDU6rX9FL64rqbtW6dWOirU5C7tH2yTdBLvwmm0d8H1jD9vWb3/vDPWLmTVRhqIU0Xfy56fFcyFlBRW1f+MwuDPaduKi8+tMVc8kZtxVem8E9dr/xGW8xMl2cLxc"];
  
  self.audiobusController.connectionPanelPosition = ABAudiobusConnectionPanelPositionLeft;
//
//  ABOutputPort *output = [self.audiobusController addOutputPortNamed:@"Audio Output"
//                                                               title:NSLocalizedString(@"Main App Output", @"")];
//  
//  self.audiobusAudioUnitWrapper = [[ABAudiobusAudioUnitWrapper alloc]
//                                   initWithAudiobusController:self.audiobusController
//                                   audioUnit: _effectState.rioUnit
//                                   output:output
//                                   input: nil];
  
  self.outputPort = [self.audiobusController addOutputPortNamed:@"Main" title:@"Main Output"];
  self.outputPort.clientFormat = myASBD;
  
  // set callback method
  // 10.25
  _effectState.asbd = myASBD;
  _effectState.sineFrequency = 300;
  _effectState.sinePhase = 0;
  _effectState.appPointer = (__bridge void*)self;
  
  AURenderCallbackStruct callbackStruct;
  callbackStruct.inputProc = InputModulatingRenderCallback;
  callbackStruct.inputProcRefCon = &_effectState;
  
  AudioUnitSetProperty(_effectState.rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, bus0, &callbackStruct, sizeof(callbackStruct));
  
  // start rio unit
  // replace to bottom with 10.26
  
  // init and start rio unit
  AudioUnitInitialize(_effectState.rioUnit);
  AudioOutputUnitStart(_effectState.rioUnit);
  
  
  
  
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
