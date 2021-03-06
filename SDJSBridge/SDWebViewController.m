//
//  SDWebViewController.m
//  SDJSBridgeExample
//
//  Created by Brandon Sneed on 10/9/14.
//  Copyright (c) 2014 SetDirection. All rights reserved.
//

#import "SDWebViewController.h"
#import "SDJSBridge.h"
#import "SDMacros.h"
#import "SDJSHandlerScript.h"
#import "UIImage+SDExtensions.h"

#import "walmart-Swift.h"

NSString * const SDJSPageFinishedHandlerName = @"pageFinished";

@interface SDWebViewController () <UIWebViewDelegate, WebViewBridging>

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIImageView *placeholderView;
@property (nonatomic, strong) NSTimer *loadTimer;
@property (nonatomic, assign) BOOL sharedWebView;
@property (nonatomic, strong, readwrite) NSURL *currentURL;
@property (nonatomic, strong) SDJSBridge *bridge;
@property (nonatomic, weak) SDJSHandlerScript *handlerScript;
@property (nonatomic, assign, readwrite) SDLoadState loadedURLState;
@property (nonatomic, copy) NSString *storedScreenshotGUID;

@end

@implementation SDWebViewController

#pragma mark - Initialization

- (instancetype)init
{
    if ((self = [super init]))
    {
    }
    
    return self;
}

- (instancetype)initWithWebView:(UIWebView *)webView
{
    return [self initWithWebView:webView bridge:nil];
}

- (instancetype)initWithWebView:(UIWebView *)webView bridge:(SDJSBridge *)bridge
{
    if ((self = [super init]))
    {
        self.webView = webView;

        _sharedWebView = YES;
        _bridge = bridge;
        
        if (!_bridge)
        {
            [self loadBridge];
        }
    }
    
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init]))
    {
        _currentURL = url;
        [self loadURL:_currentURL];
    }
    
    return self;
}

#pragma mark - Lifecycle methods

