/*!
 * OSOOperation.h
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/20/15
 */

#ifndef OpenSkyOperation_OSOOperation_h
#define OpenSkyOperation_OSOOperation_h

@import Foundation;

@protocol OSOOperationObserver;

@class OSOErrorCollection;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OSOOperationState) {
    OSOOperationStateInitialized = 0,
    OSOOperationStatePending     = 1,
    OSOOperationStateReady       = 2,
    OSOOperationStateExecuting   = 3,
    OSOOperationStateFinishing   = 4,
    OSOOperationStateFinished    = 5
};

@interface OSOOperation : NSOperation

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@property (nonatomic, assign, readonly) OSOOperationState state;

- (nullable NSArray<NSError *> *)allErrors;

- (void)willEnqueue;

// MARK: - Observers
- (void)addOperationObserver:(id<OSOOperationObserver>)observer;
- (void)removeOperationObserver:(id<OSOOperationObserver>)observer;
- (nullable NSArray<id<OSOOperationObserver>> *)allOperationObservers;

@end

/**
 *  Override these methods in your subclass to provide custom functionality
 */
@interface OSOOperation (SubclassingHooks)

/**
 *  Override this method in your sublcass to do your work.
 */
- (void)execute;

/**
 *  This method can be overridden if you need to do specific cleanup or error handling.
 *
 *  @param errors The errors the operation finished with.
 */
- (void)operationDidCompleteWithErrors:(nullable NSArray<NSError *> *)errors NS_REQUIRES_SUPER;

/**
 *  If an operation needs other operations to complete before being run a subclass can create them here.
 *
 *  They will be automatically enqueued & added as a pre-requisite of the generating operation.
 *
 *  @return An array of operations or nil
 */
- (nullable NSArray<__kindof OSOOperation *> *)createDependencies;

@end

/**
 *  Methods defined here should be treated as `final` and should not be overridden
 */
@interface OSOOperation (HelperMethods)

- (void)finishOperation;
- (void)finishOperationWithError:(nullable NSError *)error;
- (void)finishOperationWithErrors:(nullable NSArray<NSError *> *)errors;

@end

FOUNDATION_EXTERN NSString *const OSOOperationErrorDomain;
typedef NS_ENUM(NSInteger, OSOOperationError) {
    OSOOperationErrorCanceled = 0
};

FOUNDATION_EXTERN BOOL OSOOperationCanTransitionToState(OSOOperationState, OSOOperationState, BOOL);

NS_ASSUME_NONNULL_END

#endif
