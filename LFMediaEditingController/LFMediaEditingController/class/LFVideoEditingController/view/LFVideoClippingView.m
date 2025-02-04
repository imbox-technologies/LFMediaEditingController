//
//  LFVideoClippingView.m
//  LFMediaEditingController
//
//  Created by LamTsanFeng on 2017/7/17.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFVideoClippingView.h"
#import "LFVideoPlayer.h"
#import "UIView+LFMECommon.h"
#import "UIView+LFMEFrame.h"
#import "LFMediaEditingHeader.h"

/** 编辑功能 */
#import "LFDrawView.h"
#import "LFStickerView.h"

/** 滤镜框架 */
#import "LFDataFilterVideoView.h"

NSString *const kLFVideoCLippingViewData = @"LFVideoCLippingViewData";

NSString *const kLFVideoCLippingViewData_startTime = @"LFVideoCLippingViewData_startTime";
NSString *const kLFVideoCLippingViewData_endTime = @"LFVideoCLippingViewData_endTime";
NSString *const kLFVideoCLippingViewData_rate = @"LFVideoCLippingViewData_rate";

NSString *const kLFVideoCLippingViewData_draw = @"LFVideoCLippingViewData_draw";
NSString *const kLFVideoCLippingViewData_sticker = @"LFVideoCLippingViewData_sticker";
NSString *const kLFVideoCLippingViewData_filter = @"LFVideoCLippingViewData_filter";

@interface LFVideoClippingView () <LFVideoPlayerDelegate, UIScrollViewDelegate>

@property (nonatomic, weak) LFDataFilterVideoView *playerView;
@property (nonatomic, strong) LFVideoPlayer *videoPlayer;

/** 原始坐标 */
@property (nonatomic, assign) CGRect originalRect;

/** 缩放视图 */
@property (nonatomic, weak) UIView *zoomingView;

/** 绘画 */
@property (nonatomic, weak) LFDrawView *drawView;
/** 贴图 */
@property (nonatomic, weak) LFStickerView *stickerView;

@property (nonatomic, strong) UIButton *playPauseButton;

@property (nonatomic, strong) UIButton *muteButton;

@property (nonatomic, assign) BOOL muteOriginal;
@property (nonatomic, strong) NSArray <NSURL *>*audioUrls;
@property (nonatomic, strong) AVAsset *asset;



#pragma mark 编辑数据
/** 开始播放时间 */
@property (nonatomic, assign) double old_startTime;
/** 结束播放时间 */
@property (nonatomic, assign) double old_endTime;

@end

@implementation LFVideoClippingView

@synthesize rate = _rate;

/*
 1、播放功能（无限循环）
 2、暂停／继续功能
 3、视频编辑功能
*/

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _originalRect = frame;
        [self customInit];
    }
    return self;
}

