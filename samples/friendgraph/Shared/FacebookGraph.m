#import "FacebookGraph.h"
#import "Constants.h"
#import "AppDelegate_Phone.h"
#import "MainController.h"

// Serialization keys
NSString* const kFacebookGraphKey = @"kFacebookGraphKey";
NSString* const kKeyAccessToken = @"kKeyAccessToken";

@interface FacebookGraph (_PrivateMethods)

-(void)authorize;
-(void)getSession;

@end

@implementation FacebookGraph

@synthesize _session;
@synthesize _uid;

@synthesize _oAuthAccessToken;

@synthesize _authTarget;
@synthesize _authCallback;

@synthesize _authResponse;
@synthesize _accessTokenResponse;
@synthesize _codeString;

@synthesize _authConnection;
@synthesize _accessTokenConnection;

#pragma mark Singleton Methods

static FacebookGraph* gFacebookGraph = NULL;

+(FacebookGraph*)instance
{
	@synchronized(self)
	{
    if (gFacebookGraph == NULL)
		{
			gFacebookGraph = [[FacebookGraph alloc] init];
		}
	}
	return gFacebookGraph;
}

#pragma mark Initialization

-(id)init
{
	if ( self = [super init] )
	{
		self._uid = 0;
		self._oAuthAccessToken = nil;
		self._authTarget = nil;
		self._authCallback = nil;
		self._authResponse = nil;
		self._accessTokenResponse = nil;
		self._codeString = nil;
		self._authConnection = nil;
		self._accessTokenConnection = nil;
		[self getSession];
	}
	return self;
}

//-(void)initEvents
//{
//	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notify:) name:@"Event" object:notificationSender];	
//}

//-(void)stopEvents
//{
//	//[[NSNotificationCenter defaultCenter] removeObserver:self @"Event" object:notificationSender];
//}

- (void)dealloc 
{
	//	[self stopEvents];
	if ( self._session != nil )
		[self._session.delegates removeObject: self];	
	
	[_oAuthAccessToken release];
	[_authResponse release];
	[_accessTokenResponse release];
	[_codeString release];

	// these are released in the callbacks, but maybe I'll change that sometime...
//	[_authConnection release];
//	[_accessTokenConnection release];

//	self._authConnection = nil;
//	self._accessTokenConnection = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark NSCoding Methods

- (id)initWithCoder:(NSCoder *)coder;
{
	self = [[FacebookGraph alloc] init];
	if (self != nil)
	{
		self._oAuthAccessToken = [coder decodeObjectForKey:kKeyAccessToken]; 
	}   
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
	[coder encodeObject:self._oAuthAccessToken forKey:kKeyAccessToken];
}

#pragma mark NSDefaults Methods

+(void)loadDefaults
{
	@try
	{
		NSData* dataRepresentingSavedObject = [[NSUserDefaults standardUserDefaults] objectForKey:kFacebookGraphKey];
		
		if ( dataRepresentingSavedObject != nil )
		{
			if ( gFacebookGraph != nil )
				[gFacebookGraph release];			
			gFacebookGraph = [[NSKeyedUnarchiver unarchiveObjectWithData:dataRepresentingSavedObject] retain];
		}
		else
		{
		}
	}
	@catch (id theException) 
	{
//		[FlurryAPI logError:kErrorStatsLoadException message:@"FacebookGraph::loadDefaults" exception:theException];
	} 
	
}

+(void)updateDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:[FacebookGraph instance]] forKey:kFacebookGraphKey];
	[[NSUserDefaults standardUserDefaults] synchronize];	
}


#pragma mark -
#pragma mark Login Methods (Facebook Connect API)

-(void)getSession
{
	if ( ![self._session resume] )
	{
		RCLog( @"Starting new session" );
		self._session = [FBSession sessionForApplication:kFBAPIKey secret:kFBAppSecret delegate:self];
	}
	else 
	{
		RCLog( @"Session resumed!" );
	}
}

