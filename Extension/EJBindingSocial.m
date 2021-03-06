#import "EJBindingSocial.h"


@implementation EJBindingSocial


- (void)invokeAndUnprotectPostCallback:(JSObjectRef)callback statusCode:(NSInteger)statusCode responseObject:(NSObject *)responseObject {
    if(!callback){
        return;
    }
	JSGlobalContextRef ctx = scriptView.jsGlobalContext;
	JSValueRef arg = JSValueMakeNull(ctx);
	if (responseObject == NULL) {
        // TODO
	}
	else if ([responseObject isKindOfClass:[NSString class]]) {
		JSStringRef jsStr = JSStringCreateWithUTF8CString([(NSString *)responseObject UTF8String]);
		arg = JSValueMakeString(ctx, (JSStringRef)jsStr);
	}
	else {
		arg = NSObjectToJSValue(scriptView.jsGlobalContext, responseObject);
	}
	[scriptView invokeCallback:callback thisObject:NULL argc:2 argv:
	 (JSValueRef[]) {
	     JSValueMakeNumber(scriptView.jsGlobalContext, statusCode), arg
	 }
	];
	JSValueUnprotect(scriptView.jsGlobalContext, callback);
}

- (id)initWithContext:(JSContextRef)ctx argc:(size_t)argc argv:(const JSValueRef[])argv {
	if (self = [super initWithContext:ctx argc:argc argv:argv]) {
		_accountStore = [[ACAccountStore alloc] init];
	}
	return self;
}

- (void)dealloc {
    [_accountStore release];
    [super dealloc];
}

- (BOOL)addMultipartData:(NSString *)imgSrc request:(SLRequest *)request dataName:(NSString *)dataName {
    imgSrc = [scriptView pathForResource:imgSrc];
	UIImage *img = [UIImage imageNamed:imgSrc];
	if ([imgSrc hasSuffix:@".png"]) {
		NSData *imageData = UIImagePNGRepresentation(img);
		[request addMultipartData:imageData
		                 withName:dataName
		                     type:@"image/png"
		                 filename:@"image.png"];
	}
	else if ([imgSrc hasSuffix:@".gif"]) {
		NSData *imageData = UIImagePNGRepresentation(img);
		[request addMultipartData:imageData
		                 withName:dataName
		                     type:@"image/gif"
		                 filename:@"image.gif"];
	}
	else if ([imgSrc hasSuffix:@".jpg"] || [imgSrc hasSuffix:@".jpeg"]) {
		NSData *imageData = UIImageJPEGRepresentation(img, 0.9f);
		[request addMultipartData:imageData
		                 withName:dataName
		                     type:@"image/jpeg"
		                 filename:@"image.jpg"];
	}
	else {
		return FALSE;
	}
	return TRUE;
}

- (SLRequest *)createSLRequest:(NSString *)snsName message:(NSString *)message imgSrc:(NSString *)imgSrc {
	SLRequest *request = NULL;
	snsName = [snsName lowercaseString];
	if ([snsName isEqualToString:@"twitter"]) {
		NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"];
		NSDictionary *params = @{ @"status" : message };
		request = [SLRequest requestForServiceType:SLServiceTypeTwitter
		                             requestMethod:SLRequestMethodPOST
		                                       URL:url
		                                parameters:params];

		if (imgSrc) {
			[self addMultipartData:imgSrc request:request dataName:@"media[]"];
		}
	}
	if ([snsName isEqualToString:@"facebook"]) {
		NSURL *url = [NSURL URLWithString:@"https://graph.facebook.com/me/photos"];
		NSDictionary *params = @{ @"message" : message };
		request = [SLRequest requestForServiceType:SLServiceTypeFacebook
		                             requestMethod:SLRequestMethodPOST
		                                       URL:url
		                                parameters:params];

		if (imgSrc) {
			[self addMultipartData:imgSrc request:request dataName:@"source"];
		}
	}

	if ([snsName isEqualToString:@"sinaweibo"]) {
		NSURL *url = [NSURL URLWithString:@"http://api.t.sina.com.cn/statuses/upload.json"];

		NSDictionary *params = @{ @"status" : message };
		request = [SLRequest requestForServiceType:SLServiceTypeSinaWeibo
		                             requestMethod:SLRequestMethodPOST
		                                       URL:url
		                                parameters:params];
		if (imgSrc) {
			[self addMultipartData:imgSrc request:request dataName:@"pic"];
		}
	}

	return request;
}

