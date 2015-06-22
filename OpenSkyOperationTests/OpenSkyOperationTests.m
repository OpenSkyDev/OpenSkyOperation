//
//  OpenSkyOperationTests.m
//  OpenSkyOperationTests
//
//  Created by Skylar Schipper on 6/20/15.
//  Copyright © 2015 OpenSky, LLC. All rights reserved.
//

@import XCTest;
@import OpenSkyOperation;

@interface OpenSkyOperationTests : XCTestCase

@end

@implementation OpenSkyOperationTests

- (void)testOperationCompletion {
    OSOOperationQueue *queue = [[OSOOperationQueue alloc] initWithName:@"test_queue"];

    NSNumber __block *value = @0;

    XCTestExpectation *expect = [self expectationWithDescription:@"op"];

    OSOOperation *op = [[OSOOperation alloc] init];
    op.completionBlock = ^ {
        value = @1;
        [expect fulfill];
    };

    [queue addOperation:op];

    [self waitForExpectationsWithTimeout:0.01 handler:^(NSError * __nullable error) {
        XCTAssertNil(error);
    }];

    XCTAssertEqualObjects(value, @1);
}

@end
