/*!
 * OSOExclusiveOperationController.m
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/22/15
 */

@import Darwin.libkern.OSAtomic;

#import "OSOExclusiveOperationController.h"

#import <OpenSkyOperation/OSOOperationObserver.h>
#import <OpenSkyOperation/OSOOperation.h>

@interface OSOExclusiveOperationController () <OSOOperationObserver> {
    volatile OSSpinLock __lock;
}

@property (atomic, strong) NSMutableDictionary *operations;

@end

@implementation OSOExclusiveOperationController

+ (void)addExclusiveOperation:(__kindof OSOOperation<OSOExclusiveOperation> *)operation {
    [self.shared addExclusiveOperation:operation];
}

// MARK: - Add Operation
- (void)addExclusiveOperation:(__kindof OSOOperation<OSOExclusiveOperation> *)operation {
    OSSpinLockLock(&__lock);;

    NSHashTable *table = [self primitiveOperationsForKey:[operation.class exclusivityIdentifier]];

    if ([table containsObject:operation]) {
        OSSpinLockUnlock(&__lock);
        return;
    }

    for (__kindof OSOOperation<OSOExclusiveOperation> *op in table) {
        [operation addDependency:op];
        if ([operation respondsToSelector:@selector(willWaitForOperation:)]) {
            [operation willWaitForOperation:op];
        }
    }

    [table addObject:operation];

    OSSpinLockUnlock(&__lock);
}

- (NSHashTable *)primitiveOperationsForKey:(NSString *)key {
    NSHashTable *table = [self.operations objectForKey:key];
    if (!table) {
        table = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:10];
        [self.operations setObject:table forKey:key];
    }
    return table;
}

// MARK: - Singleton
+ (instancetype)shared {
    static OSOExclusiveOperationController *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        __lock = OS_SPINLOCK_INIT;
        self.operations = [[NSMutableDictionary alloc] init];
    }
    return self;
}

// MARK: - Op Observer
- (void)operationDidStart:(__kindof OSOOperation *)operation {

}
- (void)operation:(__kindof OSOOperation *)operation didFinishWithErrors:(NSArray<NSError *> *)errors {

}

@end
