//
//  AUManager.m
//  ZDAudio
//
//  Created by 吕浩轩 on 2021/5/12.
//

#import "AUManager.h"
#import <AVFoundation/AVFoundation.h>
#import <libextobjc/extobjc.h>

@interface AUManager () <AVAudioRecorderDelegate>

@property (nonatomic, weak) id<AUManagerDelegate> delegate;

@property (nonatomic, copy) Progress progress;
@property (nonatomic, copy) Level level;

/* ------- 播放 ------- */
@property (nonatomic) AVPlayer *audioPlayer;

@property (nonatomic) id audioPlayerObserver;

@property (nonatomic) CMTime audioPlayerTotalTime;


/* ------- 录音 ------- */
@property (nonatomic) AVAudioRecorder *recorder;

@property (nonatomic) NSMutableDictionary *recordSetting;

@property (nonatomic) NSTimer *levelTimer;

@property (nonatomic, copy) NSString *savePath;

@end

@implementation AUManager

@synthesize totalTime = _totalTime;
@synthesize currentTime = _currentTime;

static id _instance = nil;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
    });
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone { return [self shared]; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)mutableCopyWithZone:(NSZone *)zone { return self; }

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegate = (id)self.multiDelegate;
    }
    return self;
}

#pragma mark -
+ (NSTimeInterval)getTotalTimeWithUrl:(NSURL *)url {
    CMTime time = [self durationTimeWithUrl:url];
    return [self getSeconds:time];
}

+ (CMTime)durationTimeWithUrl:(NSURL *)url {
    AVAsset *asset = [AVAsset assetWithURL:url];
    if (!asset) {
        return kCMTimeZero;
    }
    return asset.duration;
}

+ (NSTimeInterval)getSeconds:(CMTime)time {
    NSTimeInterval sec = CMTimeGetSeconds(time);
    if (isnan(sec)) {
        return 0;
    }
    return sec;
}

#pragma mark -
- (void)play:(NSURL *)url {
    [self play:url progress:nil];
}

- (void)play:(NSURL *)url progress:(nullable Progress)progress {
    
    if (_audioPlayer && [_urlStr isEqualTo:url.absoluteString]) {
        [_audioPlayer play];
        return;
    }
    
    _audioPlayerTotalTime = [[self class] durationTimeWithUrl:url];
    
    NSTimeInterval totalTime = CMTimeGetSeconds(_audioPlayerTotalTime);
    if (isnan(totalTime)) {
        totalTime = 0;
    }

    if (progress && totalTime != 0) {
        progress(totalTime, 0);
    }
    
    if (_progress != progress) {
        _progress = progress;
    }
    
    [self stopPaly];
    
    if (!_audioPlayer) {
        _urlStr = url.absoluteString;
        _audioPlayer = [AVPlayer playerWithURL:url];
        _audioPlayer.volume = 1.0f;
        
        //监控状态属性，注意AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态
        [_audioPlayer.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        
        //监控播放完成通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopPaly) name:AVPlayerItemDidPlayToEndTimeNotification object:_audioPlayer.currentItem];
        
        //监控时间进度
        @weakify(self);
        _audioPlayerObserver = [_audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 3) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            @strongify(self);
            
            if (self.playerStatus != PlayerStatus_Playing) {
                self->_playerStatus = PlayerStatus_Playing;
                if ([self.delegate respondsToSelector:@selector(callbackPlayerStatus:)]) {
                    [self.delegate callbackPlayerStatus:self.playerStatus];
                }
            }
                            
            if (self.progress) {
                self.progress([self totalTime], [self currentTime]);
            }
            
            if ([self.delegate respondsToSelector:@selector(callbackTime:currentTime:)]) {
                [self.delegate callbackTime:[self totalTime] currentTime:[self currentTime]];
            }
        }];
    }
}

/// 获取播放状态
- (BOOL)isPlaying {
    return self.playerStatus == PlayerStatus_Playing;
}

/// 跳转到指定时间
/// @param time 指定的时间
- (void)seekToTime:(NSTimeInterval)time {
    if (!_audioPlayer) {
        return;
    }
    
    [_audioPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) toleranceBefore:CMTimeMake(1, NSEC_PER_SEC) toleranceAfter:CMTimeMake(1, NSEC_PER_SEC)];
}

/// 暂停播放
- (void)pausePaly {
    
    _playerStatus = PlayerStatus_Pause;
    
    if (!_audioPlayer) {
        return;
    }
    
    [_audioPlayer pause];
}

/// 继续播放
- (void)resumePaly {
    if (!_audioPlayer) {
        return;
    }

    [_audioPlayer play];
}

