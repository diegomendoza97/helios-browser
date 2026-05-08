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

// Call once before app terminates.
void HeliosCEFShutdown(void);

// Call periodically (e.g. from a timer) to run CEF message loop work.
void HeliosCEFDoMessageLoopWork(void);

// Returns YES if CEF was successfully initialized.
BOOL HeliosCEFIsInitialized(void);

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
