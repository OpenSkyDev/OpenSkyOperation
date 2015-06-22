/*!
 * OSOOperation.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/20/15
 */

@import Darwin.libkern.OSAtomic;

#import "OSOOperation.h"

#import <OpenSkyOperation/OSOOperationObserver.h>

#define OSOOperationAssert(condition, desc, ...) NSAssert(condition, desc, ##__VA_ARGS__)

static NSString *const kOSOOperationState = @"state";

@interface OSOOperation () {
    volatile OSSpinLock __lock;
    volatile int32_t __calledFinish;
}

@property (nonatomic, assign, readwrite) OSOOperationState state;

@property (nonatomic, strong, readwrite) NSMutableSet<id<OSOOperationObserver>> *observers;

@property (nonatomic, strong, readwrite) NSMutableSet<NSError *> *errors;

@end

@implementation OSOOperation

- (instancetype)init {
    self = [super init];
    if (self) {
        __lock = OS_SPINLOCK_INIT;
        __calledFinish = 0;
        _state = OSOOperationStateInitialized;
    }
    return self;
}

// MARK: - Overrides
- (BOOL)isExecuting {
    return (self.state == OSOOperationStateExecuting);
}
- (BOOL)isReady {
    if (self.state == OSOOperationStatePending) {
        if ([super isReady]) {
            [self preparePendingOperation];
        }
        return NO;
    }
    if (self.state == OSOOperationStateReady) {
        return [super isReady];
    }
    return NO;
}
- (BOOL)isFinished {
    return (self.state == OSOOperationStateFinished);
}
- (BOOL)isCancelled {
    return (self.state == OSOOperationStateCancelled);
}

// MARK: - KVO Helpers
+ (NSSet *)keyPathsForValuesAffectingIsReady {
    return [NSSet setWithObject:kOSOOperationState];
}
+ (NSSet *)keyPathsForValuesAffectingIsExecuting {
    return [NSSet setWithObject:kOSOOperationState];
}
+ (NSSet *)keyPathsForValuesAffectingIsFinished {
    return [NSSet setWithObject:kOSOOperationState];
}
+ (NSSet *)keyPathsForValuesAffectingIsCancelled {
    return [NSSet setWithObject:kOSOOperationState];
}

// MARK: - Set State
- (void)setState:(OSOOperationState)state {
    [self willChangeValueForKey:kOSOOperationState];

    switch (_state) {
        case OSOOperationStateCancelled:
            break; // Can't leave Cancelled
        case OSOOperationStateFinished:
            break; // Can't leave Finished
        default:
            OSOOperationAssert(_state != state, @"Can't transition to same state");
            _state = state;
            break;
    }

    [self didChangeValueForKey:kOSOOperationState];
}

- (void)preparePendingOperation {
    self.state = OSOOperationStateReady;
}

// MARK: - Enqueue
- (void)willEnqueue {
    self.state = OSOOperationStatePending;
}

// MARK: - Start
- (void)start {
    OSOOperationAssert(self.state == OSOOperationStateReady, @"This operation must be performed on an OSOOperationQueue");

    self.state = OSOOperationStateExecuting;

    for (id<OSOOperationObserver> observer in [self allObservers]) {
        [observer operationDidStart:self];
    }

    [self execute];
}

// MARK: - Perform
- (void)execute {
    NSLog(@"%@ should override %@",NSStringFromClass(self.class),NSStringFromSelector(_cmd));

    [self finish];
}

// MARK: - Finish
- (void)finish {
    [self finishWithErrors:nil];
}

- (void)finishWithError:(nullable NSError *)error {
    NSArray *errors = nil;
    if (error) {
        errors = @[error];
    }
    [self finishWithErrors:errors];
}

- (void)finishWithErrors:(nullable NSArray<NSError *> *)errors {
    if (OSAtomicAdd32Barrier(1, &__calledFinish) > 1) {
        return;
    }
    self.state = OSOOperationStateFinishing;

    if (errors.count > 0) {
        [self appendErrors:errors];
    }

    NSArray<NSError *> *allErrors = [self allErrors];

    [self finishedWithErrors:allErrors];

    for (id<OSOOperationObserver> observer in [self allObservers]) {
        [observer operation:self didFinishWithErrors:allErrors];
    }

    OSSpinLockLock(&__lock);
    self.observers = nil;
    OSSpinLockUnlock(&__lock);

    self.state = OSOOperationStateFinished;
}

- (void)finishedWithErrors:(nullable NSArray<NSError *> *)errors {
    // no-op
}

// MARK: - Cancel
- (void)cancel {
    [self cancelWithError:nil];
}
- (void)cancelWithError:(nullable NSError *)error {
    if (error) {
        [self appendErrors:@[error]];
    }
    self.state = OSOOperationStateCancelled;
}

// MARK: - Errors
- (void)appendErrors:(NSArray<NSError *> *)errors {
    OSSpinLockLock(&__lock);
    if (!_errors) {
        _errors = [[NSMutableSet alloc] init];
    }
    [_errors addObjectsFromArray:errors];
    OSSpinLockUnlock(&__lock);
}

- (NSArray<NSError *> *)allErrors {
    NSArray<NSError *> *errors = nil;
    OSSpinLockLock(&__lock);
    errors = [_errors allObjects];
    OSSpinLockUnlock(&__lock);
    return errors;
}

// MARK: - Wait
- (void)waitUntilFinished {
    NSAssert(NO, @"%s should never be used",__PRETTY_FUNCTION__);
}

// MARK: - Deps
- (nullable NSArray<__kindof OSOOperation *> *)createDependencies {
    return nil;
}

// MARK: - Observers
- (void)addObserver:(id<OSOOperationObserver>)observer {
    OSSpinLockLock(&__lock);
    if (!self.observers) {
        self.observers = [[NSMutableSet alloc] init];
    }
    [self.observers addObject:observer];
    OSSpinLockUnlock(&__lock);
}
- (void)removeObserver:(id<OSOOperationObserver>)observer {
    OSSpinLockLock(&__lock);
    [self.observers removeObject:observer];
    OSSpinLockUnlock(&__lock);
}
- (NSArray<id<OSOOperationObserver>> *)allObservers {
    OSSpinLockLock(&__lock);
    NSArray<id<OSOOperationObserver>> *obs = [self.observers allObjects];
    OSSpinLockUnlock(&__lock);
    return obs;
}

@end
