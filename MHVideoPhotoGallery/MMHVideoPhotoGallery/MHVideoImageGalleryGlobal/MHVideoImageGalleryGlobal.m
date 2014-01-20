
#import "MHVideoImageGalleryGlobal.h"
#import "MHGalleryOverViewController.h"


NSString * const MHGalleryViewModeOverView = @"MHGalleryViewModeOverView";
NSString * const MHGalleryViewModeShare = @"MHGalleryViewModeShare";
NSString * const MHUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 5_0 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A334 Safari/7534.48.3";


@interface MHNavigationController : UINavigationController
@end

@implementation MHNavigationController

- (UIViewController *)childViewControllerForStatusBarStyle {
    UIViewController *vc = [super childViewControllerForStatusBarStyle];
    vc = self.topViewController;
    return vc;
}
-(BOOL)shouldAutorotate{
    return [[self.viewControllers lastObject] shouldAutorotate];
}

-(NSUInteger)supportedInterfaceOrientations{
    return [[self.viewControllers lastObject] supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
    return [[self.viewControllers lastObject] preferredInterfaceOrientationForPresentation];
}

@end

@implementation MHShareItem


- (id)initWithImageName:(NSString*)imageName
                  title:(NSString*)title
           withMaxNumberOfItems:(NSInteger)maxNumberOfItems
           withSelector:(NSString*)selectorName
       onViewController:(id)onViewController{
    self = [super init];
    if (!self)
        return nil;
    self.imageName = imageName;
    self.title = title;
    self.maxNumberOfItems = maxNumberOfItems;
    self.selectorName = selectorName;
    self.onViewController = onViewController;
    return self;
}
@end

@implementation MHGalleryItem


- (id)initWithURL:(NSString*)urlString
      galleryType:(MHGalleryType)galleryType{
    self = [super init];
    if (!self)
        return nil;
    self.urlString = urlString;
    self.title = nil;
    self.description = nil;
    self.galleryType = galleryType;
    return self;
}
@end


@implementation MHGallerySharedManager

+ (MHGallerySharedManager *)sharedManager{
    static MHGallerySharedManager *sharedManagerInstance = nil;
    static dispatch_once_t onceQueue;
    dispatch_once(&onceQueue, ^{
        sharedManagerInstance = [[self alloc] init];
    });
    return sharedManagerInstance;
}

-(void)presentMHGalleryWithItems:(NSArray*)galleryItems
                        forIndex:(NSInteger)index
        andCurrentViewController:(id)viewcontroller
                  finishCallback:(void(^)(NSInteger pageIndex,AnimatorShowDetailForDismissMHGallery *interactiveTransition,UIImage *image)
                                  )FinishBlock
        withImageViewTransiation:(BOOL)animated{
    
    if(![MHGallerySharedManager sharedManager].viewModes){
        [MHGallerySharedManager sharedManager].viewModes = [NSSet setWithObjects:MHGalleryViewModeOverView,
                                                            MHGalleryViewModeShare, nil];
    }
    
    self.oldStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

    [[MHGallerySharedManager sharedManager] setGalleryItems:galleryItems];
    
    MHGalleryOverViewController *gallery = [MHGalleryOverViewController new];
    [gallery viewDidLoad];
    gallery.finishedCallback = ^(NSUInteger photoIndex,AnimatorShowDetailForDismissMHGallery *interactiveTransition,UIImage *image) {
        FinishBlock(photoIndex,interactiveTransition,image);
    };
    
    MHGalleryImageViewerViewController *detail = [MHGalleryImageViewerViewController new];
    detail.pageIndex = index;
    detail.finishedCallback = ^(NSUInteger photoIndex,AnimatorShowDetailForDismissMHGallery *interactiveTransition,UIImage *image) {
        FinishBlock(photoIndex,interactiveTransition,image);
    };
    
    UINavigationController *nav = [MHNavigationController new];
    
    
    if (![[MHGallerySharedManager sharedManager].viewModes containsObject:MHGalleryViewModeOverView] || galleryItems.count ==1) {
        nav.viewControllers = @[detail];
    }else{
        nav.viewControllers = @[gallery,detail];
    }
    if (animated) {
        nav.transitioningDelegate = viewcontroller;
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    [viewcontroller presentViewController:nav animated:YES completion:nil];
}

-(BOOL)isUIVCBasedStatusBarAppearance{
    NSNumber *isUIVCBasedStatusBarAppearance = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"];
    if (isUIVCBasedStatusBarAppearance) {
        return  isUIVCBasedStatusBarAppearance.boolValue;
    }
    return YES;
}

-(void)createThumbURL:(NSString*)urlString
              forSize:(CGSize)size
           atDuration:(MHImageGeneration)duration
         successBlock:(void (^)(UIImage *image,NSUInteger videoDuration,NSError *error))succeedBlock{
    
    UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:urlString];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithDictionary:[[NSUserDefaults standardUserDefaults]objectForKey:@"MHGalleryData"]];
    if (!dict) {
        dict = [NSMutableDictionary new];
    }
    if (image) {
        succeedBlock(image,[dict[urlString] integerValue],nil);
    }else{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSURL *url = [NSURL URLWithString:urlString];
        AVURLAsset *asset=[[AVURLAsset alloc] initWithURL:url options:nil];
        
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        CMTime thumbTime = CMTimeMakeWithSeconds(0,40);
        CMTime videoDurationTime = asset.duration;
        NSUInteger videoDurationTimeInSeconds = CMTimeGetSeconds(videoDurationTime);
        
        NSMutableDictionary *dictToSave = [[NSMutableDictionary alloc]initWithDictionary:[[NSUserDefaults standardUserDefaults]objectForKey:@"MHGalleryData"]];
        if (videoDurationTimeInSeconds !=0) {
            dictToSave[urlString] = @(videoDurationTimeInSeconds);
            [[NSUserDefaults standardUserDefaults]setObject:dictToSave forKey:@"MHGalleryData"];
            [[NSUserDefaults standardUserDefaults]synchronize];
        }
        
        if (duration == MHImageGenerationMiddle || duration == MHImageGenerationEnd) {
            if(duration == MHImageGenerationMiddle){
                thumbTime = CMTimeMakeWithSeconds(videoDurationTimeInSeconds/2,30);
            }else{
                thumbTime = CMTimeMakeWithSeconds(videoDurationTimeInSeconds,30);
            }
        }
        
        AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
            
            if (result != AVAssetImageGeneratorSucceeded) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    succeedBlock(nil,0,error);
                });
            }else{
                [[SDImageCache sharedImageCache] storeImage:[UIImage imageWithCGImage:im]
                                                     forKey:urlString];
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    succeedBlock([UIImage imageWithCGImage:im],videoDurationTimeInSeconds,nil);
                });
            }
        };
        CGSize maxSize = size;
        generator.maximumSize = maxSize;
        [generator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:thumbTime]]
                                        completionHandler:handler];
    });
    }
}



