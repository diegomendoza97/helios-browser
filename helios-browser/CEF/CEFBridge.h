//
//  CEFBridge.h
//  helios-browser
//
//  Objective-C bridge for CEF: initialization and browser view.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// Call once at app launch (e.g. from AppDelegate). Uses main bundle for paths.
void HeliosCEFInitialize(void);

// Call once before app terminates. Closes all browsers, pumps CEF work, then shuts down.
void HeliosCEFShutdown(void);

// Posted on the main thread immediately before closing browsers during shutdown.
FOUNDATION_EXPORT NSString * const HeliosCEFWillShutdownNotification;

// Call periodically (e.g. from a timer) to run CEF message loop work.
void HeliosCEFDoMessageLoopWork(void);

// Returns YES if CEF was successfully initialized.
BOOL HeliosCEFIsInitialized(void);

// Runs browser teardown + CefShutdown on the main thread, then invokes completion (also on main).
// Use with NSApplication.TerminateReply.terminateLater and NSApp.reply(toApplicationShouldTerminate:).
void HeliosCEFShutdownWithCompletion(void (^ _Nullable completion)(void));

#ifdef __cplusplus
}
#endif

@protocol HeliosCEFBrowserViewDelegate <NSObject>
@optional
- (void)cefBrowserView:(NSView *)view didLoadURL:(NSURL * _Nullable)url title:(NSString *)title canGoBack:(BOOL)canGoBack canGoForward:(BOOL)canGoForward loading:(BOOL)loading;
@end

@interface HeliosCEFBrowserView : NSView
@property (nonatomic, weak, nullable) id<HeliosCEFBrowserViewDelegate> delegate;
- (void)loadURL:(NSURL *)url;
- (void)goBack;
- (void)goForward;
- (void)reload;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
@property (nonatomic, readonly) BOOL loading;
@end

NS_ASSUME_NONNULL_END
