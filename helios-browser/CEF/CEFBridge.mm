//
//  CEFBridge.mm
//  helios-browser
//
//  CEF initialization and NSView that hosts a CEF browser. Requires CEF framework.
//

#import "CEFBridge.h"
#import <Foundation/Foundation.h>

#if USE_CEF
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_display_handler.h"
#include "include/cef_sandbox_mac.h"
#include "include/wrapper/cef_helpers.h"

// MARK: - CEF App (process-level)

class HeliosCefApp : public CefApp, public CefBrowserProcessHandler {
public:
    HeliosCefApp() = default;
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
    void OnContextInitialized() override {}
private:
    IMPLEMENT_REFCOUNTING(HeliosCefApp);
};

// MARK: - CEF Client (browser-level) and handlers

class HeliosCefClient : public CefClient,
                        public CefLifeSpanHandler,
                        public CefLoadHandler,
                        public CefDisplayHandler {
public:
    explicit HeliosCefClient(HeliosCEFBrowserView *view) : view_(view) {}
    std::string GetPageTitle() const { return page_title_; }

    CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
    CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
    CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }

    void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
        browser_ = browser;
    }

    void OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int transition_type) override {
        if (frame->IsMain()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->view_ setLoading:YES];
                [self->view_ notifyStateChange];
            });
        }
    }

    void OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int httpStatusCode) override {
        if (frame->IsMain()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->view_ setLoading:NO];
                [self->view_ updateFromBrowser];
            });
        }
    }

    void OnLoadError(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, ErrorCode errorCode,
                     const CefString& errorText, const CefString& failedUrl) override {
        if (frame->IsMain()) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->view_ setLoading:NO];
                [self->view_ updateFromBrowser];
            });
        }
    }

    void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) override {
        page_title_ = title.ToString();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->view_ updateFromBrowser];
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

static bool g_cef_initialized = false;

void HeliosCEFInitialize(void) {
    if (g_cef_initialized) return;

#if defined(CEF_USE_SANDBOX)
    CefScopedSandboxContext sandbox_context;
    bool ok = sandbox_context.Initialize(0, nullptr);
    if (!ok) return;
#endif

    CefMainArgs main_args(0, nullptr);
    CefSettings settings;
    settings.no_sandbox = true;
    settings.windowless_rendering_enabled = false;
    settings.multi_threaded_message_loop = false;

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *frameworkPath = [mainBundle pathForResource:@"Chromium Embedded Framework" ofType:@"framework" inDirectory:@"Frameworks"];
    NSString *executablePath = [mainBundle executablePath];
    NSString *bundlePath = [mainBundle bundlePath];

    if (frameworkPath.length) {
        settings.framework_dir_path = [frameworkPath stringByDeletingLastPathComponent].UTF8String;
    }
    if (bundlePath.length) {
        settings.main_bundle_path = bundlePath.UTF8String;
    }

    // Helper app for subprocess (required on macOS)
    NSString *helperName = [[executablePath lastPathComponent] stringByDeletingPathExtension];
    helperName = [helperName stringByAppendingString:@" Helper"];
    NSString *helperPath = [NSString pathWithComponents:@[
        bundlePath, @"Contents", @"Frameworks", helperName, @"Contents", @"MacOS", helperName
    ]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:helperPath]) {
        settings.browser_subprocess_path = helperPath.UTF8String;
    }

    CefRefPtr<HeliosCefApp> app(new HeliosCefApp());
    if (!CefInitialize(main_args, settings, app, nullptr)) {
        return;
    }
    g_cef_initialized = true;
}

void HeliosCEFShutdown(void) {
    if (!g_cef_initialized) return;
    CefShutdown();
    g_cef_initialized = false;
}

void HeliosCEFDoMessageLoopWork(void) {
    if (!g_cef_initialized) return;
    CefDoMessageLoopWork();
}

BOOL HeliosCEFIsInitialized(void) {
    return g_cef_initialized ? YES : NO;
}

// MARK: - HeliosCEFBrowserView

@interface HeliosCEFBrowserView ()
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL canGoBack;
@property (nonatomic, assign) BOOL canGoForward;
@end

@implementation HeliosCEFBrowserView {
    CefRefPtr<HeliosCefClient> _cefClient;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        _loading = NO;
        _canGoBack = NO;
        _canGoForward = NO;
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window && !_cefClient) {
        [self createBrowser];
    }
}

- (void)createBrowser {
    if (!HeliosCEFIsInitialized()) return;

    NSRect bounds = self.bounds;
    if (bounds.size.width < 1) bounds.size.width = 800;
    if (bounds.size.height < 1) bounds.size.height = 600;
    CefWindowInfo window_info;
    window_info.SetAsChild((__bridge void *)self, 0, 0, (int)bounds.size.width, (int)bounds.size.height);

    CefBrowserSettings browser_settings;
    _cefClient = new HeliosCefClient(self);
    CefBrowserHost::CreateBrowser(window_info, _cefClient.get(), "https://apple.com", browser_settings, nullptr);
}

- (void)layout {
    [super layout];
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->GetHost()) {
        _cefClient->browser()->GetHost()->NotifyMoveOrResizeStarted();
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
            _canGoBack = _cefClient->browser()->CanGoBack();
            _canGoForward = _cefClient->browser()->CanGoForward();
        }
        std::string t = _cefClient->GetPageTitle();
        if (!t.empty()) {
            title = [NSString stringWithUTF8String:t.c_str()];
        }
    }
    [d cefBrowserView:self didLoadURL:url title:title canGoBack:_canGoBack canGoForward:_canGoForward loading:_loading];
}

- (void)loadURL:(NSURL *)url {
    if (!_cefClient || !_cefClient->browser()) return;
    CefRefPtr<CefFrame> frame = _cefClient->browser()->GetMainFrame();
    if (frame) {
        frame->LoadURL(url.absoluteString.UTF8String);
    }
}

- (void)goBack {
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->CanGoBack()) {
        _cefClient->browser()->GoBack();
    }
}

- (void)goForward {
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->CanGoForward()) {
        _cefClient->browser()->GoForward();
    }
}

- (void)reload {
    if (_cefClient && _cefClient->browser()) {
        _cefClient->browser()->GetMainFrame()->Reload();
    }
}

- (void)dealloc {
    if (_cefClient && _cefClient->browser() && _cefClient->browser()->GetHost()) {
        _cefClient->browser()->GetHost()->CloseBrowser(true);
    }
}

@end

#else // !USE_CEF

// Stub implementation when CEF is not linked
void HeliosCEFInitialize(void) {}
void HeliosCEFShutdown(void) {}
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
@end

#endif
