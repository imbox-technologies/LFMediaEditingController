//
//  LFVideoPlayer.h
//  VideoPlayDemo
//
//  Created by LamTsanFeng on 2016/11/17.
//  Copyright © 2016年 GZMiracle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class LFVideoPlayer;

@protocol LFVideoPlayerDelegate <NSObject>

/** 画面回调 */
- (void)LFVideoPlayerLayerDisplay:(LFVideoPlayer *)player avplayer:(AVPlayer *)avplayer;
/** 可以播放 */
- (void)LFVideoPlayerReadyToPlay:(LFVideoPlayer *)player duration:(double)duration;
@optional
/** 播放结束 */
- (void)LFVideoPlayerPlayDidReachEnd:(LFVideoPlayer *)player;
/** 进度回调1-自动实现 */
- (UISlider *)LFVideoPlayerSyncScrub:(LFVideoPlayer *)player;
/** 进度回调2-手动实现 */
- (void)LFVideoPlayerSyncScrub:(LFVideoPlayer *)player duration:(double)duration;
/** 进度长度 */
- (CGFloat)LFVideoPlayerSyncScrubProgressWidth:(LFVideoPlayer *)player;
/** 错误回调 */
- (void)LFVideoPlayerFailedToPrepare:(LFVideoPlayer *)player error:(NSError *)error;

@end

@interface LFVideoPlayer : NSObject
{
    NSURL* mURL;
    
    float mRestoreAfterScrubbingRate;
    BOOL seekToZeroBeforePlay;
    id mTimeObserver;
    BOOL isSeeking;
}
/** 视频URL，初始化新对象将会重置以下所有参数 */
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) AVAsset *asset;

/** 代理 */
@property (nonatomic, weak) id<LFVideoPlayerDelegate> delegate;

/** 音效 */
@property (nonatomic, strong) NSArray <NSURL *> *audioUrls;
/** 视频大小 */
@property (nonatomic, readonly) CGSize size;
/** 视频时长 */
@property (nonatomic, readonly) double totalDuration;
/** 当前播放时间 */
@property (nonatomic, readonly) double duration;
/** 针对原音轨静音 */
@property (nonatomic, assign) BOOL muteOriginalSound;
/** 播放速率 (0.5~2.0) 值为0则禁止播放，默认1 */
@property (nonatomic, assign) float rate;

/** 视频控制 */
- (void)play;
- (void)pause;
/** 静音 */
- (void)mute:(BOOL)mute;
- (BOOL)isPlaying;
/** 重置画面 */
- (void)resetDisplay;
/** 跳转到某帧 */
- (void)seekToTime:(CGFloat)time;

- (double)currentTime;

/** 进度处理 */
#pragma mark - 自动实现进度 拖动回调
/** 拖动开始调用 */
- (void)beginScrubbing;
/** 拖动进度改变入参 */
- (void)scrub:(UISlider *)slider;
/** 拖动结束调用 */
- (void)endScrubbing;
@end
