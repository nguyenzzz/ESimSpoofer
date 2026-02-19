//
//  UUIDSpoofer.m
//  Randomizes the Identifier For Vendor (IDFV)
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define UUID_LOG(fmt, ...) NSLog(@"[UUIDSpoofer] " fmt, ##__VA_ARGS__)

// We store the fake UUID here so it stays the same while the app is running.
// It will generate a new random one the next time you close and reopen the app.
static NSUUID *spoofedIDFV = nil;

// 1. The fake implementation
NSUUID *hooked_identifierForVendor(id self, SEL _cmd) {
    if (!spoofedIDFV) {
        // Generate a fresh, random UUID
        spoofedIDFV = [NSUUID UUID]; 
        UUID_LOG(@"Generated new random IDFV: %@", spoofedIDFV.UUIDString);
    } else {
        UUID_LOG(@"Returning spoofed IDFV: %@", spoofedIDFV.UUIDString);
    }
    
    return spoofedIDFV;
}

// 2. The constructor that applies the hook
__attribute__((constructor))
static void UUIDSpooferInit(void) {
    UUID_LOG(@"Loaded! Preparing to hook UIDevice...");

    Class targetClass = objc_getClass("UIDevice");
    if (!targetClass) {
        UUID_LOG(@"Error: UIDevice class not found.");
        return;
    }

    // Hook the identifierForVendor instance method
    SEL originalSelector = @selector(identifierForVendor);
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    
    if (originalMethod) {
        method_setImplementation(originalMethod, (IMP)hooked_identifierForVendor);
        UUID_LOG(@"Success: identifierForVendor is now hooked.");
    } else {
        UUID_LOG(@"Error: identifierForVendor method not found.");
    }
}