- (NSDictionary *)createRequestOption:(NSString *)snsName appKey:(NSString *)appKey {
	NSDictionary *options = nil;

	if ([snsName isEqualToString:@"facebook"] && appKey != nil) {
		if (appKey != nil) {
			options = @{ ACFacebookAppIdKey:appKey,
				         ACFacebookPermissionsKey: @[@"publish_stream", @"publish_actions"],
				         ACFacebookAudienceKey:ACFacebookAudienceEveryone };
		}
		else {
			options = @{ ACFacebookPermissionsKey: @[@"publish_stream", @"publish_actions"],
				         ACFacebookAudienceKey:ACFacebookAudienceEveryone };
		}
	}

	return options;
}

- (void)prepareForFacebook:(NSString *)snsName message:(NSString *)message imgSrc:(NSString *)imgSrc appKey:(NSString *)appKey callback:(JSObjectRef)callback {
	// separate request for read and writes
	ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	NSDictionary *readOptions = nil;
	if (appKey != nil) {
		readOptions = @{ ACFacebookAppIdKey:appKey,
			             ACFacebookPermissionsKey: @[@"email", @"read_stream", @"user_photos"],
			             ACFacebookAudienceKey:ACFacebookAudienceEveryone };
	}
	else {
		readOptions = @{ ACFacebookPermissionsKey: @[@"email", @"read_stream", @"user_photos"],
			             ACFacebookAudienceKey:ACFacebookAudienceEveryone };
	}
	[self.accountStore requestAccessToAccountsWithType:accountType options:readOptions completion: ^(BOOL granted, NSError *error) {
	    if (granted) {
	        [self post:snsName message:message imgSrc:imgSrc appKey:appKey callback:callback];
		}
	    else {
	        //Fail gracefully...
	        NSLog(@"error getting permission %@", error);
	        [self invokeAndUnprotectPostCallback:callback statusCode:error.code responseObject:[error localizedDescription]];
		}
	}];
}