-(bool)isLoggedin
{
	return self._uid != 0;
}

-(void)login
{
	if ( self._session )
	{
		FBLoginDialog* dialog = [[[FBLoginDialog alloc] initWithSession:self._session] autorelease];
		dialog.delegate = self;
		[dialog show];
	}
}

#pragma mark FBSessionDelegate Methods

- (void)session:(FBSession*)session didLogin:(FBUID)uid 
{
	self._uid = uid;
	NSLog(@"User with id %lld logged in.", self._uid);
}

#pragma mark FBDialogDelegate [Login Dialog] Methods

- (void)dialogDidSucceed:(FBDialog*)dialog
{
	NSLog( @"dialogDidSucceed" );
	[self authorize];
}

#pragma mark -
#pragma mark Authorization Methods (Graph API)

-(bool)isAuthorized
{
	return nil != self._oAuthAccessToken;
}

-(void)finishedAuthorizing
{
	if ( self._authTarget && self._authCallback)
	{
		[self._authTarget performSelector:self._authCallback];
	}			
}

// authorization has the following steps
// 1. get a code by calling https://graph.facebook.com/oauth/authorize
// 2. facebook will respond with a redirect, and a code in the URL parameter
// 3. read the code parameter, and call https://graph.facebook.com/oauth/access_token
// 4. in the body of the response will be an "access_token=xxx"
// 5. save the access_token for all future graph api calls, and call the delegate callback

-(void)authorize
{
	if ( ![self isAuthorized] )
	{
		NSString* accessTokenURL = [NSString stringWithFormat:kFBAuthURLFormat, kFBClientID, kFBRedirectURI];

		NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:accessTokenURL]
																							cachePolicy:NSURLRequestUseProtocolCachePolicy
																					timeoutInterval:60.0];
		// create the connection with the request
		// and start loading the data
		self._authConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
		if ( nil != self._authConnection )
		{
			// Create the NSMutableData to hold the received data.
			self._authResponse = [NSMutableData data];
		} 
		else 
		{
			RCLog( @"authorize NSURLConnection fail" );
		}
	}
	else
	{
		[self finishedAuthorizing];
	}
}

-(void)loadAccessToken
{
	// now we have the code, and we need to go get the oAuth access_token.
	// an example url is:
	// https://graph.facebook.com/oauth/access_token?client_id=119908831367602&redirect_uri=http://oauth.twoalex.com/&client_secret=e45e55a333eec232d4206d2703de1307&code=674667c45691cbca6a03d480-1394987957%7CjN-9MVsdl0kjyoKRvQq3DbwxL4c.

	NSString* accessTokenURL = [NSString stringWithFormat:kFBAccessTokenURLFormat, kFBClientID, kFBRedirectURI, kFBAppSecret, self._codeString];

	NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:accessTokenURL]
																							cachePolicy:NSURLRequestUseProtocolCachePolicy
																					timeoutInterval:60.0];
	// create the connection with the request
	// and start loading the data
	self._accessTokenConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if ( self._accessTokenConnection ) 
	{
		// Create the NSMutableData to hold the received data.
		self._accessTokenResponse = [NSMutableData data];
	} 
	else 
	{
		RCLog( @"authorize NSURLConnection fail" );
	}
}

#pragma mark NSURLConnectionDelegate

