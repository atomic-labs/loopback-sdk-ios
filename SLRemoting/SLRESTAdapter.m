/**
 * @file SLRESTAdapter.m
 *
 * @author Michael Schoonmaker
 * @copyright (c) 2013 StrongLoop. All rights reserved.
 */

#import "SLRESTAdapter.h"
#import "SLStreamParam.h"

#import <AFNetworking/AFNetworking.h>

static NSString * const DEFAULT_DEV_BASE_URL = @"http://localhost:3001";

@interface SLRESTAdapter() {
    AFHTTPRequestOperationManager *client;
}

@property (readwrite, nonatomic) BOOL connected;

- (void)requestWithPath:(NSString *)path
                   verb:(NSString *)verb
             parameters:(NSDictionary *)parameters
              multipart:(BOOL)multipart
           outputStream:(NSOutputStream *)outputStream
                success:(SLSuccessBlock)success
                failure:(SLFailureBlock)failure;

- (void)appendPartToMultiPartForm:(id <AFMultipartFormData>)formData
                   withParameters:(NSDictionary *)parameters;

@end

@implementation SLRESTAdapter

@synthesize connected;

- (instancetype)initWithURL:(NSURL *)url allowsInvalidSSLCertificate : (BOOL) allowsInvalidSSLCertificate {
    self = [super initWithURL:url allowsInvalidSSLCertificate:allowsInvalidSSLCertificate];

    if (self) {
        self.contract = [SLRESTContract contract];
    }

    return self;
}

- (void)connectToURL:(NSURL *)url {
    // Ensure terminal slash for baseURL path, so that NSURL +URLWithString:relativeToURL: works as expected
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@"/"];
    }

    client = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
    client.securityPolicy.allowInvalidCertificates = self.allowsInvalidSSLCertificate;

    self.connected = YES;

    client.requestSerializer = [AFJSONRequestSerializer serializer];
}

- (void)invokeStaticMethod:(NSString *)method
                parameters:(NSDictionary *)parameters
                   success:(SLSuccessBlock)success
                   failure:(SLFailureBlock)failure {

    [self invokeStaticMethod:method
                  parameters:parameters
                outputStream:nil
                     success:success
                     failure:failure];
}

- (void)invokeStaticMethod:(NSString *)method
                parameters:(NSDictionary *)parameters
              outputStream:(NSOutputStream *)outputStream
                   success:(SLSuccessBlock)success
                   failure:(SLFailureBlock)failure {
    
    NSAssert(self.contract, @"Invalid contract.");

    NSString *verb = [self.contract verbForMethod:method];
    NSString *path = [self.contract urlForMethod:method parameters:parameters];
    BOOL multipart = [self.contract multipartForMethod:method];

    [self requestWithPath:path
                     verb:verb
               parameters:parameters
                multipart:multipart
             outputStream:outputStream
                  success:success
                  failure:failure];
}

- (void)invokeInstanceMethod:(NSString *)method
       constructorParameters:(NSDictionary *)constructorParameters
                  parameters:(NSDictionary *)parameters
                     success:(SLSuccessBlock)success
                     failure:(SLFailureBlock)failure {

    [self invokeInstanceMethod:method
         constructorParameters:constructorParameters
                    parameters:parameters
                  outputStream:nil
                       success:success
                       failure:failure];
}

- (void)invokeInstanceMethod:(NSString *)method
       constructorParameters:(NSDictionary *)constructorParameters
                  parameters:(NSDictionary *)parameters
                outputStream:(NSOutputStream *)outputStream
                     success:(SLSuccessBlock)success
                     failure:(SLFailureBlock)failure {
    // TODO(schoon) - Break out and document error description.
    NSAssert(self.contract, @"Invalid contract.");

    NSMutableDictionary *combinedParameters = [NSMutableDictionary dictionary];
    [combinedParameters addEntriesFromDictionary:constructorParameters];
    [combinedParameters addEntriesFromDictionary:parameters];

    NSString *verb = [self.contract verbForMethod:method];
    NSString *path = [self.contract urlForMethod:method parameters:combinedParameters];
    BOOL multipart = [self.contract multipartForMethod:method];

    [self requestWithPath:path
                     verb:verb
               parameters:combinedParameters
                multipart:multipart
             outputStream:outputStream
                  success:success
                  failure:failure];
}

- (void)requestWithPath:(NSString *)path
                   verb:(NSString *)verb
             parameters:(NSDictionary *)parameters
              multipart:(BOOL)multipart
           outputStream:(NSOutputStream *)outputStream
                success:(SLSuccessBlock)success
                failure:(SLFailureBlock)failure {

    NSAssert(self.connected, SLAdapterNotConnectedErrorDescription);

    // Remove the leading / so that the path is treated as relative to the baseURL
    if ([path hasPrefix:@"/"]) {
        path = [path substringFromIndex:1];
    }

    AFHTTPRequestSerializer *serializer = client.requestSerializer;
    NSURL *URL = [NSURL URLWithString:path relativeToURL:client.baseURL];

    NSURLRequest *request;

    if (!multipart) {
        request = [serializer requestWithMethod:verb URLString:URL.absoluteString parameters:parameters error:NULL];
    } else {
        request = [serializer multipartFormRequestWithMethod:verb
                                                   URLString:URL.absoluteString
                                                  parameters:parameters
                                   constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                                       [self appendPartToMultiPartForm:formData
                                                        withParameters:parameters];
                                   } error:NULL];
    }

    AFHTTPRequestOperation *operation;
    // Synchronize the block so that the invocations of client's [un]registerHTTPOperationClass:
    // and HTTPRequestOperationWithRequest:success: methods become atomic.
    @synchronized(self) {
        operation = [client HTTPRequestOperationWithRequest:request
                                                    success:^(AFHTTPRequestOperation *operation,
                                                              id responseObject) {
            success(responseObject);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            failure(error);
        }];

        if (outputStream) {
            // The following is needed to force the received binary payload always go to the stream
            operation.responseSerializer = [AFHTTPResponseSerializer serializer];
            operation.outputStream = outputStream;
        }
    }

    [client.operationQueue addOperation:operation];
}

- (void)appendPartToMultiPartForm:(id <AFMultipartFormData>)formData
                   withParameters:(NSDictionary *)parameters {
    for (id key in parameters) {
        id value = parameters[key];

        if ([value isKindOfClass:[SLStreamParam class]]) {
            SLStreamParam *streamParam = (SLStreamParam *)value;
            [formData appendPartWithInputStream:streamParam.inputStream
                                           name:key
                                       fileName:streamParam.fileName
                                         length:streamParam.length
                                       mimeType:streamParam.contentType];
        } else {
            NSLog(@"%s: Ignored non SLStreamParam parameter %@ specified for multipart form",
                  __FUNCTION__, [value class]);
        }
    }
}

- (NSString*)accessToken
{
    return [client.requestSerializer valueForHTTPHeaderField:@"Authorization"];
}

- (void)setAccessToken:(NSString *)accessToken
{
    [client.requestSerializer setValue:accessToken forHTTPHeaderField:@"Authorization"];
}

@end
