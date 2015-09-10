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
static NSString *const kOSOOperationCanceledState = @"cancelledState";

@interface OSOOperation () {
    volatile OSSpinLock __lock;
    volatile int32_t __calledFinish;
    volatile OSSpinLock __stateLock;
}

@property (nonatomic, assign, readwrite) OSOOperationState state;

@property (nonatomic, strong, readwrite) NSMutableSet<id<OSOOperationObserver>> *observers;

@property (nonatomic, strong, readwrite) NSMutableSet<NSError *> *backingErrors;

@property (nonatomic, assign) BOOL cancelState;

@end

@implementation OSOOperation
@synthesize state = _state;

- (instancetype)init {
    self = [super init];
    if (self) {
        __lock = OS_SPINLOCK_INIT;
        __stateLock = OS_SPINLOCK_INIT;
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
    if (self.state == OSOOperationStateInitialized) {
        return [self isCancelled];
    }
    if (self.state == OSOOperationStatePending) {
        if ([self isCancelled]) {
            self.state = OSOOperationStateReady;
            return YES;
        }
        if ([super isReady]) {
            [self preparePendingOperation];
        }
        return NO;
    }
    if (self.state == OSOOperationStateReady) {
        return [super isReady] || [self isCancelled];
    }
    return NO;
}
- (BOOL)isFinished {
    return (self.state == OSOOperationStateFinished);
}
- (BOOL)isCancelled {
    return [self cancelState];
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
    return [NSSet setWithObject:kOSOOperationCanceledState];
}

// MARK: - Set State
- (void)setState:(OSOOperationState)state {
    [self willChangeValueForKey:kOSOOperationState];

    OSSpinLockLock(&__stateLock);

    switch (_state) {
        case OSOOperationStateFinished:
            break; // Can't leave Finished
        default:
            OSOOperationAssert(OSOOperationCanTransitionToState(_state, state, [self isCancelled]), @"Can't transition from %td to %td",_state,state);
            _state = state;
            break;
    }

    OSSpinLockUnlock(&__stateLock);

    [self didChangeValueForKey:kOSOOperationState];
}

- (OSOOperationState)state {
    OSSpinLockLock(&__stateLock);
    OSOOperationState state = _state;
    OSSpinLockUnlock(&__stateLock);
    return state;
}

- (void)preparePendingOperation {
    self.state = OSOOperationStateReady;
}

- (void)setCancelState:(BOOL)cancelState {
    [self willChangeValueForKey:kOSOOperationCanceledState];
    _cancelState = cancelState;
    [self didChangeValueForKey:kOSOOperationCanceledState];
}

// MARK: - Enqueue
- (void)willEnqueue {
    self.state = OSOOperationStatePending;
}

- (BOOL)isConcurrent {
    return YES;
}

// MARK: - Start
- (void)start {
    [super start];

    if ([self isCancelled]) {
        [self finish];
        return;
    }
}

- (void)main {
    OSOOperationAssert(self.state == OSOOperationStateReady, @"This operation must be performed on an OSOOperationQueue");

    if ([self isCancelled]) {
        [self finish];
        return;
    }

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

    self.state = OSOOperationStateFinished;

    OSSpinLockLock(&__lock);
    self.observers = nil;
    [_backingErrors removeAllObjects];
    OSSpinLockUnlock(&__lock);
}

- (void)finishedWithErrors:(nullable NSArray<NSError *> *)errors {
    // no-op
}

// MARK: - Cancel
- (void)cancel {
    if ([self isFinished]) {
        return;
    }

    self.cancelState = YES;

    if (self.state > OSOOperationStateReady) {
        [self finish];
    }
}
- (void)cancelWithError:(nullable NSError *)error {
    if (error) {
        [self appendErrors:@[error]];
    }
    [self cancel];
}

// MARK: - Errors
- (void)appendErrors:(NSArray<NSError *> *)errors {
    OSSpinLockLock(&__lock);
    if (!_backingErrors) {
        _backingErrors = [[NSMutableSet alloc] init];
    }
    [_backingErrors addObjectsFromArray:errors];
    OSSpinLockUnlock(&__lock);
}

- (NSArray<NSError *> *)allErrors {
    NSArray<NSError *> *errors = nil;
    OSSpinLockLock(&__lock);
    errors = [_backingErrors allObjects];
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

BOOL OSOOperationCanTransitionToState(OSOOperationState current, OSOOperationState new, BOOL canceled) {
    if (current == OSOOperationStateInitialized && new == OSOOperationStatePending) {
        return YES;
    }
    if (current == OSOOperationStatePending && new == OSOOperationStateFinishing && canceled) {
        return YES;
    }
    if (current == OSOOperationStatePending && new == OSOOperationStateReady && canceled) {
        return YES;
    }
    if (current == OSOOperationStatePending && new == OSOOperationStateReady) {
        return YES;
    }
    if (current == OSOOperationStateReady && new == OSOOperationStateExecuting) {
        return YES;
    }
    if (current == OSOOperationStateReady && new == OSOOperationStateFinishing) {
        return YES;
    }
    if (current == OSOOperationStateExecuting && new == OSOOperationStateFinishing) {
        return YES;
    }
    if (current == OSOOperationStateFinishing && new == OSOOperationStateFinished) {
        return YES;
    }
    return NO;
}
