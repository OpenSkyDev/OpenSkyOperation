/*!
 * TestOperation.h
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 9/10/15
 */

#ifndef OpenSkyOperation_TestOperation_h
#define OpenSkyOperation_TestOperation_h

#import <OpenSkyOperation/OpenSkyOperation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TestOperation : OSOOperation

@property (nonatomic, copy) void (^completion)(NSArray<NSError *> *);

@end

NS_ASSUME_NONNULL_END

#endif
