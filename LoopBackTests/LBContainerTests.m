//
//  LBContainerTests.m
//  LoopBack
//
//  Created by Stephen Hess on 2/7/14.
//  Copyright (c) 2014 StrongLoop. All rights reserved.
//

#import "LBContainerTests.h"

#import "LBContainer.h"
#import "LBRESTAdapter.h"

@interface LBContainerTests ()

@property (nonatomic) LBContainerRepository *repository;

@end

@implementation LBContainerTests

/**
 * Create the default test suite to control the order of test methods
 */
+ (id)defaultTestSuite {
    SenTestSuite *suite = [SenTestSuite testSuiteWithName:@"TestSuite for LBContainer."];
    [suite addTest:[self testCaseWithSelector:@selector(testGetAll)]];
    [suite addTest:[self testCaseWithSelector:@selector(testGetByName)]];
    [suite addTest:[self testCaseWithSelector:@selector(testCreate)]];
    [suite addTest:[self testCaseWithSelector:@selector(testRemove)]];
    return suite;
}


- (void)setUp {
    [super setUp];
    
    LBRESTAdapter *adapter = [LBRESTAdapter adapterWithURL:[NSURL URLWithString:@"http://localhost:3000"]];
    self.repository = (LBContainerRepository*)[adapter repositoryWithClass:[LBContainerRepository class]];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testGetAll {
    ASYNC_TEST_START
    [self.repository getAllContainersWithSuccess:^(NSArray *containers) {
        STAssertNotNil(containers, @"No containers returned.");
        STAssertTrue(containers.count >= 2, [NSString stringWithFormat:@"Invalid # of containers returned: %lu", (unsigned long)containers.count]);
        STAssertTrue([[containers[0] class] isSubclassOfClass:[LBContainer class]], @"Invalid class.");
        STAssertEqualObjects(containers[0][@"name"], @"container1", @"Invalid name");
        STAssertEqualObjects(containers[1][@"name"], @"container2", @"Invalid name");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testGetByName {
    ASYNC_TEST_START
    [self.repository getContainerWithName:@"container1" success:^(LBContainer *container) {
        STAssertNotNil(container, @"Container not found.");
        STAssertEqualObjects(container.name, @"container1", @"Invalid name");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testCreate {
    ASYNC_TEST_START
    LBContainer *container = [self.repository createContainerWithName:@"containerTest"];
    [container saveWithSuccess:^{
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testRemove {
    ASYNC_TEST_START
    [self.repository getContainerWithName:@"containerTest" success:^(LBContainer *container) {
        STAssertNotNil(container, @"Container not found.");
        [container deleteWithSuccess:^(void) {
            ASYNC_TEST_SIGNAL
        }failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

@end