- (void)post:(NSString *)snsName message:(NSString *)message imgSrc:(NSString *)imgSrc appKey:(NSString *)appKey callback:(JSObjectRef)callback {
	ACAccountType *accountType = NULL;

	snsName = [snsName lowercaseString];
	if ([snsName isEqualToString:@"twitter"]) {
		accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
	}
	else if ([snsName isEqualToString:@"facebook"]) {
		accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	}
	else if ([snsName isEqualToString:@"sinaweibo"]) {
		accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierSinaWeibo];
	}
	if (!accountType) {
		NSLog(@"%@ NOT found.", snsName);
        [self invokeAndUnprotectPostCallback:callback statusCode:-1 responseObject:NULL];
        return;
	}

	SLRequestHandler requestHandler = ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
		NSInteger statusCode = urlResponse.statusCode;
		if (responseData) {
			if (statusCode >= 200 && statusCode < 300) {
				NSDictionary *postResponseData = [NSJSONSerialization JSONObjectWithData:responseData
				                                                                 options:NSJSONReadingMutableContainers
				                                                                   error:NULL];
				NSLog(@"[SUCCESS] %@ Server responded: status code %ld", snsName, (long)statusCode);
				[self invokeAndUnprotectPostCallback:callback statusCode:statusCode responseObject:postResponseData];
			}
			else {
				NSLog(@"[ERROR] %@ Server responded: status code %ld %@", snsName, (long)statusCode,
				      [NSHTTPURLResponse localizedStringForStatusCode:statusCode]);
				NSString *responseText = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

				[self invokeAndUnprotectPostCallback:callback statusCode:statusCode responseObject:responseText];
				[responseText release];
			}
		}
		else {
			NSLog(@"[ERROR] An error occurred while posting: %@", [error localizedDescription]);
			responseData = NULL;
			[self invokeAndUnprotectPostCallback:callback statusCode:error.code responseObject:[error localizedDescription]];
		}
	};

	ACAccountStoreRequestAccessCompletionHandler accountStoreHandler = ^(BOOL granted, NSError *error) {
		if (granted) {
			NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
			if ([accounts count] > 0) {
				SLRequest *request = [self createSLRequest:snsName message:message imgSrc:imgSrc];
				[request setAccount:[accounts lastObject]];
				[request performRequestWithHandler:requestHandler];
			}
			else {
				NSLog(@"Not granted by SNS");
				[self invokeAndUnprotectPostCallback:callback statusCode:0 responseObject:@"Not granted by SNS"];
			}
		}
		else {
			NSLog(@"[ERROR] An error occurred while asking for user authorization: %@",
			      [error localizedDescription]);
			[self invokeAndUnprotectPostCallback:callback statusCode:error.code responseObject:[error localizedDescription]];
		}
	};


	NSDictionary *options = [self createRequestOption:snsName appKey:appKey];

	[self.accountStore requestAccessToAccountsWithType:accountType
	                                           options:options
	                                        completion:accountStoreHandler];
}

