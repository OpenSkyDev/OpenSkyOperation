/*!
 * TestExclusive.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/22/15
 */

#import "TestExclusive.h"

@interface TestExclusive ()

@end

@implementation TestExclusive

+ (nonnull NSString *)exclusivityIdentifier {
    return NSStringFromClass(self);
}

- (void)execute {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
        self.exec();
        [self finish];
    });
}

- (BOOL)isConcurrent {
    return YES;
}

@end