- (void)dealloc
{
    self.delegate = nil;
    
    // Clear the webview delegate but only if it's pointing at us
    // Since these webviews are shared, we were not clearing the delegate on pop to home
    if (self.webView.delegate == self) {
        self.webView.delegate = nil;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initializeController];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Load a screenshot if we have one
    if (self.storedScreenshotGUID)
    {
        self.placeholderView.image = [UIImage loadImageFromGUID:self.storedScreenshotGUID];
        self.placeholderView.frame = self.view.bounds;
        [self.view bringSubviewToFront:self.placeholderView];
    }
    
    // I think it is better if the bridge is updated before we pop back, no?
    if (_bridge)
    {
        [self configureScriptObjects];
    }
    
    if (![self isMovingToParentViewController] && self.webView.superview != self.view)
    {
        [self goBackInWebView];
        [self recontainWebView];
    }
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
        
    // go back in web view before popping back to previous vc
    if (self.isMovingFromParentViewController) {
        
        if (self.loadedURLState == kSDLoadStatePushState) {
            self.webView.hidden = NO;
        }
        else {
            self.webView.hidden = YES;
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // hide placeholder view after view animates away so that when we pop back
    // we do not see a flicker of the previous page while web view's goBack
    // updates the page
    self.placeholderView.image = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initializeController
{
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.autoresizesSubviews = YES;
    //self.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.placeholderView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    //self.placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.placeholderView atIndex:0];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    if (self.loadedURLState == kSDLoadStateURL)
    {
        self.webView.hidden = YES;
    }
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.webView.backgroundColor = [UIColor whiteColor];
    
    [self recontainWebView];
}

#pragma mark - URLs

- (NSURL *)url
{
    return [self.currentURL copy];
}

- (NSURLRequest *)parseURLRequest:(NSURLRequest *)request
{
    // Don't do anything with this implementation, we just want to pass it
    // on for now. This is only here for subclasses to override
    
    return request;
}

- (void)loadURL:(NSURL *)url
{
    self.currentURL = url;
    
    NSURLRequest *request = nil;
    
    if (self.defaultUserAgent.length) {
        NSMutableURLRequest *tempRequest = [NSMutableURLRequest requestWithURL:self.currentURL];
        [tempRequest setValue:self.defaultUserAgent forHTTPHeaderField:@"User-Agent"];
        request = tempRequest;
    } else {
        request = [NSURLRequest requestWithURL:self.currentURL];
    }
    
    // A chance for the request to manipulated
    NSURLRequest *modifiedRequest = [self parseURLRequest:request];
    
    [self.webView loadRequest:modifiedRequest];
}

#pragma mark - Sharing
- (UIActivityViewController *)shareWithTitle:(NSString *)title andBody:(NSString *)body
{
    // Pass-thru
    NSArray *items = nil;
    
    if (title.length && body.length) {
        items = @[title, body];
    } else if (body.length) {
        items = @[body];
    } else {
        return nil;
    }
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    
    return activityViewController;
}

#pragma mark - Navigation

- (id)pushURL:(NSURL *)url title:(NSString *)title
{
    self.placeholderView.image = [self imageWithView:self.webView];
    
    self.placeholderView.hidden = NO;

    SDWebViewController *webViewController = [(SDWebViewController *)[[self class] alloc] initWithWebView:self.webView bridge:self.bridge];
    webViewController.title = title;
    
    BOOL animateViewController = YES;
    if (url) {
        webViewController.loadedURLState = kSDLoadStateURL;
        [webViewController loadURL:url];
    } else {
        webViewController.loadedURLState = kSDLoadStatePushState;
        animateViewController = NO;
    }
    
    // Take snapshot
    [self p_takeSnapshotOfWebview];
    
    
    [self.navigationController pushViewController:webViewController animated:animateViewController];
    
    return webViewController;
}

- (id)presentModalURL:(NSURL *)url title:(NSString *)title
{
    self.placeholderView.image = [self imageWithView:self.webView];
    
    SDWebViewController *webViewController = [(SDWebViewController *)[[self class] alloc] initWithWebView:self.webView bridge:self.bridge];
    webViewController.title = title;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
    
    [webViewController loadURL:url];
    
    return webViewController;
}

- (id)presentModalHTML:(NSString *)html title:(NSString *)title
{
    SDWebViewController *webViewController = [(SDWebViewController *)[[self class] alloc] initWithWebView:nil bridge:self.bridge];
    webViewController.title = title;
    [webViewController.webView loadHTMLString:html baseURL:self.url];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
    
    return webViewController;
}

- (void)goBackInWebView {
    [self.webView goBack];
}

#pragma mark - SDJSBridge

- (void)loadBridge {
    self.bridge = [[SDJSBridge alloc] initWithWebView:self.webView];
}

- (void)addScriptObject:(NSObject<JSExport> *)object name:(NSString *)name
{
    [self.bridge addScriptObject:object name:name];
    
    if ([object isKindOfClass:[SDJSHandlerScript class]]) {
        self.handlerScript = (SDJSHandlerScript *)object;
    }
}

- (void)addScriptMethod:(NSString *)name block:(id)block
{
    [self.bridge addScriptMethod:name block:block];
}

- (void)configureScriptObjects
{
    
    // Change 1: Tell the delegate to configure its script objects first
    @strongify(self.delegate, strongDelegate);
    
    if ([strongDelegate respondsToSelector:@selector(webViewControllerConfigureScriptObjects:)]) {
        [strongDelegate webViewControllerConfigureScriptObjects:self];
    }
    
    // Change 2: THEN update the current bridge scripts to point to self
    
    // update parent web view controller reference in scripts
    for (NSString *scriptName in [_bridge scriptObjects]) {
        SDJSBridgeScript *script = [_bridge scriptObjects][scriptName];
        if ([script isKindOfClass:[SDJSBridgeScript class]]) {
            script.webViewController = self;
        }
    }
}

- (JSValue *)evaluateScript:(NSString *)script {
    return [self.bridge evaluateScript:script];
}

#pragma mark - UIWebViewDelegate methods

- (BOOL)shouldStartLoadWithRequest:(NSURLRequest *)request
                    navigationType:(UIWebViewNavigationType)navigationType
     againstWebViewNavigationTypes:(NSArray *)navigationTypes
{
    BOOL result = YES;
    
    if ([navigationTypes containsObject:@(navigationType)])
    {
        if ([request.URL.absoluteString isEqualToString:self.currentURL.absoluteString])
            return YES;
        
        @strongify(self.delegate, strongDelegate);
        
        if ([strongDelegate respondsToSelector:@selector(webViewController:shouldOpenRequest:)])
            result = [strongDelegate webViewController:self shouldOpenRequest:request];
        else
        {
            result = [self shouldHandleURL:request.URL];
            
            // handles link clicks through standard navigation mechanism.
            if (result)
            {
                if ([request.URL.scheme isEqualToString:@"https"] || [request.URL.scheme isEqualToString:@"http"])
                {
                    [self.webView stopLoading];
                    [self pushURL:request.URL title:nil];
                    result = NO;
                }
                else
                {
                    result = YES;
                }
            }
        }
    }
    
    // useful for debugging.
    //NSLog(@"navType = %d, url = %@", navigationType, request.URL);
    
    return result;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    return [self shouldStartLoadWithRequest:request
                             navigationType:navigationType
              againstWebViewNavigationTypes:@[@(UIWebViewNavigationTypeLinkClicked)]];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    @strongify(self.delegate, strongDelegate);
    
    if ([strongDelegate respondsToSelector:@selector(webViewControllerDidStartLoad:)])
        [strongDelegate webViewControllerDidStartLoad:self];
    
    [self webViewDidStartLoad];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!webView.isLoading) {
        [self updateState];
        [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(_actuallyShowWebView) userInfo:nil repeats:NO];
    }
    
    [self.handlerScript callHandlerWithName:SDJSPageFinishedHandlerName data:nil];
    
    @strongify(self.delegate, strongDelegate);
    if ([strongDelegate respondsToSelector:@selector(webViewControllerDidFinishLoad:)])
        [strongDelegate webViewControllerDidFinishLoad:self];
    
    [self webViewDidFinishLoad];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self webViewDidFinishLoad];
}

- (void)didCreateJavaScriptContext:(JSContext * __nonnull)context {
    [self.bridge configureContext:context];
    
    @strongify(self.delegate, strongDelegate);
    
    if ([strongDelegate respondsToSelector:@selector(webViewController:didCreateJavaScriptContext:)]) {
        [strongDelegate webViewController:self didCreateJavaScriptContext:context];
    }
}

//- (void)webView:(UIWebView *)webView didCreateJavaScriptContext:(JSContext *)context
//{
//    [self.bridge configureContext:context];
//    
//    @strongify(self.delegate, strongDelegate);
//    
//    if ([strongDelegate respondsToSelector:@selector(webViewController:didCreateJavaScriptContext:)]) {
//        [strongDelegate webViewController:self didCreateJavaScriptContext:context];
//    }
//}

#pragma mark - Web view events.

- (void)webViewDidStartLoad
{
    // don't do anything, this is for subclasses.
}

- (void)webViewDidFinishLoad
{
    // don't do anything, this is for subclasses.
}

- (BOOL)shouldHandleURL:(NSURL *)url
{
    return YES;
}

#pragma mark - Utilities

- (UIImage *)imageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

- (void)p_showWebView
{
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, .25 * NSEC_PER_MSEC);
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        self.webView.hidden = NO;
        self.placeholderView.image = nil;
        [self.view sendSubviewToBack:self.placeholderView];
    });
}

