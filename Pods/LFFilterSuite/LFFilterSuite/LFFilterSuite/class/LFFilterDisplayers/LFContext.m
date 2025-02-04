//
//  LFContext.m
//  LFMediaEditingController
//
//  Created by TsanFeng Lam on 2019/3/1.
//  Copyright © 2019 LamTsanFeng. All rights reserved.
//

#import "LFContext.h"


NSString *__nonnull const LFContextOptionsCGContextKey = @"CGContext";
NSString *__nonnull const LFContextOptionsMTLDeviceKey = @"MTLDevice";

static NSDictionary *LFContextCreateCIContextOptions(void) {
    return @{kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null]};
}


@implementation LFContext

- (instancetype)initWithSoftwareRenderer:(BOOL)softwareRenderer {
    self = [super init];
    
    if (self) {
        NSMutableDictionary *options = LFContextCreateCIContextOptions().mutableCopy;
        options[kCIContextUseSoftwareRenderer] = @(softwareRenderer);
        _CIContext = [CIContext contextWithOptions:options];
        _type = LFContextTypeDefault;
    }
    
    return self;
}

- (instancetype)initWithCGContextRef:(CGContextRef)contextRef {
    self = [super init];
    
    if (self) {
#ifdef NSFoundationVersionNumber_iOS_9_0
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
            _CGContext = contextRef;
            _CIContext = [CIContext contextWithCGContext:contextRef options:LFContextCreateCIContextOptions()];
            _type = LFContextTypeCoreGraphics;
#pragma clang diagnostic pop
#endif
    }
    
    return self;
}

- (instancetype)initWithLargeImage {
    self = [self initWithSoftwareRenderer:NO];
    
    if (self) {
        _type = LFContextTypeLargeImage;
    }
    
    return self;
}

#ifdef NSFoundationVersionNumber_iOS_9_0
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (instancetype)initWithMTLDevice:(id<MTLDevice>)device {
    self = [super init];
    
    if (self) {
        _MTLDevice = device;
        _CIContext = [CIContext contextWithMTLDevice:device options:LFContextCreateCIContextOptions()];
        _type = LFContextTypeMetal;
    }
    
    return self;
}
#pragma clang diagnostic pop
#endif

- (void)dealloc
{
    _CGContext = nil;
    _MTLDevice = nil;
    _CIContext = nil;
}

+ (LFContextType)suggestedContextType {

//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wunguarded-availability"
//    if ([self supportsType:LFContextTypeMetal]) {
//        return LFContextTypeMetal;
//    } else
//#pragma clang diagnostic pop
    
//#ifdef NSFoundationVersionNumber_iOS_9_0
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wunguarded-availability"
//        if ([self supportsType:LFContextTypeCoreGraphics]) {
//            return LFContextTypeCoreGraphics;
//#pragma clang diagnostic pop
//#endif
//    } else {
        return LFContextTypeDefault;
//    }
}

+ (BOOL)supportsType:(LFContextType)contextType {
    id CIContextClass = [CIContext class];
    
    switch (contextType) {
#ifdef NSFoundationVersionNumber_iOS_9_0
        case LFContextTypeMetal:
            return [CIContextClass respondsToSelector:@selector(contextWithMTLDevice:options:)] && MTLCreateSystemDefaultDevice();
#endif
        case LFContextTypeCoreGraphics:
            return [CIContextClass respondsToSelector:@selector(contextWithCGContext:options:)];
        case LFContextTypeAuto:
        case LFContextTypeDefault:
        case LFContextTypeLargeImage:
            return YES;
    }
    return NO;
}

+ (LFContext *__nonnull)contextWithType:(LFContextType)type options:(NSDictionary *__nullable)options {
    switch (type) {
        case LFContextTypeAuto:
            return [self contextWithType:[self suggestedContextType] options:options];
#if !(TARGET_IPHONE_SIMULATOR)
#ifdef NSFoundationVersionNumber_iOS_9_0
        case LFContextTypeMetal: {
            if (@available(iOS 8.0, *)) {
                id<MTLDevice> device = options[LFContextOptionsMTLDeviceKey];
                if (device == nil) {
                    device = MTLCreateSystemDefaultDevice();
                }
                if (device == nil) {
                    [NSException raise:@"Metal Error" format:@"Metal is available on iOS 8 and A7 chips. Or higher."];
                }
                
                return [[self alloc] initWithMTLDevice:device];
            }
        }
#endif
#endif
        case LFContextTypeCoreGraphics: {
            CGContextRef context = (__bridge CGContextRef)(options[LFContextOptionsCGContextKey]);
            
            if (context == nil) {
                [NSException raise:@"MissingCGContext" format:@"LFContextTypeCoreGraphics needs to have a CGContext attached to the LFContextOptionsCGContextKey in the options"];
            }
            
            return [[self alloc] initWithCGContextRef:context];
        }
        case LFContextTypeDefault:
            return [[self alloc] initWithSoftwareRenderer:NO];
        case LFContextTypeLargeImage:
            return [[self alloc] initWithLargeImage];
        default:
            [NSException raise:@"InvalidContextType" format:@"Invalid context type %d", (int)type];
            break;
    }
    
    return nil;
}

@end
