/*!
 * OSOExclusiveOperationController.h
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/22/15
 */

#ifndef OpenSkyOperation_OSOExclusiveOperationController_h
#define OpenSkyOperation_OSOExclusiveOperationController_h

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@class OSOOperation;

/**
 *  Conforming your operation to OSOExclusiveOperation and adding it to an OSOOperationQueue will guarantee it's run after all other instances of the same operation are run
 *
 *  The only method that must be implemented is + (NSString *)exclusivityIdentifier.  For the most part returning the class name as a string should be sufficient
 */
@protocol OSOExclusiveOperation <NSObject>

@required
+ (NSString *)exclusivityIdentifier;

@optional
- (void)willWaitForOperation:(__kindof OSOOperation *)operation;

@end

@interface OSOExclusiveOperationController : NSObject

/**
 *  Adds and instance of an OSOExclusiveOperation to the current operations.
 *
 *  This happens automatically when adding an OSOExclusiveOperation to an OSOOperationQueue
 */
+ (void)addExclusiveOperation:(__kindof OSOOperation<OSOExclusiveOperation> *)operation;

@end

NS_ASSUME_NONNULL_END

#endif
