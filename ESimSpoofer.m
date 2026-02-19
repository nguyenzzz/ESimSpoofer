//
//  ESimSpoofer.m
//  Spoofs eSIM support for LiveContainer apps
//
//  Compile this into a .dylib and inject it.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// FIXED: Use NSLog instead of syslog. 
// This handles the @"String" format correctly and fixes the compilation error.
#define ESIM_LOG(fmt, ...) NSLog(@"[ESimSpoofer] " fmt, ##__VA_ARGS__)

// Define the interface we want to hook so the compiler knows it exists
@interface CTCellularPlanProvisioning : NSObject
- (BOOL)supportsCellularPlan;
@end

// The function that will replace the original method
BOOL hooked_supportsCellularPlan(id self, SEL _cmd) {
    ESIM_LOG(@"App asked for eSIM support. Returning YES.");
    return YES;
}

// The Constructor: Runs automatically when the dylib is loaded
__attribute__((constructor))
static void ESimSpooferInit(void) {
    ESIM_LOG(@"Loaded! Preparing to hook CoreTelephony...");

    // 1. Get the class
    Class targetClass = objc_getClass("CTCellularPlanProvisioning");
    
    if (!targetClass) {
        // If CoreTelephony isn't loaded yet, we might miss it. 
        // Standard apps usually load it, but we log just in case.
        ESIM_LOG(@"Error: CTCellularPlanProvisioning class not found. Is CoreTelephony linked?");
        return;
    }

    // 2. Get the original selector
    SEL originalSelector = @selector(supportsCellularPlan);
    
    // 3. Add our hooked method implementation
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    
    if (originalMethod) {
        // Replace the implementation of the existing method with our C function
        method_setImplementation(originalMethod, (IMP)hooked_supportsCellularPlan);
        ESIM_LOG(@"Hook success: supportsCellularPlan is now TRUE.");
    } else {
        ESIM_LOG(@"Error: Original method supportsCellularPlan not found!");
    }
}