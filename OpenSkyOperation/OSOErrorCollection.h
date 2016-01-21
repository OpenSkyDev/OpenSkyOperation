/*!
 * OSOErrorCollection.h
 * OpenSkyOperation
 *
 * Copyright (c) 2016 OpenSky, LLC
 *
 * Created by Skylar Schipper on 1/21/16
 */

#ifndef OpenSkyOperation_OSOErrorCollection_h
#define OpenSkyOperation_OSOErrorCollection_h

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/**
 *  This can be used to store a collection of errors.
 *
 *  Use this class if your operation can generate errors from other systems at other times.  You can safely add errors from other threads to this collection.
 */
@interface OSOErrorCollection : NSObject

/**
 *  All the errors from the collection.  Returns a copy of the backing store every time.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSError *> *errors;

/**
 *  Add an error to the collection
 *
 *  @param error The error to add.  No-op if nil.
 */
- (void)addError:(nullable NSError *)error;

/**
 *  Remove an error from the collection
 *
 *  @param error The error to remove.  No-op if nil.
 */
- (void)removeError:(nullable NSError *)error;

/**
 *  Remove all errors from the collection
 */
- (void)removeAllErrors;

@end

NS_ASSUME_NONNULL_END

#endif
