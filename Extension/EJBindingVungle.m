#import "EJBindingVungle.h"

@implementation EJBindingVungle


- (id)initWithContext:(JSContextRef)ctx argc:(size_t)argc argv:(const JSValueRef[])argv {
	if (self = [super initWithContext:ctx argc:argc argv:argv]) {
		if (argc > 0) {
			appID = [JSValueToNSString(ctx, argv[0]) retain];
		}
		else {
			NSLog(@"Error: Must set appID");
            return self;
		}
        
        loading = false;
        hookBeforeShow = nil;
        hookAfterClose = nil;
        
        sdk = [VungleSDK sharedSDK];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [sdk setDelegate:self];
            [sdk startWithAppId:appID];
        }];

	}

	return self;
}

- (void)createWithJSObject:(JSObjectRef)obj scriptView:(EJJavaScriptView *)view {
	[super createWithJSObject:obj scriptView:view];
}

- (void)dealloc {
	[sdk setDelegate:nil];
	[sdk release];

    if (hookBeforeShow) {
        JSValueUnprotect(scriptView.jsGlobalContext, hookBeforeShow);
        hookBeforeShow = nil;
    }

    if (hookAfterClose) {
        JSValueUnprotect(scriptView.jsGlobalContext, hookAfterClose);
        hookAfterClose = nil;
    }
    
	[super dealloc];
}

-(void)vungleSDKwillShowAd {
    NSLog(@"vungleSDKwillShowAd");
    if (hookBeforeShow) {
        [scriptView invokeCallback: hookBeforeShow thisObject: NULL argc: 0 argv: NULL];
        JSValueUnprotect(scriptView.jsGlobalContext, hookBeforeShow);
        hookBeforeShow = nil;
    }
    [self triggerEvent:@"beforeShow"];
}

- (void)vungleSDKwillCloseAdWithViewInfo:(NSDictionary *)viewInfo willPresentProductSheet:(BOOL)willPresentProductSheet {
    NSLog(@"vungleSDKwillCloseAdWithViewInfo %d", willPresentProductSheet);

//    "playTime":15,"didDownload":false,"videoLength":15,"completedView":true

    JSValueRef jsViewInfo = NSObjectToJSValue(scriptView.jsGlobalContext,
                                               @{
                                                 @"playTime": [viewInfo objectForKey:@"playTime"],
                                                 @"videoLength": [viewInfo objectForKey:@"videoLength"],
                                                 @"completedView": [viewInfo objectForKey:@"completedView"],
                                                 @"didDownload": [viewInfo objectForKey:@"didDownload"],
                                                 @"willPresentProductSheet": @(willPresentProductSheet)
                                                });
    JSValueRef params[] = { jsViewInfo };

    if (hookAfterClose) {
        [scriptView invokeCallback: hookAfterClose thisObject: NULL argc: 1 argv: params];
        JSValueUnprotect(scriptView.jsGlobalContext, hookAfterClose);
        hookAfterClose = nil;
    }
    
    [self triggerEvent:@"close" argc:1 argv:params];
}

- (void)vungleSDKwillCloseProductSheet:(id)productSheet {
    NSLog(@"vungleSDKwillCloseProductSheet");
    [self triggerEvent:@"closeProductSheet"];
}


EJ_BIND_GET(appID, ctx)
{
	return NSStringToJSValue(ctx, appID);
}


EJ_BIND_GET(muted, ctx)
{
    return NSStringToJSValue(ctx, sdk.muted);
}

EJ_BIND_SET(muted, ctx, value)
{
    sdk.muted = JSValueToBoolean(ctx, value);
}


EJ_BIND_GET(isReady, ctx)
{
    return JSValueMakeBoolean(ctx, sdk.isAdPlayable);
}

EJ_BIND_FUNCTION(setLoggingEnabled, ctx, argc, argv)
{
    [sdk setLoggingEnabled:JSValueToBoolean(ctx, argv[0])];
    return NULL;
}

