//
//  OpenSkyOperationTests.m
//  OpenSkyOperationTests
//
//  Created by Skylar Schipper on 6/20/15.
//  Copyright © 2015 OpenSky, LLC. All rights reserved.
//

@import XCTest;

#import "TestExclusive.h"

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

- (void)testExclusiveOperations {
    OSOOperationQueue *queue = [[OSOOperationQueue alloc] initWithName:@"test_queue"];
    queue.maxConcurrentOperationCount = 10;

    NSUInteger __block value = 0;

    {
        XCTestExpectation *wait = [self expectationWithDescription:@"test"];
        TestExclusive *exlusive = [[TestExclusive alloc] init];
        exlusive.exec = ^ {
            XCTAssertEqual(value, 0);
            value++;
            [wait fulfill];
        };
        [queue addOperation:exlusive];
    }
    {
        XCTestExpectation *wait = [self expectationWithDescription:@"test"];
        TestExclusive *exlusive = [[TestExclusive alloc] init];
        exlusive.exec = ^ {
            XCTAssertEqual(value, 1);
            value++;
            [wait fulfill];
        };
        [queue addOperation:exlusive];
    }
    {
        XCTestExpectation *wait = [self expectationWithDescription:@"test"];
        TestExclusive *exlusive = [[TestExclusive alloc] init];
        exlusive.exec = ^ {
            XCTAssertEqual(value, 2);
            value++;
            [wait fulfill];
        };
        [queue addOperation:exlusive];
    }
    {
        XCTestExpectation *wait = [self expectationWithDescription:@"test"];
        TestExclusive *exlusive = [[TestExclusive alloc] init];
        exlusive.exec = ^ {
            XCTAssertEqual(value, 3);
            value++;
            [wait fulfill];
        };
        [queue addOperation:exlusive];
    }
    



    [self waitForExpectationsWithTimeout:1.1 handler:^(NSError * __nullable error) {
        XCTAssertNil(error);
    }];

    XCTAssertEqual(value, 4);
}

@end