- (void)customInit
{
    self.backgroundColor = [UIColor clearColor];
    self.scrollEnabled = NO;
    self.delegate = self;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    
    /** 缩放视图 */
    UIView *zoomingView = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:zoomingView];
    _zoomingView = zoomingView;
    
    
    /** 播放视图 */
    LFDataFilterVideoView *playerView = [[LFDataFilterVideoView alloc] initWithFrame:self.bounds];
    playerView.contentMode = UIViewContentModeScaleAspectFit;
    [self.zoomingView addSubview:playerView];
    _playerView = playerView;
    
    /** 绘画 */
    LFDrawView *drawView = [[LFDrawView alloc] initWithFrame:self.bounds];
    /**
     默认画笔
     */
    drawView.brush = [LFPaintBrush new];
    /** 默认不能触发绘画 */
    drawView.userInteractionEnabled = NO;
    [self.zoomingView addSubview:drawView];
    self.drawView = drawView;
    
    /** 贴图 */
    LFStickerView *stickerView = [[LFStickerView alloc] initWithFrame:self.bounds];
    __weak typeof(self) weakSelf = self;
    stickerView.moveCenter = ^BOOL(CGRect rect) {
        /** 判断缩放后贴图是否超出边界线 */
        CGRect newRect = [weakSelf.zoomingView convertRect:rect toView:weakSelf];
        CGRect clipTransRect = CGRectApplyAffineTransform(weakSelf.frame, weakSelf.transform);
        CGRect screenRect = (CGRect){weakSelf.contentOffset, clipTransRect.size};
        screenRect = CGRectInset(screenRect, 44, 44);
        return !CGRectIntersectsRect(screenRect, newRect);
    };
    /** 禁止后，贴图将不能拖到，设计上，贴图是永远可以拖动的 */
    //    stickerView.userInteractionEnabled = NO;
    [self.zoomingView addSubview:stickerView];
    self.stickerView = stickerView;
    
    // Play/pause button
    const CGFloat playPauseButtonSize = 60;
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playPauseButton.frame = CGRectMake(0, 0, playPauseButtonSize, playPauseButtonSize);
    self.playPauseButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.playPauseButton.tintColor = [UIColor whiteColor];
    self.playPauseButton.layer.cornerRadius = playPauseButtonSize / 2.0;
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [self updatePlayPauseButton];
    [self.zoomingView addSubview:self.playPauseButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.playPauseButton.centerXAnchor constraintEqualToAnchor:self.zoomingView.centerXAnchor],
        [self.playPauseButton.centerYAnchor constraintEqualToAnchor:self.zoomingView.centerYAnchor],
        [self.playPauseButton.widthAnchor constraintEqualToConstant:playPauseButtonSize],
        [self.playPauseButton.heightAnchor constraintEqualToConstant:playPauseButtonSize]
    ]];
    
    // Mute button
    const CGFloat muteButtonSize = 40;
    self.muteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.muteButton.frame = CGRectMake(0, 0, muteButtonSize, muteButtonSize);
    self.muteButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.muteButton.tintColor = [UIColor whiteColor];
    self.muteButton.layer.cornerRadius = muteButtonSize / 2.0;
    self.muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.muteButton addTarget:self action:@selector(toggleMute) forControlEvents:UIControlEventTouchUpInside];
    [self updateMuteButton];
    [self.zoomingView addSubview:self.muteButton];
    [NSLayoutConstraint activateConstraints:@[
        [self.muteButton.topAnchor constraintEqualToAnchor:self.zoomingView.topAnchor constant:25],
        [self.muteButton.leadingAnchor constraintEqualToAnchor:self.zoomingView.leadingAnchor constant:10],
        [self.muteButton.widthAnchor constraintEqualToConstant:muteButtonSize],
        [self.muteButton.heightAnchor constraintEqualToConstant:muteButtonSize]
    ]];
    
    // 实现LFEditingProtocol协议
    {
        self.lf_displayView = self.playerView;
        self.lf_drawView = self.drawView;
        self.lf_stickerView = self.stickerView;
    }
}

- (void)dealloc
{
    [self pauseVideo];
    self.videoPlayer.delegate = nil;
    self.videoPlayer = nil;
    self.playerView = nil;
    // 释放LFEditingProtocol协议
    [self clearProtocolxecutor];
}

- (void)setVideoAsset:(AVAsset *)asset placeholderImage:(UIImage *)image
{
    _asset = asset;
    [self.playerView setImageByUIImage:image];
    if (self.videoPlayer == nil) {
        self.videoPlayer = [LFVideoPlayer new];
        self.videoPlayer.delegate = self;
    }
    [self.videoPlayer setAsset:asset];
    [self.videoPlayer setAudioUrls:self.audioUrls];
    if (_rate > 0 && !(_rate + FLT_EPSILON > 1.0 && _rate - FLT_EPSILON < 1.0)) {
        self.videoPlayer.rate = _rate;
    }
    
    /** 重置编辑UI位置 */
    CGSize videoSize = self.videoPlayer.size;
    if (CGSizeEqualToSize(CGSizeZero, videoSize) || isnan(videoSize.width) || isnan(videoSize.height)) {
        videoSize = self.zoomingView.lfme_size;
    }
    CGRect editRect = AVMakeRectWithAspectRatioInsideRect(videoSize, self.originalRect);
    
    /** 参数取整，否则可能会出现1像素偏差 */
    editRect = LFMediaEditProundRect(editRect);
    
    self.frame = editRect;
    _zoomingView.lfme_size = editRect.size;
    
    /** 子控件更新 */
    [[self.zoomingView subviews] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.frame = self.zoomingView.bounds;
    }];
}

- (void)setCropRect:(CGRect)cropRect
{
    _cropRect = cropRect;
    
    self.frame = cropRect;
//    _playerLayerView.center = _drawView.center = _splashView.center = _stickerView.center = self.center;
    
    /** 重置最小缩放比例 */
    CGRect rotateNormalRect = CGRectApplyAffineTransform(self.originalRect, self.transform);
    CGFloat minimumZoomScale = MAX(CGRectGetWidth(self.frame) / CGRectGetWidth(rotateNormalRect), CGRectGetHeight(self.frame) / CGRectGetHeight(rotateNormalRect));
    self.minimumZoomScale = minimumZoomScale;
    self.maximumZoomScale = minimumZoomScale;
    
    [self setZoomScale:minimumZoomScale];
}

