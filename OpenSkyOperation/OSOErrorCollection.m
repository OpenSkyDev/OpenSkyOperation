/*!
 * OSOErrorCollection.m
 * OpenSkyOperation
 *
 * Copyright (c) 2016 OpenSky, LLC
 *
 * Created by Skylar Schipper on 1/21/16
 */

@import Darwin.POSIX.pthread;

#import "OSOErrorCollection.h"

@interface OSOErrorCollection () {
    pthread_mutex_t _lock;
}

@property (nonatomic, strong) NSMutableArray *errorStore;

@end

@implementation OSOErrorCollection

// MARK: - Init
- (instancetype)init {
    self = [super init];
    if (self) {
        pthread_mutex_init(&_lock, NULL);

        pthread_mutex_lock(&_lock);
        _errorStore = [NSMutableArray array];
        pthread_mutex_unlock(&_lock);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

// MARK: - Helpers
- (NSArray<NSError *> *)errors {
    pthread_mutex_lock(&_lock);
    NSArray *errors = [self.errorStore copy];
    pthread_mutex_unlock(&_lock);
    return errors;
}

- (void)addError:(NSError *)error {
    if (!error) {
        return;
    }

    pthread_mutex_lock(&_lock);
    [self.errorStore addObject:error];
    pthread_mutex_unlock(&_lock);
}

- (void)removeError:(NSError *)error {
    if (!error) {
        return;
    }

    pthread_mutex_lock(&_lock);
    [self.errorStore removeObject:error];
    pthread_mutex_unlock(&_lock);
}

- (void)removeAllErrors {
    pthread_mutex_lock(&_lock);
    [self.errorStore removeAllObjects];
    pthread_mutex_unlock(&_lock);
}

@end