- (void)showPostDialog:(NSString *)snsName message:(NSString *)message imgSrc:(NSString *)imgSrc shareUrl:(NSString *)shareUrl callback:(JSObjectRef)callback {
	SLComposeViewController *sns = NULL;
	snsName = [snsName lowercaseString];
	if ([snsName isEqualToString:@"twitter"] && [SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
		sns = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
	}
	else if ([snsName isEqualToString:@"facebook"] && [SLComposeViewController isAvailableForServiceType:SLServiceTypeFacebook]) {
		sns = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
	}
	else if ([snsName isEqualToString:@"sinaweibo"] && [SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo]) {
		sns = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
	}
    
	if (sns) {
		[sns setInitialText:message];
		if (imgSrc) {
            imgSrc = [scriptView pathForResource:imgSrc];
            NSData *pixels = [NSData dataWithContentsOfFile:imgSrc];
            UIImage *img = [[UIImage alloc] initWithData:pixels];
			if (img) {
				bool ok = [sns addImage:img];
                [img release];
				NSLog(@"addImage %d", ok);
			}
		}
		if (shareUrl) {
			[sns addURL:[NSURL URLWithString:shareUrl]];
		}
		[sns setCompletionHandler: ^(SLComposeViewControllerResult result) {
		    NSInteger statusCode = 0;
		    switch (result) {
				case SLComposeViewControllerResultDone:
					statusCode = 200;
					NSLog(@"Done");
					break;

				case SLComposeViewControllerResultCancelled:
					statusCode = 0;
					NSLog(@"Cancelled");
					break;

				default:
					statusCode = 500;
					NSLog(@"Other Exception");
					break;
			}
		    [sns dismissViewControllerAnimated:YES completion:nil];
		    NSString *responseText = NULL;
		    [self invokeAndUnprotectPostCallback:callback statusCode:statusCode responseObject:responseText];
		}];

		[scriptView.window.rootViewController presentViewController:sns animated:YES completion: ^{
		    // on displayed
            NSLog(@"On Displayed");
		}];

    }else{
        NSLog(@"%@ NOT found.", snsName);
        [self invokeAndUnprotectPostCallback:callback statusCode:-1 responseObject:NULL];
        return;
    }
}

EJ_BIND_FUNCTION(post, ctx, argc, argv)
{
	if (![SLComposeViewController class]) {
		NSLog(@"This iOS does NOT include Social.framework.");
		return JSValueMakeBoolean(ctx, false);
	}
	NSString *snsName = JSValueToNSString(ctx, argv[0]);
	NSString *message = JSValueToNSString(ctx, argv[1]);
	NSString *imgSrc = JSValueToNSString(ctx, argv[2]);
	NSString *appKey;
	JSObjectRef callback;
	if (argc > 4) {
		appKey = JSValueToNSString(ctx, argv[3]);
		callback = JSValueToObject(ctx, argv[4], NULL);
	}
	else {
		appKey = NULL;
		callback = JSValueToObject(ctx, argv[3], NULL);
	}

	if (callback) {
		JSValueProtect(ctx, callback);
	}

	snsName = [snsName lowercaseString];
	if ([snsName isEqualToString:@"facebook"]) {
		[self prepareForFacebook:snsName message:message imgSrc:imgSrc appKey:appKey callback:callback];
	}
	else {
		[self post:snsName message:message imgSrc:imgSrc appKey:appKey callback:callback];
	}

	return JSValueMakeBoolean(ctx, true);
}


// snsName ,message, imgSrc, shareUrl, callback
EJ_BIND_FUNCTION(showPostDialog, ctx, argc, argv)
{
	if (![SLComposeViewController class]) {
		NSLog(@"This iOS does NOT include Social.framework.");
		return JSValueMakeBoolean(ctx, false);
	}
	NSString *snsName = JSValueToNSString(ctx, argv[0]);
	NSString *message = JSValueToNSString(ctx, argv[1]);
    NSString *imgSrc = nil;
    NSString *shareUrl = nil;
    JSObjectRef callback = nil;
    
    if (argc > 2){
        imgSrc = JSValueToNSString(ctx, argv[2]);
        if (argc > 3){
            shareUrl = JSValueToNSString(ctx, argv[3]);
        }
        if (argc > 4){
            callback = JSValueToObject(ctx, argv[4], NULL);
            if (callback) {
                JSValueProtect(ctx, callback);
            }
        }
    }
   
	snsName = [snsName lowercaseString];
	[self showPostDialog:snsName message:message imgSrc:imgSrc shareUrl:shareUrl callback:callback];

	return JSValueMakeBoolean(ctx, true);
}


// message, imgSrc, callback
EJ_BIND_FUNCTION(openShare, ctx, argc, argv){
    
    NSString *message = JSValueToNSString(ctx, argv[0]);
    NSString *imgSrc = nil;
    JSObjectRef callback = nil;
    
    if (argc > 1){
        imgSrc = JSValueToNSString(ctx, argv[1]);
        if (argc > 2){
            callback = JSValueToObject(ctx, argv[2], NULL);
            if (callback) {
                JSValueProtect(ctx, callback);
            }
        }
    }

    UIActivityViewController *activityViewController = nil;
    if (imgSrc) {
        imgSrc = [scriptView pathForResource:imgSrc];
        NSData *pixels = [NSData dataWithContentsOfFile:imgSrc];
        UIImage *shareImg = [[UIImage alloc] initWithData:pixels];
        if (shareImg) {
            NSLog(@"addImage %d", true);
            activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[message, shareImg] applicationActivities:nil];
            [shareImg release];
        }
    }
    
    if (!activityViewController){
        activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[message] applicationActivities:nil];
    }
    
    activityViewController.popoverPresentationController.sourceView = scriptView.window.rootViewController.view;

    [scriptView.window.rootViewController
         presentViewController:activityViewController
         animated:YES
         completion:^{
             if (callback){
                 [scriptView invokeCallback:callback thisObject:NULL argc:0 argv:nil];
                 JSValueUnprotect(scriptView.jsGlobalContext, callback);
             }
         }
     ];
    
    return NULL;
    
}

@end
