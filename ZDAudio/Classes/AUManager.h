//
//  AUManager.h
//  ZDAudio
//
//  Created by 吕浩轩 on 2021/5/12.
//

#import <Foundation/Foundation.h>
#import <HXCategoriesPro/NSObject+HXMultiDelegate.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PlayerStatus) {
    PlayerStatus_None,
    PlayerStatus_Playing,
    PlayerStatus_Pause,
    PlayerStatus_Stop = PlayerStatus_None
};

typedef void (^Progress)(NSTimeInterval totalTime, NSTimeInterval currentTime);
typedef void (^Level)(CGFloat level, NSError * _Nullable error);

@protocol AUManagerDelegate <NSObject>

@optional

/// 返回时间
/// @param totalTime 总时间
/// @param currentTime 当前时间
- (void)callbackTime:(NSTimeInterval)totalTime currentTime:(NSTimeInterval)currentTime;

/// 返回播放器状态
/// @param status 播放器状态
- (void)callbackPlayerStatus:(PlayerStatus)status;

/* ---------------- 录音 ---------------- */
/// 录音完成
/// @param flag 是否成功，不成功自动删除录音文件
- (void)recorderDidFinishSuccessfully:(BOOL)flag;

@end

@interface AUManager : NSObject

/* ---------------- 录音相关 ---------------- */
/// 当前播放的 URL
@property (nullable, nonatomic, copy, readonly) NSString *urlStr;

/// 播放器状态
@property (nonatomic, readonly) PlayerStatus playerStatus;

/// 总播放时间
@property (nonatomic, readonly) NSTimeInterval totalTime;

/// 当前播放时间
@property (nonatomic, readonly) NSTimeInterval currentTime;

/// 是否正在播放
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;



/// 单例初始化
+ (instancetype)shared;

/* ---------------- 播放 ---------------- */
/// 获取 URL 音视频文件的总时间
/// @param url 网址 或 文件路径
+ (NSTimeInterval)getTotalTimeWithUrl:(NSURL *)url;

/// 播放
/// @param url 网址 或 文件路径
- (void)play:(NSURL *)url;

/// 播放
/// @param url 网址 或 文件路径
/// @param progress 进度
- (void)play:(NSURL *)url progress:(nullable Progress)progress;

/// 跳转到指定时间
/// @param time 指定的时间
- (void)seekToTime:(NSTimeInterval)time;

/// 暂停播放
- (void)pausePaly;

/// 继续播放
- (void)resumePaly;

/// 停止播放
- (void)stopPaly;


/* ---------------- 录音 ---------------- */
/// 录制
/// @param path 保存路径，只支持 .wav
/// @param callback 返回'电平'值 [0 ~ 120]
- (void)recordWithSavePath:(NSString *)path callback:(nullable Level)callback;

/// 停止录制
- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
