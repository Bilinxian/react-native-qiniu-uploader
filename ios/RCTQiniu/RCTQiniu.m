#import "RCTQiniu.h"

@interface RCTQiniu()

@property QNUploadManager *upManager;
@property NSString *taskId;
@property NSString *filePath;
@property NSString *upKey;
@property NSString *upToken;
@property BOOL isTaskPause;
@property BOOL hasListener;

@end

@implementation RCTQiniu

- (instancetype)init
{
    self = [super init];
    if (self) {
        kQNGlobalConfiguration.isDnsOpen = YES;
        kQNGlobalConfiguration.connectCheckEnable = YES;
        kQNGlobalConfiguration.udpDnsEnable = YES;
        kQNGlobalConfiguration.udpDnsIpv4Servers = @[@"223.5.5.5",@"119.29.29.29", @"114.114.114.114", @"180.76.76.76", @"8.8.8.8"];
        kQNGlobalConfiguration.dohEnable = NO;

    }
    return self;
}

RCT_EXPORT_MODULE();

- (void)startObserving
{
    _hasListener = YES;
}

- (void)stopObserving
{
    _hasListener = NO;
}

#pragma mark start upload file
RCT_EXPORT_METHOD(startTask:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    self.taskId = options[@"id"];
    self.filePath = options[@"filePath"];
    self.upKey = options[@"upKey"];
    self.upToken = options[@"upToken"];
    NSNumber *isAsyncTask = options[@"isAsyncTask"];
    self.upManager = [[QNUploadManager alloc] initWithConfiguration:[self config]];
    if ([self checkParams]) {
        if (1 == [isAsyncTask intValue]) {
            [self uploadTask:resolve rejecter:reject];
        }
        else {
            [self uploadTask:nil rejecter: nil];
            resolve(@"");
        }

    }
}

#pragma mark resume upload task
RCT_EXPORT_METHOD(resumeTask) {
  self.isTaskPause = NO;
  [self uploadTask:nil rejecter:nil];
}

#pragma mark pause upload task
RCT_EXPORT_METHOD(pauseTask) {
  self.isTaskPause = YES;
}

/**
 * zoneTarget:华东1,华北2,华南3,北美4
 */
- (QNConfiguration *)config {
    QNConfiguration *config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        //设置断点续传
        NSError *error;
        builder.recorder =  [QNFileRecorder fileRecorderWithFolder:[NSTemporaryDirectory() stringByAppendingString:kCacheFolder] error:&error];
        builder.zone = [QNAutoZone new];
        builder.chunkSize = 512 * 1024;
        builder.timeoutInterval = 120;
        builder.useConcurrentResumeUpload = YES;
        builder.putThreshold = 512 * 1024;
        builder.resumeUploadVersion = QNResumeUploadVersionV2;

    }];
    return config;
}

- (BOOL)checkParams {

  BOOL pass = YES;
  NSString *msg = @"";

  if (nil == self.filePath || [self.filePath isEqual:[NSNull null]]) {
    msg = @"filePath can not be nil";
    pass = NO;
  } else if (nil == self.upKey || [self.upKey isEqual:[NSNull null]]) {
    msg = @"upKey can not be nil";
    pass = NO;
  } else if (nil == self.upToken || [self.upToken isEqual:[NSNull null]]) {
    msg = @"upToken can not be nil";
    pass = NO;
  }

  if (!pass) {
    [self commentEvent:onError code:kFail msg:msg];
  }

  if (pass && [self.filePath hasPrefix:@"file://"])
    self.filePath = [self.filePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];

  return pass;
}

- (void)uploadTask:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {

  __weak typeof(self) weakSelf = self;

  QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil
                                                      progressHandler:^(NSString *key, float percent) {
                                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                                        NSString *per =[NSString stringWithFormat:@"%.2f", percent];
                                                        [strongSelf commentEvent:onProgress code:kSuccess msg:key percent:per];
                                                      }
                                                               params:nil
                                                             checkCrc:NO
                                                   cancellationSignal:^BOOL() {
                                                     __strong typeof(weakSelf) strongSelf = weakSelf;
                                                     return strongSelf.isTaskPause;
                                                   }];
  [self.upManager putFile:self.filePath key:self.upKey token:self.upToken complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
    if (info.isOK) {
        if (resolve) {
            resolve(@"上传成功");
        } else {
            [self commentEvent:onComplete code:kSuccess msg:@"上传成功"];
        }

    } else {
      NSString *errorStr = @"";
      for (NSString *key in info.error.userInfo) {
        [errorStr stringByAppendingString:key];
      }
        if (reject) {
            reject([NSString stringWithFormat:@"%d", info.statusCode], errorStr, nil);
        } else {
            [self commentEvent:onError code:info.statusCode msg:errorStr];
        }

    }
  }
                   option:uploadOption];
}

#pragma mark - native to js event method
- (NSArray<NSString *> *)supportedEvents {
    return @[qiniuEvent];
}

- (void)commentEvent:(NSString *)type code:(int)code msg:(NSString *)msg {
  [self commentEvent:type code:code msg:msg percent:@""];
}

- (void)commentEvent:(NSString *)type code:(int)code msg:(NSString *)msg percent:(NSString *)percent {
  NSMutableDictionary *params = @{}.mutableCopy;
  params[kType] = type;
  params[kCode] = [NSString stringWithFormat:@"%d", code];
  params[kMsg] = msg;
  params[kTaskId] = self.taskId;
  params[kPercent] = percent;
  NSLog(@"返回commentEvent%@", params );
  if (_hasListener) {
      [self sendEventWithName:qiniuEvent body:params];
  }

}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end
