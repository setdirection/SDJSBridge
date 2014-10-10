//
//  SDWebViewController.m
//  SDJSBridgeExample
//
//  Created by Brandon Sneed on 10/9/14.
//  Copyright (c) 2014 SetDirection. All rights reserved.
//

#import "SDWebViewController.h"
#import "SDJSBridge.h"

@interface SDWebViewController () <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIImageView *placeholderView;
@end

@implementation SDWebViewController
{
    NSURL *_currentURL;
    SDJSBridge *_bridge;
    BOOL _sharedWebView;
}

- (instancetype)init
{
    self = [super init];
    
    //_initialURL = url;
    [self configureController];
    
    return self;
}

- (instancetype)initWithWebView:(UIWebView *)webView
{
    self = [super init];
    
    _webView = webView;
    _sharedWebView = YES;
    
    [self configureController];
    
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc");
}

- (void)loadURL:(NSURL *)url
{
    _currentURL = url;
    [self.webView loadRequest:[NSURLRequest requestWithURL:_currentURL]];
}

- (void)configureController
{
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    if (!self.webView)
    {
        self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.webView.scrollView.delaysContentTouches = NO;
        [self.webView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
        
        _bridge = [[SDJSBridge alloc] initWithWebView:self.webView];
    }
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:_currentURL]];
}

- (void)addScriptObject:(NSObject<JSExport> *)object name:(NSString *)name
{
    [_bridge addScriptObject:object name:name];
}

- (void)addScriptMethod:(NSString *)name block:(void *)block
{
    [_bridge addScriptMethod:name block:block];
}

- (void)recontainWebView
{
    self.webView.delegate = self;
    
    CGRect frame = self.view.bounds;
    
    [self.webView removeFromSuperview];
    self.webView.frame = frame;
    self.webView.scrollView.contentInset = UIEdgeInsetsZero;
    [self.view addSubview:self.webView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.webView.backgroundColor = [UIColor whiteColor];
    
    [self recontainWebView];
    
    self.placeholderView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view insertSubview:self.placeholderView atIndex:0];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (![self isMovingToParentViewController])
    {
        [self recontainWebView];
        [self.webView goBack];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    UIImage *placeholderImage = [self imageWithView:self.webView];
    self.placeholderView.image = placeholderImage;
}

- (void)viewDidAppear:(BOOL)animated
{
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL result = YES;
    
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        NSLog(@"url = %@", request.URL);
        
        if ([request.URL.absoluteString isEqualToString:_currentURL.absoluteString])
            return YES;
        
        if ([self.delegate respondsToSelector:@selector(webViewController:shouldOpenRequest:)])
            result = [self.delegate webViewController:self shouldOpenRequest:request];
        else
            result = YES;
    }
    
    return result;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if ([self.delegate respondsToSelector:@selector(webViewControllerDidStartLoad:)])
        [self.delegate webViewControllerDidStartLoad:self];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if ([self.delegate respondsToSelector:@selector(webViewControllerDidFinishLoad:)])
        [self.delegate webViewControllerDidFinishLoad:self];
    /*_bridge = [[SDJSBridge alloc] initWithWebView:self.webView];
     _topLevelAPI.platform.sharedWebView = self.webView;
     _topLevelAPI.platform.navigationController = self.navigationController;
     
     [_bridge addScriptObject:_topLevelAPI name:@"WM"];*/
}

- (void)webView:(UIWebView *)webView didCreateJavaScriptContext:(JSContext*) ctx
{
    NSLog(@"got a new context");
    [_bridge configureContext:ctx];
}

- (UIImage *)imageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

@end
