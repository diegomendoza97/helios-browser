//
//  CEFBridge.mm
//  helios-browser
//
//  CEF initialization and NSView that hosts a CEF browser. Requires CEF framework.
//

#import "CEFBridge.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <atomic>
#include <unistd.h>

#if USE_CEF
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_display_handler.h"
#include "include/cef_request_handler.h"
#include "include/cef_sandbox_mac.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

namespace {
std::atomic<int> g_helios_live_browser_count{0};

void HeliosPumpCEFMessageLoop(unsigned iterations) {
    for (unsigned i = 0; i < iterations; i++) {
        CefDoMessageLoopWork();
    }
}
}  // namespace

static bool g_cef_initialized = false;
static std::atomic<bool> g_cef_shutdown_in_progress{false};

// MARK: - CEF App (process-level)

class HeliosCefApp : public CefApp, public CefBrowserProcessHandler {
public:
    HeliosCefApp() = default;
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
    void OnContextInitialized() override {}

    void OnBeforeCommandLineProcessing(const CefString& process_type,
                                       CefRefPtr<CefCommandLine> command_line) override {
        // Temporary stabilization for macOS local-dev signing issues:
        // force software compositing to avoid GPU subprocess/library failures.
        command_line->AppendSwitch("disable-gpu");
        command_line->AppendSwitch("disable-gpu-compositing");
        command_line->AppendSwitch("disable-gpu-shader-disk-cache");
        command_line->AppendSwitch("in-process-gpu");

        std::string ptype = process_type.ToString();
        NSLog(@"[Helios] CEF command line configured for process type: %s",
              ptype.empty() ? "(browser)" : ptype.c_str());
    }

private:
    IMPLEMENT_REFCOUNTING(HeliosCefApp);
};

// MARK: - Forward declarations for HeliosCEFBrowserView internal methods

@interface HeliosCEFBrowserView ()
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL canGoBack;
@property (nonatomic, assign) BOOL canGoForward;
- (void)updateFromBrowser;
- (void)notifyStateChange;
- (void)browserDidCreate;
- (void)applyLoadingStateFromCEF:(BOOL)isLoading canGoBack:(BOOL)canGoBack canGoForward:(BOOL)canGoForward;
- (void)syncNavigationFlagsFromBrowser;
@end

// MARK: - CEF Client (browser-level) and handlers