-(NSString*)extractYouTubeURL:(NSString *)HTML{
    
    NSError *error =nil;
    NSString *string = HTML;
    NSString  *extractionExpression = @"(?!\\\\\")http[^\"]*?itag=[^\"]*?(?=\\\\\")";
    
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:extractionExpression
                                                                      options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSArray* videos = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    if (videos.count > 0) {
        NSTextCheckingResult* checkingResult = nil;
        checkingResult = [videos firstObject];
        NSMutableString* streamURL = [NSMutableString stringWithString: [string substringWithRange:checkingResult.range]];
    
        [streamURL replaceOccurrencesOfString:@"\\\\u0026"
                                   withString:@"&"
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, streamURL.length)];
        
        [streamURL replaceOccurrencesOfString:@"\\\\\\"
                                   withString:@""
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, streamURL.length)];
        
        return streamURL;
    }
    return nil;
}

-(void)getYoutTubeURLforThumbAndMediaPlayer:(NSString*)URL
                               successBlock:(void (^)(NSString *URL,NSError *error))succeedBlock{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.domain rangeOfString:@"youtube"].location != NSNotFound) {
            [cookieStorage deleteCookie:cookie];
        }
    }
    
    NSMutableURLRequest *httpRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5];
    [httpRequest setValue:MHUserAgent forHTTPHeaderField:@"User-Agent"];
    
    [NSURLConnection sendAsynchronousRequest:httpRequest queue:[[NSOperationQueue alloc] init] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSString* html = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];
        
        
        if ([self extractYouTubeURL:html]) {
            succeedBlock([self extractYouTubeURL:html],nil);
        }else{
            succeedBlock([self extractYouTubeURL:html],nil);
        }
    }];
}

-(void)startDownloadingThumbImage:(NSString*)urlString
                          forSize:(CGSize)size
                       atDuration:(MHImageGeneration)duration
                     successBlock:(void (^)(UIImage *image,NSUInteger videoDuration,NSError *error,NSString *newURL))succeedBlock{
    
        if ([urlString rangeOfString:@"youtube.com"].location == NSNotFound) {
            [self createThumbURL:urlString
                         forSize:size
                      atDuration:duration
                    successBlock:^(UIImage *image, NSUInteger videoDuration, NSError *error) {
                        succeedBlock(image,videoDuration,error,urlString);
                    }];
        }else{
            [self getYoutTubeURLforThumbAndMediaPlayer:urlString
                                          successBlock:^(NSString *URL, NSError *error) {
                                              [self createThumbURL:URL
                                                           forSize:size
                                                        atDuration:MHImageGenerationMiddle
                                                      successBlock:^(UIImage *image, NSUInteger videoDuration, NSError *error) {
                                                          succeedBlock(image,videoDuration,error,URL);
                                                      }];
            }];
        }
}


- (UIImage *)imageByRenderingView:(id)view{
    CGFloat scale = 1.0;
    if([[UIScreen mainScreen]respondsToSelector:@selector(scale)]) {
        CGFloat tmp = [[UIScreen mainScreen]scale];
        if (tmp > 1.5) {
            scale = 2.0;
        }
    }
    if(scale > 1.5) {
        UIGraphicsBeginImageContextWithOptions([view bounds].size, NO, scale);
    } else {
        UIGraphicsBeginImageContext([view bounds].size);
    }
    [[view layer] renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultingImage;
}

@end



