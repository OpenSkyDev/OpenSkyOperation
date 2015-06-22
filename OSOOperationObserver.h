//
//  OSOOperationObserver.h
//  OpenSkyOperation
//
//  Created by Skylar Schipper on 6/20/15.
//  Copyright © 2015 OpenSky, LLC. All rights reserved.
//

#ifndef OpenSkyOperation_OSOOperationObserver_h
#define OpenSkyOperation_OSOOperationObserver_h

@import Foundation;

@class OSOOperation;

NS_ASSUME_NONNULL_BEGIN

@protocol OSOOperationObserver <NSObject>

- (void)operationDidStart:(__kindof OSOOperation *)operation;

- (void)operation:(__kindof OSOOperation *)operation didFinishWithErrors:(nullable NSArray<NSError *> *)errors;

@end

NS_ASSUME_NONNULL_END


#endif 