class HeliosCefClient : public CefClient,
                        public CefLifeSpanHandler,
                        public CefLoadHandler,
                        public CefDisplayHandler,
                        public CefRequestHandler {
public:
    explicit HeliosCefClient(HeliosCEFBrowserView *view) : view_(view) {}
    std::string GetPageTitle() const { return page_title_; }

    CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
    CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
    CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
    CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

    void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
        browser_ = browser;
        g_helios_live_browser_count++;
        if (browser_ && browser_->GetHost()) {
            browser_->GetHost()->WasResized();
            browser_->GetHost()->Invalidate(PET_VIEW);
        }
        HeliosCEFBrowserView *v = view_;
        dispatch_async(dispatch_get_main_queue(), ^{
            [v browserDidCreate];
        });
    }

    bool DoClose(CefRefPtr<CefBrowser> browser) override {
        // Return false to allow the browser to close normally
        return false;
    }

    void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
        browser_ = nullptr;
        g_helios_live_browser_count--;
    }

    void OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, TransitionType transition_type) override {
        if (frame->IsMain()) {
            std::string url = frame->GetURL();
            NSLog(@"[Helios] CEF OnLoadStart main frame: %s", url.c_str());
            HeliosCEFBrowserView *v = view_;
            dispatch_async(dispatch_get_main_queue(), ^{
                [v setLoading:YES];
                [v syncNavigationFlagsFromBrowser];
                [v notifyStateChange];
            });
        }
    }

    void OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int httpStatusCode) override {
        if (frame->IsMain()) {
            std::string url = frame->GetURL();
            NSLog(@"[Helios] CEF OnLoadEnd main frame: %s (status=%d)", url.c_str(), httpStatusCode);
            HeliosCEFBrowserView *v = view_;
            dispatch_async(dispatch_get_main_queue(), ^{
                [v setLoading:NO];
                [v updateFromBrowser];
            });
        }
    }

    void OnLoadError(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, ErrorCode errorCode,
                     const CefString& errorText, const CefString& failedUrl) override {
        if (frame->IsMain()) {
            NSLog(@"[Helios] CEF OnLoadError main frame: code=%d text=%s url=%s",
                  static_cast<int>(errorCode),
                  errorText.ToString().c_str(),
                  failedUrl.ToString().c_str());
            HeliosCEFBrowserView *v = view_;
            dispatch_async(dispatch_get_main_queue(), ^{
                [v setLoading:NO];
                [v updateFromBrowser];
            });
        }
    }

    void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                              bool isLoading,
                              bool canGoBack,
                              bool canGoForward) override {
        NSLog(@"[Helios] CEF OnLoadingStateChange: isLoading=%d canGoBack=%d canGoForward=%d",
              isLoading ? 1 : 0,
              canGoBack ? 1 : 0,
              canGoForward ? 1 : 0);
        HeliosCEFBrowserView *v = view_;
        dispatch_async(dispatch_get_main_queue(), ^{
            [v applyLoadingStateFromCEF:isLoading ? YES : NO
                             canGoBack:canGoBack ? YES : NO
                          canGoForward:canGoForward ? YES : NO];
        });
    }

    void OnAddressChange(CefRefPtr<CefBrowser> browser,
                         CefRefPtr<CefFrame> frame,
                         const CefString& url) override {
        if (!frame->IsMain()) {
            return;
        }
        // SPAs (e.g. YouTube) update the URL without a full load; refresh CanGoBack/CanGoForward from the browser.
        HeliosCEFBrowserView *v = view_;
        dispatch_async(dispatch_get_main_queue(), ^{
            [v updateFromBrowser];
        });
    }

    void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser,
                                   TerminationStatus status,
                                   int error_code,
                                   const CefString& error_string) override {
        NSLog(@"[Helios] CEF renderer terminated: status=%d error_code=%d error=%s",
              static_cast<int>(status),
              error_code,
              error_string.ToString().c_str());
    }

    void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override {
        page_title_ = title.ToString();
        HeliosCEFBrowserView *v = view_;
        dispatch_async(dispatch_get_main_queue(), ^{
            [v updateFromBrowser];
        });
    }

    CefRefPtr<CefBrowser> browser() const { return browser_; }

private:
    HeliosCEFBrowserView *__weak view_;
    CefRefPtr<CefBrowser> browser_;
    std::string page_title_;
    IMPLEMENT_REFCOUNTING(HeliosCefClient);
};

// MARK: - CEF init/shutdown state

static CefScopedLibraryLoader g_library_loader;
NSString * const HeliosCEFDidInitializeNotification = @"HeliosCEFDidInitializeNotification";
NSString * const HeliosCEFWillShutdownNotification = @"HeliosCEFWillShutdownNotification";