- (void)p_takeSnapshotOfWebview
{
    // Get a snapshot of the current webview, save it to disk to use later
    UIImage *image = [self imageWithView:self.webView];
    self.placeholderView.image = image;
    self.storedScreenshotGUID = [image saveImageToDisk];
    
    [self.view bringSubviewToFront:self.placeholderView];
}

#pragma mark - UIWebView

- (void)recontainWebView
{
    self.webView.delegate = self;
    
    CGRect frame = self.view.bounds;
    
    [self.webView removeFromSuperview];
    
    self.webView.frame = frame;
    self.webView.scrollView.contentInset = UIEdgeInsetsZero;
    [self.view addSubview:self.webView];
    
    self.placeholderView.frame = frame;
}

- (void)_actuallyShowWebView {
    // called by timer in webViewDidFinishLoad. this is the best estimation of
    // when the web view will be completely finished loading. this prevents
    // flicker that was causing the webView to be shown too early with the
    // previous page still renderered. before you would see a flicker of the
    // previous page before seeing the newly loaded page.
    [self p_showWebView];
}

- (UIWebView *)webView
{
    if (!_webView)
    {
        UIWebView *aWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
        aWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        aWebView.scrollView.delaysContentTouches = NO;
        [aWebView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
        aWebView.delegate = self;
        
        _webView = aWebView;
        [WebViewManager addBridgedWebView:_webView];
        
        [self loadBridge];
    }
    
    return _webView;
}

// Call this to update the state of the webview
// This code used to be buried in webViewDidFinishLoad:
// This purposely does not call any of the javascript stuff as this is a simple back
// If we need that to be called, then we can extend the functionality of this method as needed
- (void)updateState
{
    NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
    if (title.length)
    {
        self.title = title;
    }
}

@end
