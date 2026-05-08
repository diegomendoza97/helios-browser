//
//  process_helper_mac.cc
//  helios-browser Helper
//
//  Entry point for the CEF helper subprocess (renderer, GPU, utility).
//

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"
#include <stdio.h>

namespace {
class HeliosHelperApp : public CefApp, public CefBrowserProcessHandler {
public:
    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }

    void OnBeforeCommandLineProcessing(const CefString& process_type,
                                       CefRefPtr<CefCommandLine> command_line) override {
        const std::string type = process_type.ToString();
        fprintf(stderr,
                "[Helios Helper] OnBeforeCommandLineProcessing process_type=%s\n",
                type.empty() ? "(browser)" : type.c_str());
    }

private:
    IMPLEMENT_REFCOUNTING(HeliosHelperApp);
};
}  // namespace

// Entry point function for sub-processes.
int main(int argc, char* argv[]) {
    // Load the CEF framework library at runtime instead of linking directly
    // as required by the macOS sandbox implementation.
    CefScopedLibraryLoader library_loader;
    if (!library_loader.LoadInHelper()) {
        fprintf(stderr, "[Helios Helper] LoadInHelper failed.\n");
        return 1;
    }
    fprintf(stderr, "[Helios Helper] LoadInHelper succeeded.\n");

    // Provide CEF with command-line arguments.
    CefMainArgs main_args(argc, argv);

    // Execute the sub-process.
    CefRefPtr<HeliosHelperApp> app(new HeliosHelperApp());
    const int result = CefExecuteProcess(main_args, app, nullptr);
    fprintf(stderr, "[Helios Helper] CefExecuteProcess exited with %d.\n", result);
    return result;
}