static void HeliosPerformCEFShutdownNow(void) {
    if (!g_cef_initialized) {
        return;
    }
    // Ignore nested attempts (e.g. if something spins a nested run loop during teardown).
    bool expected = false;
    if (!g_cef_shutdown_in_progress.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) {
        NSLog(@"[Helios] CEF shutdown re-entry skipped (nested run loop / delegate)");
        return;
    }

    NSLog(@"[Helios] CEF shutdown: requesting CloseBrowser on all views");
    [[NSNotificationCenter defaultCenter] postNotificationName:HeliosCEFWillShutdownNotification object:nil];

    // Do NOT call CFRunLoopRunInMode here: it processes AppKit events and can re-enter termination
    // handlers while this function is still running, which previously left terminateLater waiting forever.
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8.0];
    while (g_helios_live_browser_count.load(std::memory_order_acquire) > 0 &&
           [deadline timeIntervalSinceNow] > 0) {
        CefDoMessageLoopWork();
        // Tiny run-loop slice so AppKit/CEF can finish closing; avoid long CFRunLoopRunInMode (stalls quit).
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
        usleep(1000);
    }
    if (g_helios_live_browser_count.load() > 0) {
        NSLog(@"[Helios] ERROR: browsers still open after pump — skipping CefShutdown (would hang). "
              @"Helpers may linger until the OS reaps the process.");
        g_cef_initialized = false;
        g_cef_shutdown_in_progress = false;
        return;
    }

    NSLog(@"[Helios] CEF shutdown: brief drain before CefShutdown");
    NSDate *drainUntil = [NSDate dateWithTimeIntervalSinceNow:1.25];
    while ([drainUntil timeIntervalSinceNow] > 0) {
        CefDoMessageLoopWork();
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
        usleep(1500);
    }

    NSLog(@"[Helios] Calling CefShutdown...");
    CefShutdown();
    g_cef_initialized = false;
    g_cef_shutdown_in_progress = false;
    NSLog(@"[Helios] CefShutdown returned");
}

static void HeliosForceResizeDescendants(NSView *root, NSRect bounds) {
    if (!root) return;
    for (NSView *subview in root.subviews) {
        [subview setFrame:bounds];
        subview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        HeliosForceResizeDescendants(subview, bounds);
    }
    if (root.layer) {
        for (CALayer *layer in root.layer.sublayers) {
            layer.frame = NSRectToCGRect(bounds);
        }
    }
}

void HeliosCEFInitialize(void) {
    if (g_cef_initialized) return;
    NSLog(@"[Helios] CEF Initialize starting...");

    // Load the CEF framework library at runtime (required on macOS).
    if (!g_library_loader.LoadInMain()) {
        NSLog(@"[Helios] Failed to load CEF framework library.");
        return;
    }
    NSLog(@"[Helios] CEF library loaded successfully.");

    CefMainArgs main_args(0, nullptr);
    CefSettings settings;
    settings.no_sandbox = true;
    settings.windowless_rendering_enabled = false;
    settings.multi_threaded_message_loop = false;
    settings.external_message_pump = false;

    // Set cache path to avoid process singleton warning
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject
                           stringByAppendingPathComponent:@"com.dmendoza.helios-browser/cef_cache"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    CefString(&settings.root_cache_path) = cachePath.UTF8String;

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *executablePath = [mainBundle executablePath];
    NSString *bundlePath = [mainBundle bundlePath];

    // Construct framework path manually (versioned layout created by Run Script)
    NSString *frameworkPath = [[bundlePath stringByAppendingPathComponent:@"Contents/Frameworks"]
                               stringByAppendingPathComponent:@"Chromium Embedded Framework.framework"];
    BOOL frameworkExists = [[NSFileManager defaultManager] fileExistsAtPath:frameworkPath];
    NSLog(@"[Helios] Framework path: %@ (exists: %d)", frameworkPath, frameworkExists);
    NSLog(@"[Helios] Bundle path: %@", bundlePath);

    if (frameworkExists) {
        CefString(&settings.framework_dir_path) = frameworkPath.UTF8String;
    }
    if (bundlePath.length) {
        CefString(&settings.main_bundle_path) = bundlePath.UTF8String;
    }

    // Helper app for subprocess (required on macOS)
    NSString *appName = [[executablePath lastPathComponent] stringByDeletingPathExtension];
    NSString *helperName = [appName stringByAppendingString:@" Helper"];
    NSString *helperBundlePath = [[bundlePath stringByAppendingPathComponent:@"Contents/Frameworks"]
                                  stringByAppendingPathComponent:[helperName stringByAppendingPathExtension:@"app"]];
    NSString *helperExePath = [[[helperBundlePath stringByAppendingPathComponent:@"Contents"]
                                stringByAppendingPathComponent:@"MacOS"]
                               stringByAppendingPathComponent:helperName];
    NSLog(@"[Helios] Helper exe path: %@", helperExePath);
    NSLog(@"[Helios] Helper exists: %d", [[NSFileManager defaultManager] fileExistsAtPath:helperExePath]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:helperExePath]) {
        // Let CEF use its default macOS helper resolution first.
        // Forcing browser_subprocess_path here can mask helper bundle/layout issues.
        NSLog(@"[Helios] Using default CEF subprocess path resolution.");
    }

    CefRefPtr<HeliosCefApp> app(new HeliosCefApp());
    NSLog(@"[Helios] Calling CefInitialize...");
    if (!CefInitialize(main_args, settings, app, nullptr)) {
        NSLog(@"[Helios] CefInitialize failed.");
        return;
    }
    g_cef_initialized = true;
    NSLog(@"[Helios] CEF initialized successfully!");
    [[NSNotificationCenter defaultCenter] postNotificationName:HeliosCEFDidInitializeNotification object:nil];
}

