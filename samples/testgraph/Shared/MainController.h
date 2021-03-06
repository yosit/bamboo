@class GraphAPI;

@interface MainController : UIViewController
{
	GraphAPI* _graph;
	
	UIButton* _authButton;
	UIButton* _postButton;
	UILabel* _statusInfo;
	UIImageView* _profileImage;
	UIButton* _getPicureButton;
	UITextView* _fullText;
}

@property (nonatomic, retain) GraphAPI* _graph;

@property (nonatomic, retain) UIButton* _authButton;
@property (nonatomic, retain) UIButton* getPicureButton;

@property (nonatomic, retain) UIButton* _postButton;
@property (nonatomic, retain) UILabel* _statusInfo;
@property (nonatomic, retain) UIImageView* _profileImage;

@property (nonatomic, retain) UITextView* _fullText;

-(void)doneAuthorizing;

@end
