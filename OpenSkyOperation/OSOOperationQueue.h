/*!
 * OSOOperationQueue.h
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/20/15
 */

#ifndef OpenSkyOperation_OSOOperationQueue_h
#define OpenSkyOperation_OSOOperationQueue_h

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface OSOOperationQueue : NSOperationQueue

- (instancetype)initWithName:(nullable NSString *)name;

+ (OSOOperationQueue *)backgroundQueue;

+ (OSOOperationQueue *)utilityQueue;

@end

NS_ASSUME_NONNULL_END

#endif