void HeliosCEFShutdown(void) {
    if (!g_cef_initialized) {
        return;
    }
    // Match the thread that called CefInitialize (AppKit main); avoids crashes if a nested
    // runloop ever delivered termination on another QoS/thread.
    if ([NSThread isMainThread]) {
        HeliosPerformCEFShutdownNow();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            HeliosPerformCEFShutdownNow();
        });
    }
}

void HeliosCEFDoMessageLoopWork(void) {
    if (!g_cef_initialized) return;
    CefDoMessageLoopWork();
}

BOOL HeliosCEFIsInitialized(void) {
    return g_cef_initialized ? YES : NO;
}

extern "C" void HeliosCEFShutdownWithCompletion(void (^completion)(void)) {
    void (^finish)(void) = ^{
        if (completion) {
            completion();
        }
    };
    if (!g_cef_initialized) {
        finish();
        return;
    }
    void (^work)(void) = ^{
        HeliosPerformCEFShutdownNow();
        finish();
    };
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }
}

// MARK: - HeliosCEFBrowserView

@implementation HeliosCEFBrowserView {
    CefRefPtr<HeliosCefClient> _cefClient;
    NSURL *_pendingURL;
    BOOL _waitingForCEF;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        _loading = NO;
        _canGoBack = NO;
        _canGoForward = NO;
        _waitingForCEF = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(heliosCEFWillShutdown:)
                                                     name:HeliosCEFWillShutdownNotification
                                                   object:nil];
    }
    return self;
}

- (void)heliosCEFWillShutdown:(NSNotification *)notification {
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->GetHost()) {
        NSLog(@"[Helios] CloseBrowser(true) for app shutdown");
        _cefClient->browser()->GetHost()->CloseBrowser(true);
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSLog(@"[Helios] viewDidMoveToWindow: window=%@, cefClient=%d, cefReady=%d", self.window, _cefClient ? 1 : 0, HeliosCEFIsInitialized());
    if (self.window && !_cefClient) {
        if (HeliosCEFIsInitialized()) {
            [self createBrowser];
        } else if (!_waitingForCEF) {
            // CEF not yet initialized; wait for notification
            _waitingForCEF = YES;
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(cefDidInitialize:)
                                                         name:HeliosCEFDidInitializeNotification
                                                       object:nil];
            NSLog(@"[Helios] Waiting for CEF initialization...");
        }
    }
}

- (void)cefDidInitialize:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HeliosCEFDidInitializeNotification object:nil];
    _waitingForCEF = NO;
    NSLog(@"[Helios] CEF initialized notification received, creating browser.");
    if (self.window && !_cefClient) {
        [self createBrowser];
    }
}

