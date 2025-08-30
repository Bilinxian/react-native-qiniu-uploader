#import "RCTQiniu.h"

@interface UploadTask : NSObject

@property (nonatomic, copy) NSString *taskId;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *upKey;
@property (nonatomic, copy) NSString *upToken;
@property (nonatomic, assign) BOOL isPaused;

- (instancetype)initWithId:(NSString *)taskId filePath:(NSString *)filePath upKey:(NSString *)upKey upToken:(NSString *)upToken;

@end

@implementation UploadTask

- (instancetype)initWithId:(NSString *)taskId filePath:(NSString *)filePath upKey:(NSString *)upKey upToken:(NSString *)upToken {
    self = [super init];
    if (self) {
        _taskId = taskId;
        _filePath = filePath;
        _upKey = upKey;
        _upToken = upToken;
        _isPaused = NO;
    }
    return self;
}

@end

@interface RCTQiniu()

@property (nonatomic, strong) QNUploadManager *upManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UploadTask *> *taskMap;
@property (nonatomic, assign) BOOL hasListener;

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
        _taskMap = [NSMutableDictionary dictionary];
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
    NSString *taskId = options[@"id"];
    NSString *filePath = options[@"filePath"];
    NSString *upKey = options[@"upKey"];
    NSString *upToken = options[@"upToken"];
    NSNumber *isAsyncTask = options[@"isAsyncTask"] ?: @0;

    UploadTask *task = [[UploadTask alloc] initWithId:taskId filePath:filePath upKey:upKey upToken:upToken];
    self.taskMap[taskId] = task;

    if ([self checkParams:task]) {
        if ([isAsyncTask intValue] == 1) {
            [self uploadTask:task resolve:resolve rejecter:reject];
        } else {
            [self uploadTask:task resolve:nil rejecter:nil];
            resolve(@"");
        }
    } else {
        reject(@"PARAMS_ERROR", @"参数校验失败", nil);
    }
}

#pragma mark resume upload task
RCT_EXPORT_METHOD(resumeTask:(NSString *)taskId) {
    UploadTask *task = self.taskMap[taskId];
    if (task) {
        task.isPaused = NO;
        [self uploadTask:task resolve:nil rejecter:nil];
    }
}

#pragma mark pause upload task
RCT_EXPORT_METHOD(pauseTask:(NSString *)taskId) {
    UploadTask *task = self.taskMap[taskId];
    if (task) {
        task.isPaused = YES;
    }
}

#pragma mark remove upload task
RCT_EXPORT_METHOD(removeTask:(NSString *)taskId) {
    [self.taskMap removeObjectForKey:taskId];
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

- (BOOL)checkParams:(UploadTask *)task {
    BOOL pass = YES;
    NSString *msg = @"";

    if (nil == task.filePath || [task.filePath isEqual:[NSNull null]]) {
        msg = @"filePath can not be nil";
        pass = NO;
    } else if (nil == task.upKey || [task.upKey isEqual:[NSNull null]]) {
        msg = @"upKey can not be nil";
        pass = NO;
    } else if (nil == task.upToken || [task.upToken isEqual:[NSNull null]]) {
        msg = @"upToken can not be nil";
        pass = NO;
    }

    if (!pass) {
        [self commentEvent:onError taskId:task.taskId code:kFail msg:msg percent:@""];
    }

    if (pass && [task.filePath hasPrefix:@"file://"]) {
        task.filePath = [task.filePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    }

    return pass;
}

- (void)uploadTask:(UploadTask *)task resolve:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    __weak typeof(self) weakSelf = self;
    __weak UploadTask *weakTask = task;

    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil
                                                      progressHandler:^(NSString *key, float percent) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong UploadTask *strongTask = weakTask;
        NSString *per = [NSString stringWithFormat:@"%.2f", percent];
        [strongSelf commentEvent:onProgress taskId:strongTask.taskId code:kSuccess msg:key percent:per];
    }
                                                               params:nil
                                                             checkCrc:NO
                                                   cancellationSignal:^BOOL() {
        __strong UploadTask *strongTask = weakTask;
        return strongTask.isPaused;
    }];

    if (!self.upManager) {
        self.upManager = [[QNUploadManager alloc] initWithConfiguration:[self config]];
    }

    [self.upManager putFile:task.filePath key:task.upKey token:task.upToken complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong UploadTask *strongTask = weakTask;

        if (info.isOK) {
            if (resolve) {
                resolve(@"上传成功");
            } else {
                [strongSelf commentEvent:onComplete taskId:strongTask.taskId code:kSuccess msg:@"上传成功" percent:@""];
            }
        } else {
            NSString *errorStr = info.error ? info.error.localizedDescription : @"未知错误";
            if (reject) {
                reject([NSString stringWithFormat:@"%d", info.statusCode], errorStr, nil);
            } else {
                [strongSelf commentEvent:onError taskId:strongTask.taskId code:info.statusCode msg:errorStr percent:@""];
            }
        }

        // 上传完成后移除任务（可选）
        [strongSelf.taskMap removeObjectForKey:strongTask.taskId];
    } option:uploadOption];
}

#pragma mark - native to js event method
- (NSArray<NSString *> *)supportedEvents {
    return @[qiniuEvent];
}

- (void)commentEvent:(NSString *)type taskId:(NSString *)taskId code:(int)code msg:(NSString *)msg percent:(NSString *)percent {
    NSMutableDictionary *params = @{}.mutableCopy;
    params[kType] = type;
    params[kCode] = [NSString stringWithFormat:@"%d", code];
    params[kMsg] = msg;
    params[kTaskId] = taskId;
    params[kPercent] = percent;

    NSLog(@"返回commentEvent: %@", params);

    if (_hasListener) {
        [self sendEventWithName:qiniuEvent body:params];
    }
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end