- (void)togglePlayPause
{
    if ([self isPlaying]) {
        [self pauseVideo];
    } else {
        [self resumeVideo];
    }
    [self updatePlayPauseButton];
}

- (void)updatePlayPauseButton
{
    UIImage *image = [self isPlaying] ? [UIImage systemImageNamed:@"pause.fill"] : [UIImage systemImageNamed:@"play.fill"];
    [self.playPauseButton setImage:image forState:UIControlStateNormal];
}

- (void)muteVideo
{
    self.videoPlayer.muteOriginalSound = YES;
    [self updateMuteButton];
}

- (void)toggleMute
{
    self.videoPlayer.muteOriginalSound = !self.videoPlayer.muteOriginalSound;
    [self updateMuteButton];
}

- (void)updateMuteButton
{
    UIImage *image = self.videoPlayer.muteOriginalSound ? [UIImage systemImageNamed:@"speaker.slash.fill"] : [UIImage systemImageNamed:@"speaker.2.fill"];
    [self.muteButton setImage:image forState:UIControlStateNormal];
}

/** 保存 */
- (void)save
{
    self.old_startTime = self.startTime;
    self.old_endTime = self.endTime;
}
/** 取消 */
- (void)cancel
{
    self.startTime = self.old_startTime;
    self.endTime = self.old_endTime;
}

/** 播放 */
- (void)playVideo
{
    [self.videoPlayer play];
    [self seekToTime:self.startTime];
    [self updatePlayPauseButton];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPlay:)]) {
        [self.clipDelegate lf_videoClippingViewPlay:self];
    }
}

- (void)resumeVideo
{
    [self.videoPlayer play];
    [self updatePlayPauseButton];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPlay:)]) {
        [self.clipDelegate lf_videoClippingViewPlay:self];
    }
}

/** 暂停 */
- (void)pauseVideo
{
    [self.videoPlayer pause];
    [self updatePlayPauseButton];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPause:)]) {
        [self.clipDelegate lf_videoClippingViewPause:self];
    }
}

/** 静音原音 */
- (void)muteOriginalVideo:(BOOL)mute
{
    _muteOriginal = mute;
    self.videoPlayer.muteOriginalSound = mute;
}

- (float)rate
{
    return self.videoPlayer.rate ?: 1.0;
}

- (void)setRate:(float)rate
{
    _rate = rate;
    self.videoPlayer.rate = rate;
}

/** 是否播放 */
- (BOOL)isPlaying
{
    return [self.videoPlayer isPlaying];
}

/** 重新播放 */
- (void)replayVideo
{
    [self.videoPlayer resetDisplay];
    if (![self.videoPlayer isPlaying]) {
        [self playVideo];
    } else {
        [self seekToTime:self.startTime];
    }
}

/** 重置视频 */
- (void)resetVideoDisplay
{
    [self.videoPlayer pause];
    [self.videoPlayer resetDisplay];
    [self seekToTime:self.startTime];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPause:)]) {
        [self.clipDelegate lf_videoClippingViewPause:self];
    }
}

/** 增加音效 */
- (void)setAudioMix:(NSArray <NSURL *>*)audioMix
{
    _audioUrls = audioMix;
    [self.videoPlayer setAudioUrls:self.audioUrls];
}

/** 移动到某帧 */
- (void)seekToTime:(CGFloat)time
{
    [self.videoPlayer seekToTime:time];
}

- (void)beginScrubbing
{
    _isScrubbing = YES;
    [self.videoPlayer beginScrubbing];
}

- (void)endScrubbing
{
    _isScrubbing = NO;
    [self.videoPlayer endScrubbing];
}

/** 是否存在水印 */
- (BOOL)hasWatermark
{
    return self.drawView.canUndo || self.stickerView.subviews.count;
}

- (UIView *)overlayView
{
    if (self.hasWatermark) {
        
        UIView *copyZoomView = [[UIView alloc] initWithFrame:self.zoomingView.bounds];
        copyZoomView.backgroundColor = [UIColor clearColor];
        copyZoomView.userInteractionEnabled = NO;
        
        if (self.drawView.canUndo) {
            /** 绘画 */
            UIView *drawView = [[UIView alloc] initWithFrame:copyZoomView.bounds];
            drawView.layer.contents = (__bridge id _Nullable)([self.drawView LFME_captureImage].CGImage);
            [copyZoomView addSubview:drawView];
        }
        
        if (self.stickerView.subviews.count) {
            /** 贴图 */
            UIView *stickerView = [[UIView alloc] initWithFrame:copyZoomView.bounds];
            stickerView.layer.contents = (__bridge id _Nullable)([self.stickerView LFME_captureImage].CGImage);
            [copyZoomView addSubview:stickerView];
        }
        
        return copyZoomView;
    }
    return nil;
}

