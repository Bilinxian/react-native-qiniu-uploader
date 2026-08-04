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
    self.hasListener = YES;
}

- (void)stopObserving
{
    // 仅停止向 JS 发事件；勿取消进行中的上传（eventEmitter 重绑会触发 stopObserving）
    self.hasListener = NO;
}

- (void)invalidate
{
    self.hasListener = NO;
    [self pauseAllTasksAndClear];
    [super invalidate];
}

/** 暂停并清空全部任务，促使 cancellationSignal 尽快结束上传 */
- (void)pauseAllTasksAndClear
{
    NSArray<UploadTask *> *tasks;
    @synchronized (self) {
        tasks = [self.taskMap.allValues copy];
        [self.taskMap removeAllObjects];
    }
    for (UploadTask *task in tasks) {
        task.isPaused = YES;
    }
}

#pragma mark start upload file
RCT_EXPORT_METHOD(startTask:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    NSString *taskId = options[@"id"];
    NSString *filePath = options[@"filePath"];
    NSString *upKey = options[@"upKey"];
    NSString *upToken = options[@"upToken"];
    NSNumber *isAsyncTask = options[@"isAsyncTask"] ?: @0;

    UploadTask *task = [[UploadTask alloc] initWithId:taskId filePath:filePath upKey:upKey upToken:upToken];
    @synchronized (self) {
        self.taskMap[taskId] = task;
    }

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
    UploadTask *task = nil;
    @synchronized (self) {
        task = self.taskMap[taskId];
    }
    if (task) {
        task.isPaused = NO;
        [self uploadTask:task resolve:nil rejecter:nil];
    }
}

#pragma mark pause upload task
RCT_EXPORT_METHOD(pauseTask:(NSString *)taskId) {
    UploadTask *task = nil;
    @synchronized (self) {
        task = self.taskMap[taskId];
    }
    if (task) {
        task.isPaused = YES;
    }
}

#pragma mark remove upload task
RCT_EXPORT_METHOD(removeTask:(NSString *)taskId) {
    @synchronized (self) {
        UploadTask *task = self.taskMap[taskId];
        if (task) {
            task.isPaused = YES;
        }
        [self.taskMap removeObjectForKey:taskId];
    }
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
        // 保留并发分片（视频上传需要）；进度回调已切主线程并做空判（WSB-1NH）
        builder.useConcurrentResumeUpload = YES;
        builder.concurrentTaskCount = 3;
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
        // 并发分片回调可能不在主线程，统一派发并做空判，避免 UAF（WSB-1NH）
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            __strong UploadTask *strongTask = weakTask;
            if (!strongSelf || !strongTask || !strongSelf.hasListener || strongTask.isPaused) {
                return;
            }
            NSString *per = [NSString stringWithFormat:@"%.2f", percent];
            [strongSelf commentEvent:onProgress taskId:strongTask.taskId code:kSuccess msg:key ?: @"" percent:per];
        });
    }
                                                               params:nil
                                                             checkCrc:NO
                                                   cancellationSignal:^BOOL() {
        __strong UploadTask *strongTask = weakTask;
        return strongTask == nil || strongTask.isPaused;
    }];

    if (!self.upManager) {
        self.upManager = [[QNUploadManager alloc] initWithConfiguration:[self config]];
    }

    [self.upManager putFile:task.filePath key:task.upKey token:task.upToken complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        // complete 同样可能在后台线程，与 progress 一致切主线程再碰 RN/bridge（WSB-1NH）
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            __strong UploadTask *strongTask = weakTask;
            if (!strongSelf || !strongTask) {
                return;
            }

            NSString *taskId = strongTask.taskId;
            if (info.isOK) {
                if (resolve) {
                    resolve(@"上传成功");
                } else if (strongSelf.hasListener && taskId) {
                    [strongSelf commentEvent:onComplete taskId:taskId code:kSuccess msg:@"上传成功" percent:@""];
                }
            } else {
                NSString *errorStr = info.error ? info.error.localizedDescription : @"未知错误";
                if (reject) {
                    reject([NSString stringWithFormat:@"%d", info.statusCode], errorStr, nil);
                } else if (strongSelf.hasListener && taskId) {
                    [strongSelf commentEvent:onError taskId:taskId code:info.statusCode msg:errorStr percent:@""];
                }
            }

            if (taskId) {
                @synchronized (strongSelf) {
                    [strongSelf.taskMap removeObjectForKey:taskId];
                }
            }
        });
    } option:uploadOption];
}

#pragma mark - native to js event method
- (NSArray<NSString *> *)supportedEvents {
    return @[qiniuEvent];
}

- (void)commentEvent:(NSString *)type taskId:(NSString *)taskId code:(int)code msg:(NSString *)msg percent:(NSString *)percent {
    if (!self.hasListener || taskId.length == 0) {
        return;
    }
    NSMutableDictionary *params = @{}.mutableCopy;
    params[kType] = type ?: @"";
    params[kCode] = [NSString stringWithFormat:@"%d", code];
    params[kMsg] = msg ?: @"";
    params[kTaskId] = taskId;
    params[kPercent] = percent ?: @"";

    [self sendEventWithName:qiniuEvent body:params];
}

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end