/// 停止播放
- (void)stopPaly {

    _audioPlayerTotalTime = kCMTimeZero;
    _playerStatus = PlayerStatus_Stop;
    
    if (!_audioPlayer) {
        return;
    }
    
    if (self.progress) {
        self.progress([self totalTime], [self currentTime]);
    }
    
    if ([self.delegate respondsToSelector:@selector(callbackTime:currentTime:)]) {
        [self.delegate callbackTime:[self totalTime] currentTime:[self currentTime]];
    }
    
    if ([self.delegate respondsToSelector:@selector(callbackPlayerStatus:)]) {
        [self.delegate callbackPlayerStatus:PlayerStatus_Stop];
    }
    
    if (_audioPlayer && _audioPlayerObserver) {
        [_audioPlayer removeTimeObserver:_audioPlayerObserver];
    }
    
    if (_audioPlayer) {
        [_audioPlayer pause];
        [_audioPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_audioPlayer.currentItem];
        _audioPlayer = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"] && object == _audioPlayer.currentItem) {
        AVPlayerItemStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerItemStatusReadyToPlay) {
            [_audioPlayer play];
        } else if (status == AVPlayerItemStatusUnknown) {
            NSLog(@"AVPlayerItemStatusUnknown");
        } else if (status == AVPlayerItemStatusFailed) {
            NSLog(@"AVPlayerItemStatusFailed");
        }
    }
}

- (NSTimeInterval)totalTime {
    if (!_audioPlayer) {
        return 0;
    }
    
    CMTime totalTime;
    if (_audioPlayerTotalTime.value != 0 && _audioPlayerTotalTime.timescale != 0) {
        totalTime = _audioPlayerTotalTime;
    } else {
        totalTime = _audioPlayer.currentItem.duration;
    }

    return [[self class] getSeconds:totalTime];
}

- (NSTimeInterval)currentTime {
    if (!_audioPlayer) {
        return 0;
    }

    return [[self class] getSeconds:_audioPlayer.currentItem.currentTime];
}

/*  录音  */
- (void)recordWithSavePath:(NSString *)path callback:(nullable Level)callback {

    if (path && [_savePath isEqualToString:path]) {
        return;
    }
    
    if ([path hasPrefix:@"~"]) {
        NSString *usersPath = [NSString stringWithFormat:@"/Users/%@", NSUserName()];
        path = [path stringByReplacingOccurrencesOfString:@"~" withString:usersPath];
    }
    
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path.stringByDeletingLastPathComponent isDirectory:&isDirectory] || !isDirectory) {
        NSError *er;
        [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&er];
        if (er) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:404 userInfo:@{@"msg" : @"录音路径异常！"}];
            callback(0, error);
            return;
        }
    }
    
    _level = callback;
    
    [self stopRecord];
    
    NSError *error;
    _recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:self.recordSetting error:&error];
    
    if (!error) {
        _recorder.meteringEnabled = YES;
        _recorder.delegate = self;
        [_recorder prepareToRecord];
        [_recorder record];
        @weakify(self)
        self.levelTimer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            @strongify(self);
            [self.recorder updateMeters];
            
            float   level;
            float   minDecibels = -60.0f;
            float   decibels    = [self.recorder averagePowerForChannel:0];

            if (decibels < minDecibels) {
                level = 0.0f;
            } else if (decibels >= 0.0f) {
                level = 1.0f;
            } else {
                float   root            = 2.0f;
                float   minAmp          = powf(10.0f, 0.05f * minDecibels);
                float   inverseAmpRange = 1.0f / (1.0f - minAmp);
                float   amp             = powf(10.0f, 0.05f * decibels);
                float   adjAmp          = (amp - minAmp) * inverseAmpRange;
                
                level = powf(adjAmp, 1.0f / root);
            }
            
            if (self.level) {
                self.level(level * 120., error);
            }
        }];
        
        [[NSRunLoop mainRunLoop] addTimer:self.levelTimer forMode:NSRunLoopCommonModes];
    }
    
    if (_level) {
        _level(0.0, error);
    }
}

- (void)stopRecord {
    if (_recorder) {
        [_recorder stop];
        _recorder = nil;
    }
}

#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {

    // 关闭计时器
    [_levelTimer invalidate];
    _levelTimer = nil;
    
    if ([self.delegate respondsToSelector:@selector(recorderDidFinishSuccessfully:)]) {
        [self.delegate recorderDidFinishSuccessfully:flag];
    }
    
    // 未正常结束，删除文件
    if (!flag) {
        if ([_recorder deleteRecording]) {
            NSLog(@"录音文件删除成功");
        } else {
            NSLog(@"录音文件删除失败");
        }
    }
}

// 项目要求，固定参数
- (NSMutableDictionary *)recordSetting {
    NSMutableDictionary *recordSetting = [NSMutableDictionary dictionary];
    [recordSetting setValue:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [recordSetting setValue:@(AVAudioQualityHigh) forKey:AVEncoderAudioQualityKey];
    [recordSetting setValue:@96000 forKey:AVEncoderBitRateKey];
    [recordSetting setValue:@16000 forKey:AVSampleRateKey];
    [recordSetting setValue:@16 forKey:AVLinearPCMBitDepthKey];
    [recordSetting setValue:@1 forKey:AVNumberOfChannelsKey];
    
    return [recordSetting copy];
}

- (void)dealloc {
    if (_audioPlayer) {
        [_audioPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_audioPlayer.currentItem];
        
        if (_audioPlayerObserver) {
            [_audioPlayer removeTimeObserver:_audioPlayerObserver];
        }
    }
}

@end
