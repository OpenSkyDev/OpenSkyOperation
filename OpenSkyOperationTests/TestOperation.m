/*!
 * TestOperation.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 9/10/15
 */

#import "TestOperation.h"

@interface TestOperation ()

@end

@implementation TestOperation

- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    if (self.completion) {
        self.completion(errors);
        _completion = nil;
    }
}

@end
