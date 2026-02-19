//
//  DeviceCheckBypass.m
//  Bypasses local DeviceCheck failures for LiveContainer
//
//  Compile this into a .dylib and inject it.
//

#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>
#import <objc/runtime.h>

// Helper Logger
#define DC_LOG(fmt, ...) NSLog(@"[DeviceCheckBypass] " fmt, ##__VA_ARGS__)

// -------------------------------------------------------------------------
// 1. Hook DCDevice (The older API)
// -------------------------------------------------------------------------

@interface DCDevice (Hooks)
- (BOOL)isSupported;
- (void)generateTokenWithCompletionHandler:(void(^)(NSData * _Nullable, NSError * _Nullable))completion;
@end

// Fake implementation for generateToken
void hooked_generateToken(id self, SEL _cmd, void (^completion)(NSData *, NSError *)) {
    DC_LOG(@"App requested DeviceCheck Token. Generating fake token...");
    
    // Create a dummy token (just random bytes)
    const char *bytes = "FakeDeviceCheckTokenForLiveContainer";
    NSData *fakeData = [NSData dataWithBytes:bytes length:strlen(bytes)];
    
    // Call the completion block with SUCCESS (Data, No Error)
    if (completion) {
        completion(fakeData, nil);
    }
}

// Fake implementation for isSupported
BOOL hooked_isSupported(id self, SEL _cmd) {
    DC_LOG(@"App asked if DeviceCheck is supported. Returning YES.");
    return YES;
}

// -------------------------------------------------------------------------
// 2. Hook DCAppAttestService (The newer API - likely what Red Bull uses)
// -------------------------------------------------------------------------

@interface DCAppAttestService : NSObject
@end

// Fake implementation for attestKey
void hooked_attestKey(id self, SEL _cmd, id keyId, id clientDataHash, void (^completion)(id, NSError *)) {
    DC_LOG(@"App requested AppAttest Key Attestation. Spoofing success...");
    
    // Create a dummy attestation object (random bytes)
    const char *bytes = "FakeAttestationObject";
    NSData *fakeAttestation = [NSData dataWithBytes:bytes length:strlen(bytes)];
    
    if (completion) {
        completion(fakeAttestation, nil);
    }
}

// Fake implementation for generateKey
void hooked_generateKey(id self, SEL _cmd, void (^completion)(NSString *, NSError *)) {
    DC_LOG(@"App requested new AppAttest Key. Returning fake Key ID...");
    
    NSString *fakeKeyId = @"FakeKeyID_123456789";
    
    if (completion) {
        completion(fakeKeyId, nil);
    }
}

// -------------------------------------------------------------------------
// 3. Constructor to Apply Hooks
// -------------------------------------------------------------------------

__attribute__((constructor))
static void DeviceCheckBypassInit(void) {
    DC_LOG(@"Loaded! Hooking DeviceCheck and AppAttest...");

    // Hook DCDevice
    Class dcClass = objc_getClass("DCDevice");
    if (dcClass) {
        // Hook isSupported
        Method isSupportedMethod = class_getClassMethod(dcClass, @selector(isSupported));
        method_setImplementation(isSupportedMethod, (IMP)hooked_isSupported);
        
        // Hook generateTokenWithCompletionHandler:
        Method genTokenMethod = class_getInstanceMethod(dcClass, @selector(generateTokenWithCompletionHandler:));
        method_setImplementation(genTokenMethod, (IMP)hooked_generateToken);
    }
    
    // Hook DCAppAttestService
    Class attClass = objc_getClass("DCAppAttestService");
    if (attClass) {
        // Hook generateKeyWithCompletionHandler:
        Method genKeyMethod = class_getInstanceMethod(attClass, @selector(generateKeyWithCompletionHandler:));
        if (genKeyMethod) method_setImplementation(genKeyMethod, (IMP)hooked_generateKey);
        
        // Hook attestKey:clientDataHash:completionHandler:
        Method attestMethod = class_getInstanceMethod(attClass, @selector(attestKey:clientDataHash:completionHandler:));
        if (attestMethod) method_setImplementation(attestMethod, (IMP)hooked_attestKey);
    }
}