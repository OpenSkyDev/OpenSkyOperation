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
- (void)addObserver:(id<OSOOperationObserver>)observer;
- (void)removeObserver:(id<OSOOperationObserver>)observer;
- (nullable NSArray<id<OSOOperationObserver>> *)allObservers;

@end

/**
 *  Override these methods in your subclass to provide custom functionality
 */
@interface OSOOperation (SubclassingHooks)

- (void)execute;

- (void)finishedWithErrors:(nullable NSArray<NSError *> *)errors;

- (nullable NSArray<__kindof OSOOperation *> *)createDependencies;

@end

/**
 *  Methods defined here should be treated as `final` and should not be overridden
 */
@interface OSOOperation (HelperMethods)

- (void)finish;
- (void)finishWithError:(nullable NSError *)error;
- (void)finishWithErrors:(nullable NSArray<NSError *> *)errors;

@end

FOUNDATION_EXTERN BOOL OSOOperationCanTransitionToState(OSOOperationState, OSOOperationState, BOOL);

NS_ASSUME_NONNULL_END

#endif