- (void)createBrowser {
    NSLog(@"[Helios] createBrowser called. CEF initialized: %d", HeliosCEFIsInitialized());
    if (!HeliosCEFIsInitialized()) return;

    NSRect bounds = self.bounds;
    NSLog(@"[Helios] createBrowser bounds: %.0f x %.0f", bounds.size.width, bounds.size.height);
    if (bounds.size.width < 1) bounds.size.width = 800;
    if (bounds.size.height < 1) bounds.size.height = 600;
    CefWindowInfo window_info;
    CefRect cef_bounds(0, 0, (int)bounds.size.width, (int)bounds.size.height);
    window_info.SetAsChild((__bridge CefWindowHandle)self, cef_bounds);

    CefBrowserSettings browser_settings;
    _cefClient = new HeliosCefClient(self);
    // If we have a pending URL, use it as the initial URL instead of about:blank
    std::string initialURL = "about:blank";
    if (_pendingURL) {
        initialURL = _pendingURL.absoluteString.UTF8String;
        NSLog(@"[Helios] Using pending URL as initial: %@", _pendingURL);
    }
    CefBrowserHost::CreateBrowser(window_info, _cefClient.get(), initialURL, browser_settings, nullptr, nullptr);
    NSLog(@"[Helios] CreateBrowser called successfully.");
}

- (void)browserDidCreate {
    NSLog(@"[Helios] browserDidCreate called, pendingURL=%@", _pendingURL);
    [self setNeedsLayout:YES];
    [self layoutSubtreeIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout:YES];
        [self layoutSubtreeIfNeeded];
    });
    if (_pendingURL && _cefClient && _cefClient->browser()) {
        CefRefPtr<CefFrame> frame = _cefClient->browser()->GetMainFrame();
        if (frame) {
            NSLog(@"[Helios] Loading pending URL: %@", _pendingURL.absoluteString);
            frame->LoadURL(_pendingURL.absoluteString.UTF8String);
        }
        _pendingURL = nil;
    }
}

- (void)layout {
    [super layout];
    // Keep any embedded CEF child NSViews exactly pinned to the container.
    const NSRect bounds = self.bounds;
    HeliosForceResizeDescendants(self, bounds);

    if (_cefClient && _cefClient->browser() && _cefClient->browser()->GetHost()) {
        CefWindowHandle childHandle = _cefClient->browser()->GetHost()->GetWindowHandle();
        if (childHandle) {
            NSView *childView = (__bridge NSView *)childHandle;
            if (childView) {
                [childView setFrame:bounds];
                childView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
                HeliosForceResizeDescendants(childView, bounds);
            }
        }
        _cefClient->browser()->GetHost()->WasResized();
        _cefClient->browser()->GetHost()->NotifyMoveOrResizeStarted();
        _cefClient->browser()->GetHost()->Invalidate(PET_VIEW);
    }
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
}

- (void)updateFromBrowser {
    if (!_cefClient || !_cefClient->browser()) return;
    CefRefPtr<CefBrowser> b = _cefClient->browser();
    _canGoBack = b->CanGoBack();
    _canGoForward = b->CanGoForward();
    [self notifyStateChange];
}

- (void)applyLoadingStateFromCEF:(BOOL)isLoading canGoBack:(BOOL)canGoBack canGoForward:(BOOL)canGoForward {
    _loading = isLoading;
    _canGoBack = canGoBack;
    _canGoForward = canGoForward;
    [self notifyStateChange];
}

- (void)syncNavigationFlagsFromBrowser {
    if (!_cefClient || !_cefClient->browser()) {
        return;
    }
    CefRefPtr<CefBrowser> b = _cefClient->browser();
    _canGoBack = b->CanGoBack();
    _canGoForward = b->CanGoForward();
}

