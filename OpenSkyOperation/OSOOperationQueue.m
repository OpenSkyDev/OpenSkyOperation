/*!
 * OSOOperationQueue.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/20/15
 */

#import "OSOOperationQueue.h"

#import <OpenSkyOperation/OSOOperation.h>

#import "OSOExclusiveOperationController.h"

@interface OSOOperationQueue ()

@end

@implementation OSOOperationQueue

// MARK: - Init
- (instancetype)initWithName:(nullable NSString *)name {
    self = [super init];
    if (self) {
        self.name = name;
    }
    return self;
}

// MARK: - Overrides
- (void)addOperation:(nonnull NSOperation *)op {
    if ([op isKindOfClass:[OSOOperation class]]) {
        OSOOperation *_op = (OSOOperation *)op;
        NSArray<__kindof OSOOperation *> *deps = [_op createDependencies];

        if (deps.count > 0) {
            for (__kindof OSOOperation *dep in deps) {
                [_op addDependency:dep];
                [self addOperation:dep];
            }
        }

        if ([_op conformsToProtocol:@protocol(OSOExclusiveOperation)]) {
            [OSOExclusiveOperationController addExclusiveOperation:(OSOOperation<OSOExclusiveOperation> *)_op];
        }

        [_op willEnqueue];
    }
    [super addOperation:op];
}

// addOperation: is not called by this method, we we'll do it
- (void)addOperations:(nonnull NSArray<NSOperation *> *)ops waitUntilFinished:(BOOL)wait {
    for (NSOperation *op in ops) {
        [self addOperation:op];
    }

    if (wait) {
        for (NSOperation *op in ops) {
            [op waitUntilFinished];
        }
    }
}

// MARK: - Helpers
+ (OSOOperationQueue *)backgroundQueue {
    static OSOOperationQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[OSOOperationQueue alloc] init];
        queue.name = @"com.planningcenter.QoSBackground";
        queue.qualityOfService = NSQualityOfServiceBackground;
    });
    return queue;
}

+ (OSOOperationQueue *)utilityQueue {
    static OSOOperationQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[OSOOperationQueue alloc] init];
        queue.name = @"com.planningcenter.QoSUtility";
        queue.qualityOfService = NSQualityOfServiceUtility;
    });
    return queue;
}

+ (OSOOperationQueue *)criticalQueue {
    static OSOOperationQueue *queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[OSOOperationQueue alloc] init];
        queue.name = @"com.planningcenter.QoSUserInteractive";
        queue.qualityOfService = NSQualityOfServiceUserInteractive;
    });
    return queue;
}

@end
