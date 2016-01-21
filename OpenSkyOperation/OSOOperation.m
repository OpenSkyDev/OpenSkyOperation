/*!
 * OSOOperation.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/20/15
 */

@import Darwin.POSIX.pthread;
@import Darwin.libkern.OSAtomic;

#import "OSOOperation.h"

#import <OpenSkyOperation/OSOOperationObserver.h>

#define OSOOperationAssert(condition, desc, ...) NSAssert(condition, desc, ##__VA_ARGS__)

static NSString *const kOSOOperationState = @"state";
static NSString *const kOSOOperationCanceledState = @"cancelledState";

@interface OSOOperation () {
    pthread_mutex_t __lock;
    pthread_mutex_t __stateLock;
    volatile int32_t __calledFinish;
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
        pthread_mutex_init(&__lock, NULL);
        pthread_mutex_init(&__stateLock, NULL);
        __calledFinish = 0;
        _state = OSOOperationStateInitialized;
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&__lock);
    pthread_mutex_destroy(&__stateLock);
}

#if defined(DEBUG) && DEBUG

+ (void)initialize {
    if ([self instancesRespondToSelector:@selector(finishedWithErrors:)]) {
        NSLog(@"******************** DEPRECATED ********************");
        NSLog(@"    Class %@ Implements %@",NSStringFromClass(self.class),NSStringFromSelector(@selector(finishedWithErrors:)));
        NSLog(@"****************************************************");
    }
}

#endif

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

    pthread_mutex_lock(&__stateLock);

    switch (_state) {
        case OSOOperationStateFinished:
            break; // Can't leave Finished
        default:
            OSOOperationAssert(OSOOperationCanTransitionToState(_state, state, [self isCancelled]), @"Can't transition from %td to %td",_state,state);
            _state = state;
            break;
    }

    pthread_mutex_unlock(&__stateLock);

    [self didChangeValueForKey:kOSOOperationState];
}

- (OSOOperationState)state {
    pthread_mutex_lock(&__stateLock);
    OSOOperationState state = _state;
    pthread_mutex_unlock(&__stateLock);
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
        [self finishOperation];
        return;
    }
}

- (void)main {
    OSOOperationAssert(self.state == OSOOperationStateReady, @"This operation must be performed on an OSOOperationQueue");

    if ([self isCancelled]) {
        [self finishOperation];
        return;
    }

    self.state = OSOOperationStateExecuting;

    for (id<OSOOperationObserver> observer in [self allOperationObservers]) {
        [observer operationDidStart:self];
    }

    [self execute];
}

// MARK: - Perform
- (void)execute {
    NSLog(@"%@ should override %@",NSStringFromClass(self.class),NSStringFromSelector(_cmd));

    [self finishOperation];
}

// MARK: - Finish
- (void)finishOperation {
    [self finishOperationWithErrors:nil];
}

- (void)finishOperationWithError:(nullable NSError *)error {
    NSArray *errors = nil;
    if (error) {
        errors = @[error];
    }
    [self finishOperationWithErrors:errors];
}

- (void)finishOperationWithErrors:(nullable NSArray<NSError *> *)errors {
    if (OSAtomicAdd32Barrier(1, &__calledFinish) > 1) {
        return;
    }
    self.state = OSOOperationStateFinishing;

    if (errors.count > 0) {
        [self appendErrors:errors];
    }

    NSArray<NSError *> *allErrors = [self allErrors];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([self respondsToSelector:@selector(finishedWithErrors:)]) {
        NSLog(@"******************** DEPRECATED ********************");
        NSLog(@"    Class %@ Implements %@",NSStringFromClass(self.class),NSStringFromSelector(@selector(finishedWithErrors:)));
        NSLog(@"****************************************************");
        [self finishedWithErrors:allErrors];
    }
#pragma clang diagnostic pop

    [self operationDidCompleteWithErrors:allErrors];

    for (id<OSOOperationObserver> observer in [self allOperationObservers]) {
        [observer operation:self didFinishWithErrors:allErrors];
    }

    self.state = OSOOperationStateFinished;

    pthread_mutex_lock(&__lock);
    self.observers = nil;
    [_backingErrors removeAllObjects];
    pthread_mutex_unlock(&__lock);
}

- (void)operationDidCompleteWithErrors:(nullable NSArray<NSError *> *)errors {
#if defined(DEBUG) && DEBUG
    NSAssert(self.state == OSOOperationStateFinishing, @"%@ called when state is inconsistent.  You shouldn't call this method directly",NSStringFromSelector(_cmd));
#endif
}

// MARK: - Cancel
- (void)cancel {
    if ([self isFinished]) {
        return;
    }

    self.cancelState = YES;

    if (self.state > OSOOperationStateReady) {
        [self finishOperation];
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
    pthread_mutex_lock(&__lock);
    if (!_backingErrors) {
        _backingErrors = [[NSMutableSet alloc] init];
    }
    [_backingErrors addObjectsFromArray:errors];
    pthread_mutex_unlock(&__lock);
}

- (NSArray<NSError *> *)allErrors {
    NSArray<NSError *> *errors = nil;
    pthread_mutex_lock(&__lock);
    errors = [_backingErrors allObjects];
    pthread_mutex_unlock(&__lock);
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
- (void)addOperationObserver:(id<OSOOperationObserver>)observer {
    pthread_mutex_lock(&__lock);
    if (!self.observers) {
        self.observers = [[NSMutableSet alloc] init];
    }
    [self.observers addObject:observer];
    pthread_mutex_unlock(&__lock);
}
- (void)removeOperationObserver:(id<OSOOperationObserver>)observer {
    pthread_mutex_lock(&__lock);
    [self.observers removeObject:observer];
    pthread_mutex_unlock(&__lock);
}
- (NSArray<id<OSOOperationObserver>> *)allOperationObservers {
    pthread_mutex_lock(&__lock);
    NSArray<id<OSOOperationObserver>> *obs = [self.observers allObjects];
    pthread_mutex_unlock(&__lock);
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