- (void)notifyStateChange {
    id<HeliosCEFBrowserViewDelegate> d = self.delegate;
    if (!d) return;
    NSURL *url = nil;
    NSString *title = @"";
    if (_cefClient) {
        if (_cefClient->browser()) {
            CefRefPtr<CefFrame> frame = _cefClient->browser()->GetMainFrame();
            if (frame) {
                std::string u = frame->GetURL();
                if (!u.empty()) {
                    url = [NSURL URLWithString:[NSString stringWithUTF8String:u.c_str()]];
                }
            }
            // Do not overwrite _canGoBack / _canGoForward here: OnLoadingStateChange already
            // delivered the authoritative values, and browser()->CanGoBack() can briefly lag.
        }
        std::string t = _cefClient->GetPageTitle();
        if (!t.empty()) {
            title = [NSString stringWithUTF8String:t.c_str()];
        }
    }
    [d cefBrowserView:self didLoadURL:url title:title canGoBack:_canGoBack canGoForward:_canGoForward loading:_loading];
}

- (void)loadURL:(NSURL *)url {
    NSLog(@"[Helios] loadURL: %@, cefClient=%d, browser=%d", url, _cefClient ? 1 : 0, (_cefClient && _cefClient->browser()) ? 1 : 0);
    if (!_cefClient || !_cefClient->browser()) {
        // Browser not yet created; store URL and load once ready
        _pendingURL = url;
        NSLog(@"[Helios] Browser not ready, storing pending URL: %@", url);
        return;
    }
    CefRefPtr<CefFrame> frame = _cefClient->browser()->GetMainFrame();
    if (frame) {
        NSLog(@"[Helios] Loading URL in CEF frame: %@", url.absoluteString);
        frame->LoadURL(url.absoluteString.UTF8String);
    }
}

- (void)navigateBack {
    if (!_cefClient || !_cefClient->browser() || !_cefClient->browser()->GetHost()) {
        NSLog(@"[Helios] navigateBack: no browser");
        return;
    }
    NSLog(@"[Helios] navigateBack invoked");
    _cefClient->browser()->GetHost()->SetFocus(true);
    _cefClient->browser()->GoBack();
    // Navigation is scheduled; pump now so the UI thread doesn't wait for the next timer tick.
    HeliosPumpCEFMessageLoop(96);
}

- (void)navigateForward {
    if (!_cefClient || !_cefClient->browser() || !_cefClient->browser()->GetHost()) {
        NSLog(@"[Helios] navigateForward: no browser");
        return;
    }
    NSLog(@"[Helios] navigateForward invoked");
    _cefClient->browser()->GetHost()->SetFocus(true);
    _cefClient->browser()->GoForward();
    HeliosPumpCEFMessageLoop(96);
}

- (void)reloadPage {
    if (!_cefClient || !_cefClient->browser() || !_cefClient->browser()->GetHost()) {
        NSLog(@"[Helios] reloadPage: no browser");
        return;
    }
    NSLog(@"[Helios] reloadPage invoked");
    _cefClient->browser()->GetHost()->SetFocus(true);
    _cefClient->browser()->Reload();
    HeliosPumpCEFMessageLoop(96);
}

- (void)goBack { [self navigateBack]; }
- (void)goForward { [self navigateForward]; }
- (void)reload { [self reloadPage]; }

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->GetHost()) {
        _cefClient->browser()->GetHost()->CloseBrowser(true);
    }
    _cefClient = nullptr;
}

@end

#else // !USE_CEF

NSString * const HeliosCEFWillShutdownNotification = @"HeliosCEFWillShutdownNotification";

// Stub implementation when CEF is not linked
void HeliosCEFInitialize(void) {}
void HeliosCEFShutdown(void) {}
extern "C" void HeliosCEFShutdownWithCompletion(void (^completion)(void)) {
    if (completion) {
        completion();
    }
}
void HeliosCEFDoMessageLoopWork(void) {}
BOOL HeliosCEFIsInitialized(void) { return NO; }

@interface HeliosCEFBrowserView ()
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL canGoBack;
@property (nonatomic, assign) BOOL canGoForward;
@end

@implementation HeliosCEFBrowserView
- (void)loadURL:(NSURL *)url {}
- (void)goBack {}
- (void)goForward {}
- (void)reload {}
- (void)navigateBack {}
- (void)navigateForward {}
- (void)reloadPage {}
@end

#endif
