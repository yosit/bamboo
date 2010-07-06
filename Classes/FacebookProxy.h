#import "FBConnect/FBConnect.h"

// Facebook API
// all of these values need to be set in the client application
extern NSString* const kFBAPIKey;
extern NSString* const kFBAppSecret;

extern NSString* const kFBClientID;
extern NSString* const kFBRedirectURI;

@class GraphAPI;

@interface FBDataDialog : FBDialog
{
	NSData* _webPageData;
}

@property (nonatomic, retain) NSData* webPageData;

@end


@interface FacebookProxy : NSObject <NSCoding, FBSessionDelegate, FBDialogDelegate, FBRequestDelegate> //, UIWebViewDelegate>
{
	FBSession* _session;
	FBUID _uid;

	NSString* _oAuthAccessToken;
	
	id _authTarget;
	SEL _authCallback;

	NSMutableData* _authResponse;
	NSMutableData* _accessTokenResponse;
	
	NSString* _codeString;
	
//	NSURLRequest* _authConnection;
//	NSURLRequest* _accessTokenConnection;
	NSURLConnection* _authConnection;
	NSURLConnection* _accessTokenConnection;
	
	FBLoginDialog* _loginDialog;
	FBDataDialog* _permissionDialog;	
}

@property (nonatomic, retain) FBSession* session;
@property (nonatomic, assign) FBUID uid;

@property (nonatomic, copy) NSString* oAuthAccessToken;

@property (nonatomic, assign) id authTarget;
@property (nonatomic, assign) SEL authCallback;

@property (nonatomic, retain) NSMutableData* authResponse;
@property (nonatomic, retain) NSMutableData* accessTokenResponse;
@property (nonatomic, copy) NSString* codeString;

@property (nonatomic, retain) NSURLConnection* authConnection;
@property (nonatomic, retain) NSURLConnection* accessTokenConnection;

@property (nonatomic, retain) FBLoginDialog* loginDialog;
@property (nonatomic, retain) FBDataDialog* permissionDialog;


+(FacebookProxy*)instance;
+(void)loadDefaults;
//+(void)updateDefaults;

-(void)loginAndAuthorizeWithTarget:(id)target callback:(SEL)authCallback;

// use this to clear the memory, in case the user wants to logout, or any other similar situation
-(void)forgetToken;
-(void)logout;

-(GraphAPI*)newGraph;

@end