//  NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
//	RCLog( @"status: %@", [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]] );
//	RCLog( @"headers: %@", [httpResponse allHeaderFields] );
//	RCLog( @"header keys: %@", [[httpResponse allHeaderFields] allKeys] );
//	RCLog( @"header values: %@", [[httpResponse allHeaderFields] allValues]);

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response 
{
	RCLog( @"didReceiveResponse" );
 
	if ( connection == self._authConnection )
	{
		self._authResponse = [NSMutableData data];
		
		// the code we need is at the end of the URL in the response parameter
		// example: 
		// http://oauth.twoalex.com/?code=674667c45691cbca6a03d480-1394987957%7CjN-9MVsdl0kjyoKRvQq3DbwxL4c.

		NSString* responseURL = [[response URL] absoluteString];
		NSArray* splitStrings = [responseURL componentsSeparatedByString:@"code="];
		
		if ( [splitStrings count] > 1 )
		{
			self._codeString = [splitStrings objectAtIndex:1];
			RCLog( @"codeString = [%@]", self._codeString );
		}
		else
		{
			RCLog( @"something is wrong with the URL: %@", responseURL );
			assert( false );
		}
	}
	else if ( connection == self._accessTokenConnection )
	{
		self._accessTokenResponse = [NSMutableData data];
	}
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data 
{
	if ( connection == self._authConnection )
	{
		RCLog( @"didReceiveData._auth" );
		[self._authResponse appendData:data];
	}
	else if ( connection = self._accessTokenConnection )
	{		
		RCLog( @"didReceiveData._token" );
		[self._accessTokenResponse appendData:data];
	}
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection 
{
	if ( connection == self._authConnection )
	{
		RCLog( @"connectionDidFinishLoading._auth" );
		
		NSString* responseBody = [[NSString alloc] initWithData:self._authResponse encoding:NSASCIIStringEncoding];
		RCLog( @"response: %@", responseBody );
		[responseBody release];
		responseBody = nil;
		
		[connection release];
		
		[self loadAccessToken];		
	}
	else if ( connection == self._accessTokenConnection )
	{
		RCLog( @"connectionDidFinishLoading._token" );
		NSString* responseBody = [[NSString alloc] initWithData:self._accessTokenResponse encoding:NSASCIIStringEncoding];
		RCLog( @"response: %@", responseBody );
		
		// the entire response body is just access_token=xxx, the access token is the goods that we're doing all this for. example is:
		// access_token=119908831367602|674667c45691cbca6a03d480-1394987957|dRiaWMp7ZoqrRy_jHDEutHC5AP0.
		
		NSArray* splitStrings = [responseBody componentsSeparatedByString:@"access_token="];
		
		if ( [splitStrings count] > 1 )
		{
			self._oAuthAccessToken = [splitStrings objectAtIndex:1];
			RCLog( @"accessToken = [%@]", self._oAuthAccessToken );
			[FacebookGraph updateDefaults];
			[self finishedAuthorizing];
		}
		else
		{
			RCLog( @"something is wrong with the access_code response: %@", responseBody );
			assert( false );
		}
		
		[responseBody release];
		responseBody = nil;
		
		[connection release];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if ( connection == self._authConnection )
	{
		RCLog( @"_auth connectionDidFail" );
	}
	else if ( connection == self._accessTokenConnection )
	{
		RCLog( @"_token connectionDidFail" );
	}
	
	// release the connection, and the data object
	[connection release];
// todo - manage this memory in a way that makes sense
//	// receivedData is declared as a method instance elsewhere
//	[receivedData release];
	
	// inform the user
	RCLog(@"Connection failed! Error - %@ %@",
				[error localizedDescription],
				[[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

#pragma mark -
#pragma mark Public Instance Methods

// the event flow of this class is:
// 1. first, check if we already have an access token.  if so, gtfo.  if not..the normal flow is...
// 2. login (if not already logged in) via traditional login api
// 3. authorize using graph api, if we don't already have an oAuthAccessToken

-(void)loginAndAuthorizeWithTarget:(id)target callback:(SEL)authCallback
{
	self._authTarget = target;
	self._authCallback = authCallback;

	if ( [self isAuthorized] )
	{
		[self finishedAuthorizing];
	}
	else if ( ![self isLoggedin] )
	{
		[self login];
	}
	else
	{
		[self authorize];
	}
}

#pragma mark Event Handlers
#pragma mark Button Handlers

@end