- (LFFilter *)filter
{
    return self.playerView.filter;
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.zoomingView;
}

#pragma mark - LFVideoPlayerDelegate
/** 画面回调 */
- (void)LFVideoPlayerLayerDisplay:(LFVideoPlayer *)player avplayer:(AVPlayer *)avplayer
{
    if (self.startTime > 0) {
        [player seekToTime:self.startTime];
    }
    [self.playerView setPlayer:avplayer];
//    [self.playerLayerView setImage:nil];
}
/** 可以播放 */
- (void)LFVideoPlayerReadyToPlay:(LFVideoPlayer *)player duration:(double)duration
{
    if (_endTime == 0) { /** 读取配置优于视频初始化的情况 */
        _endTime = duration;
    }
    _totalDuration = duration;
    [self muteVideo];
    [self playVideo];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewReadyToPlay:)]) {
        [self.clipDelegate lf_videoClippingViewReadyToPlay:self];
    }
}

/** 播放结束 */
- (void)LFVideoPlayerPlayDidReachEnd:(LFVideoPlayer *)player
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPlayToEndTime:)]) {
        [self.clipDelegate lf_videoClippingViewPlayToEndTime:self];
    }
    [self playVideo];
    [self updatePlayPauseButton];
}
/** 错误回调 */
- (void)LFVideoPlayerFailedToPrepare:(LFVideoPlayer *)player error:(NSError *)error
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewFailedToPrepare:error:)]) {
        [self.clipDelegate lf_videoClippingViewFailedToPrepare:self error:error];
    }
}

/** 进度回调2-手动实现 */
- (void)LFVideoPlayerSyncScrub:(LFVideoPlayer *)player duration:(double)duration
{
    if (self.isScrubbing) return;
    if (duration > self.endTime) {
        [self replayVideo];
    } else {
        if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingView:duration:)]) {
            [self.clipDelegate lf_videoClippingView:self duration:duration];
        }
    }
}

/** 进度长度 */
- (CGFloat)LFVideoPlayerSyncScrubProgressWidth:(LFVideoPlayer *)player
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewProgressWidth:)]) {
        return [self.clipDelegate lf_videoClippingViewProgressWidth:self];
    }
    return [UIScreen mainScreen].bounds.size.width;
}


#pragma mark - LFEditingProtocol

#pragma mark - 数据
- (NSDictionary *)photoEditData
{
    NSDictionary *drawData = _drawView.data;
    NSDictionary *stickerData = _stickerView.data;
    NSDictionary *filterData = _playerView.data;
    
    NSMutableDictionary *data = [@{} mutableCopy];
    if (drawData) [data setObject:drawData forKey:kLFVideoCLippingViewData_draw];
    if (stickerData) [data setObject:stickerData forKey:kLFVideoCLippingViewData_sticker];
    if (filterData) [data setObject:filterData forKey:kLFVideoCLippingViewData_filter];
    
    if (self.startTime > 0 || self.endTime < self.totalDuration || (_rate > 0 && !(_rate + FLT_EPSILON > 1.0 && _rate - FLT_EPSILON < 1.0))) {
        NSDictionary *myData = @{kLFVideoCLippingViewData_startTime:@(self.startTime)
                                 , kLFVideoCLippingViewData_endTime:@(self.endTime)
                                 , kLFVideoCLippingViewData_rate:@(self.rate)};
        [data setObject:myData forKey:kLFVideoCLippingViewData];
    }
    
    if (data.count) {
        return data;
    }
    return nil;
}

- (void)setPhotoEditData:(NSDictionary *)photoEditData
{
    NSDictionary *myData = photoEditData[kLFVideoCLippingViewData];
    if (myData) {
        self.startTime = self.old_startTime = [myData[kLFVideoCLippingViewData_startTime] doubleValue];
        self.endTime = self.old_endTime = [myData[kLFVideoCLippingViewData_endTime] doubleValue];
        self.rate = [myData[kLFVideoCLippingViewData_rate] floatValue];
    }
    _drawView.data = photoEditData[kLFVideoCLippingViewData_draw];
    _stickerView.data = photoEditData[kLFVideoCLippingViewData_sticker];
    _playerView.data = photoEditData[kLFVideoCLippingViewData_filter];
}

@end