EJ_BIND_FUNCTION(show, ctx, argc, argv)
{

    if (hookBeforeShow) {
        JSValueUnprotect(scriptView.jsGlobalContext, hookBeforeShow);
        hookBeforeShow = nil;
    }
    
    if (hookAfterClose) {
        JSValueUnprotect(scriptView.jsGlobalContext, hookAfterClose);
        hookAfterClose = nil;
    }

    /*
     Options ( VunglePlayAdOptionKey + key ) :
     Incentivized    boolean
     IncentivizedAlertTitleText      string
     IncentivizedAlertBodyText       string
     IncentivizedAlertCloseButtonText        string
     IncentivizedAlertContinueButtonText     string
     Orientations        string
     Placement       string
     User        string
     * ExtraInfoDictionary  (don't support)
    */
    
    NSMutableDictionary* options = nil;
    
    JSObjectRef jsOptions;
    if (argc > 0){
        jsOptions = JSValueToObject(ctx, argv[0], NULL);
        NSDictionary *inOptions = (NSDictionary *)JSValueToNSObject(ctx, jsOptions);
        NSEnumerator *keys = [inOptions keyEnumerator];
        options = [[NSMutableDictionary alloc] init];
        NSString *prefix = @"VunglePlayAdOptionKey";
        id keyId;
        while ((keyId = [keys nextObject])) {
            NSString *key = (NSString *)keyId;
            NSString *value = (NSString *)[inOptions objectForKey:keyId];
            NSString *fullKey = [prefix stringByAppendingString:key];
            NSLog(@"key : %@, value: %@", fullKey, value);
            if ([key isEqualToString:@"Incentivized"]){
                [options setObject:@([[inOptions objectForKey:keyId] boolValue]) forKey:fullKey];
            }else if ([key isEqualToString:@"IncentivizedAlertTitleText"]){
                 [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"IncentivizedAlertBodyText"]){
                [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"IncentivizedAlertCloseButtonText"]){
                [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"IncentivizedAlertContinueButtonText"]){
                [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"Orientations"]){
                if ([value isEqualToString:@"portrait"]){
                     [options setObject:@(UIInterfaceOrientationMaskPortrait) forKey:fullKey];
                }else if ([value isEqualToString:@"landscape"]){
                    [options setObject:@(UIInterfaceOrientationMaskLandscape) forKey:fullKey];
                }
            }else if ([key isEqualToString:@"Placement"]){
                [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"User"]){
                [options setObject:value forKey:fullKey];
            }else if ([key isEqualToString:@"beforeShow"]){
                JSStringRef funcName = JSStringCreateWithUTF8CString("beforeShow");
                JSValueRef jsFunc = JSObjectGetProperty(ctx, jsOptions, funcName, NULL);
                JSStringRelease(funcName);
                hookBeforeShow = JSValueToObject(ctx, jsFunc, NULL);
                if (hookBeforeShow) {
                    JSValueProtect(ctx, hookBeforeShow);
                }
            }else if ([key isEqualToString:@"afterClose"]){
                JSStringRef funcName = JSStringCreateWithUTF8CString("afterClose");
                JSValueRef jsFunc = JSObjectGetProperty(ctx, jsOptions, funcName, NULL);
                JSStringRelease(funcName);
                hookAfterClose = JSValueToObject(ctx, jsFunc, NULL);
                if (hookAfterClose) {
                    JSValueProtect(ctx, hookAfterClose);
                }
            }
        }
    }

    if (hookBeforeShow) {
        [scriptView invokeCallback: hookBeforeShow thisObject: NULL argc: 0 argv: NULL];
        JSValueUnprotect(scriptView.jsGlobalContext, hookBeforeShow);
        hookBeforeShow = nil;
    }
    
    NSError *error;

    if (options){
        [sdk playAd:scriptView.window.rootViewController withOptions:options error:&error];
        [options release];
    }else{
        [sdk playAd:scriptView.window.rootViewController error:&error];
    }


    if (error) {
        NSLog(@"Error encountered playing ad: %@", error);
        [self triggerEvent:@"error"];
        return scriptView->jsFalse;
    }
    
    return scriptView->jsTrue;

}



EJ_BIND_EVENT(beforeShow);
EJ_BIND_EVENT(close);
EJ_BIND_EVENT(closeProductSheet);
EJ_BIND_EVENT(error);


@end
