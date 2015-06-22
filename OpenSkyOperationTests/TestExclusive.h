/*!
 * TestExclusive.h
 * OpenSkyOperation
 *
 * Copyright (c) 2015 OpenSky, LLC
 *
 * Created by Skylar Schipper on 6/22/15
 */

#ifndef OpenSkyOperation_TestExclusive_h
#define OpenSkyOperation_TestExclusive_h

#import <OpenSkyOperation/OpenSkyOperation.h>

@interface TestExclusive : OSOOperation <OSOExclusiveOperation>

@property (nonatomic, copy) void(^exec)(void);

@end

#endif
