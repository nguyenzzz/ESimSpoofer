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
// 1. Fake Implementations for DCDevice (Older API)
// -------------------------------------------------------------------------

void hooked_generateToken(id self, SEL _cmd, void (^completion)(NSData *, NSError *)) {
    DC_LOG(@"App requested DeviceCheck Token. Generating fake token...");
    
    // Create a dummy token 
    const char *bytes = "FakeDeviceCheckTokenForLiveContainer";
    NSData *fakeData = [NSData dataWithBytes:bytes length:strlen(bytes)];
    
    if (completion) {
        completion(fakeData, nil);
    }
}

BOOL hooked_isSupported(id self, SEL _cmd) {
    DC_LOG(@"App asked if DeviceCheck/AppAttest is supported. Returning YES.");
    return YES;
}

// -------------------------------------------------------------------------
// 2. Fake Implementations for DCAppAttestService (Newer API)
// -------------------------------------------------------------------------

void hooked_attestKey(id self, SEL _cmd, id keyId, id clientDataHash, void (^completion)(id, NSError *)) {
    DC_LOG(@"App requested AppAttest Key Attestation. Spoofing success...");
    
    // Create a dummy attestation object
    const char *bytes = "FakeAttestationObject";
    NSData *fakeAttestation = [NSData dataWithBytes:bytes length:strlen(bytes)];
    
    if (completion) {
        completion(fakeAttestation, nil);
    }
}

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
        // isSupported is an instance method
        Method isSupportedMethod = class_getInstanceMethod(dcClass, @selector(isSupported));
        if (isSupportedMethod) method_setImplementation(isSupportedMethod, (IMP)hooked_isSupported);
        
        Method genTokenMethod = class_getInstanceMethod(dcClass, @selector(generateTokenWithCompletionHandler:));
        if (genTokenMethod) method_setImplementation(genTokenMethod, (IMP)hooked_generateToken);
    }
    
    // Hook DCAppAttestService
    Class attClass = objc_getClass("DCAppAttestService");
    if (attClass) {
        // AppAttest also has an isSupported instance method we should hook
        Method isSupportedAttest = class_getInstanceMethod(attClass, @selector(isSupported));
        if (isSupportedAttest) method_setImplementation(isSupportedAttest, (IMP)hooked_isSupported);

        Method genKeyMethod = class_getInstanceMethod(attClass, @selector(generateKeyWithCompletionHandler:));
        if (genKeyMethod) method_setImplementation(genKeyMethod, (IMP)hooked_generateKey);
        
        Method attestMethod = class_getInstanceMethod(attClass, @selector(attestKey:clientDataHash:completionHandler:));
        if (attestMethod) method_setImplementation(attestMethod, (IMP)hooked_attestKey);
    }
}