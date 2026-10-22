/* One-Line Physics Draw - windowed Windows app (WebView2)
 *
 * This is the Store-eligible flavour: the game runs inside its own window through the Microsoft
 * Edge WebView2 runtime instead of opening the system browser, so it needs no loopback server.
 * That matters for MSIX: packaged apps run in an AppContainer where loopback traffic to a
 * browser outside the container is blocked, which is exactly what windows/launcher.c relies on.
 *
 * The offline page is served to the WebView from a virtual host mapped onto the `www` folder
 * next to the executable:
 *
 *     https://physicsdraw.local/index.html   ->   <exe dir>/www/index.html
 *
 * A real http(s) origin (rather than file://) is what makes localStorage work, so unlocked
 * levels, stars, hints and the language persist - inside MSIX they persist in the package's
 * own local state, which Windows manages and removes on uninstall.
 *
 * Build (cross-compiles from Linux/macOS/Windows with Zig, no Windows SDK needed):
 *   node scripts/build-store.mjs
 * which fetches the SDK header, generates webview2-iids.h plus the resource script, and runs the
 * equivalent of:
 *   zig c++ -O2 -std=c++17 -target x86_64-windows-gnu -municode -Wl,--subsystem,windows \
 *       -I<windows/build/webview2>/include -Iwindows/webview2 \
 *       -o PhysicsDraw.exe webview2-host.cpp store.rc -lole32 -luser32 -lshell32
 *
 * Runtime needs WebView2Loader.dll next to the executable plus the evergreen WebView2 runtime,
 * which ships with Windows 11 and current Windows 10. When either is missing the app explains
 * what to do instead of failing silently.
 */

#include <windows.h>
#include <string>

#include "WebView2.h"
#include "webview2-iids.h"  /* generated: GUID constants, see scripts/build-store.mjs */

#ifndef APP_NAME
#define APP_NAME "One-Line Physics Draw"
#endif
#ifndef APP_VERSION
#define APP_VERSION "1.0.0"
#endif
#ifndef VIRTUAL_HOST
#define VIRTUAL_HOST L"physicsdraw.local"
#endif
#ifndef WEBVIEW2_LOADER
#define WEBVIEW2_LOADER L"WebView2Loader.dll"
#endif

#define WIDEN_(literal) L##literal
#define WIDEN(literal) WIDEN_(literal)

#define IDI_APP 101
#define DESIGN_CLIENT_WIDTH 520
#define DESIGN_CLIENT_HEIGHT 900
#define MIN_CLIENT_WIDTH 360
#define MIN_CLIENT_HEIGHT 520

namespace {

HWND g_window = nullptr;
ICoreWebView2Controller *g_controller = nullptr;
ICoreWebView2 *g_webview = nullptr;
bool g_enable_devtools = false;

typedef HRESULT(WINAPI *CreateEnvironmentFn)(PCWSTR browserExecutableFolder,
                                             PCWSTR userDataFolder,
                                             ICoreWebView2EnvironmentOptions *environmentOptions,
                                             ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *handler);

void report_failure(const wchar_t *context, HRESULT hr) {
    wchar_t message[512];
    swprintf(message, 512, L"%s\n\nHRESULT 0x%08lX", context, static_cast<unsigned long>(hr));
    MessageBoxW(g_window, message, WIDEN(APP_NAME) L" " WIDEN(APP_VERSION), MB_OK | MB_ICONERROR);
}

void report_missing_runtime() {
    const int choice = MessageBoxW(
        g_window,
        L"This app uses the Microsoft Edge WebView2 runtime, which is not installed.\n\n"
        L"Windows 11 and up-to-date Windows 10 include it. If yours does not, install the "
        L"\"Evergreen Standalone Installer\" from Microsoft's WebView2 page, then start the "
        L"app again.\n\n"
        L"Open the WebView2 download page now?",
        WIDEN(APP_NAME) L" - WebView2 runtime missing",
        MB_YESNO | MB_ICONWARNING);
    if (choice == IDYES) {
        ShellExecuteW(nullptr,
                      L"open",
                      L"https://developer.microsoft.com/microsoft-edge/webview2/",
                      nullptr,
                      nullptr,
                      SW_SHOWNORMAL);
    }
}

std::wstring executable_directory() {
    wchar_t buffer[MAX_PATH * 2] = {0};
    DWORD length = GetModuleFileNameW(nullptr, buffer, static_cast<DWORD>(sizeof(buffer) / sizeof(wchar_t)) - 1);
    if (length == 0 || length >= sizeof(buffer) / sizeof(wchar_t) - 1) {
        return std::wstring();
    }
    std::wstring path(buffer, length);
    size_t slash = path.find_last_of(L"\\/");
    return slash == std::wstring::npos ? std::wstring() : path.substr(0, slash);
}

bool make_directory_tree(const std::wstring &path) {
    if (path.empty()) {
        return false;
    }
    DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
        return true;
    }
    size_t slash = path.find_last_of(L"\\/");
    if (slash != std::wstring::npos && slash > 0) {
        if (!make_directory_tree(path.substr(0, slash))) {
            return false;
        }
    }
    return CreateDirectoryW(path.c_str(), nullptr) != FALSE || GetLastError() == ERROR_ALREADY_EXISTS;
}

/* Packaged (MSIX) apps must let WebView2 pick the user data folder inside the package's own
 * state; unpackaged runs keep their profile next to the other user data in %LOCALAPPDATA%. */
bool is_packaged() {
    typedef LONG(WINAPI * GetCurrentPackageFullNameFn)(UINT32 *, PWSTR);
    HMODULE kernel = GetModuleHandleW(L"kernel32.dll");
    if (!kernel) {
        return false;
    }
    auto probe = reinterpret_cast<GetCurrentPackageFullNameFn>(
        reinterpret_cast<void *>(GetProcAddress(kernel, "GetCurrentPackageFullName")));
    if (!probe) {
        return false;
    }
    UINT32 length = 0;
    LONG result = probe(&length, nullptr);
    /* ERROR_INSUFFICIENT_BUFFER means a package full name exists. */
    return result == ERROR_INSUFFICIENT_BUFFER;
}

std::wstring user_data_folder() {
    if (is_packaged()) {
        return std::wstring(); /* nullptr -> WebView2 uses the package's local state */
    }
    wchar_t local[MAX_PATH] = {0};
    if (GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH) == 0) {
        return std::wstring();
    }
    std::wstring folder = std::wstring(local) + L"\\OneLinePhysicsDraw\\WebView2";
    return make_directory_tree(folder) ? folder : std::wstring();
}

void apply_bounds() {
    if (!g_controller || !g_window) {
        return;
    }
    RECT bounds;
    GetClientRect(g_window, &bounds);
    g_controller->put_Bounds(bounds);
}

/* Once the process is per-monitor DPI aware, every window coordinate is a physical pixel, so the
 * 520x900 design client area has to be scaled by the monitor DPI. Without that the notebook would
 * shrink on a 125% or 150% display instead of keeping its real 400x650 CSS pixel size. The
 * Windows 10 entry points are resolved at run time; on anything older we stay at 96 DPI. */
UINT query_dpi(HWND window) {
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32) {
        if (window) {
            typedef UINT(WINAPI * GetDpiForWindowFn)(HWND);
            auto for_window = reinterpret_cast<GetDpiForWindowFn>(
                reinterpret_cast<void *>(GetProcAddress(user32, "GetDpiForWindow")));
            if (for_window) {
                UINT dpi = for_window(window);
                if (dpi > 0) {
                    return dpi;
                }
            }
        }
        typedef UINT(WINAPI * GetDpiForSystemFn)(void);
        auto for_system = reinterpret_cast<GetDpiForSystemFn>(
            reinterpret_cast<void *>(GetProcAddress(user32, "GetDpiForSystem")));
        if (for_system) {
            UINT dpi = for_system();
            if (dpi > 0) {
                return dpi;
            }
        }
    }
    return 96;
}

int scale_by_dpi(int value, UINT dpi) {
    return dpi > 0 && dpi != 96 ? MulDiv(value, static_cast<int>(dpi), 96) : value;
}

/* The non-client area grows with DPI as well, which plain AdjustWindowRectEx does not know. */
void adjust_frame(RECT *frame, DWORD style, UINT dpi) {
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32) {
        typedef BOOL(WINAPI * AdjustWindowRectExForDpiFn)(LPRECT, DWORD, BOOL, DWORD, UINT);
        auto adjust = reinterpret_cast<AdjustWindowRectExForDpiFn>(
            reinterpret_cast<void *>(GetProcAddress(user32, "AdjustWindowRectExForDpi")));
        if (adjust && adjust(frame, style, FALSE, 0, dpi)) {
            return;
        }
    }
    AdjustWindowRectEx(frame, style, FALSE, 0);
}

/* ------------------------------------------------------------ callbacks --- */

class NavigationCompletedHandler final : public ICoreWebView2NavigationCompletedEventHandler {
public:
    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_ref); }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG remaining = InterlockedDecrement(&m_ref);
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppv) override {
        if (!ppv) {
            return E_POINTER;
        }
        if (riid == WEBVIEW2_IID_IUnknown || riid == WEBVIEW2_IID_ICoreWebView2NavigationCompletedEventHandler) {
            *ppv = static_cast<ICoreWebView2NavigationCompletedEventHandler *>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }
    HRESULT STDMETHODCALLTYPE Invoke(ICoreWebView2 *sender, ICoreWebView2NavigationCompletedEventArgs *args) override {
        (void)sender;
        if (!args) {
            return S_OK;
        }
        BOOL success = TRUE;
        args->get_IsSuccess(&success);
        if (!success) {
            COREWEBVIEW2_WEB_ERROR_STATUS status = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
            args->get_WebErrorStatus(&status);
            wchar_t message[256];
            swprintf(message, 256, L"The game page failed to load (web error status %d).", static_cast<int>(status));
            MessageBoxW(g_window, message, WIDEN(APP_NAME), MB_OK | MB_ICONWARNING);
        }
        return S_OK;
    }

private:
    ULONG m_ref = 1;
};

class ControllerHandler final : public ICoreWebView2CreateCoreWebView2ControllerCompletedHandler {
public:
    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_ref); }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG remaining = InterlockedDecrement(&m_ref);
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppv) override {
        if (!ppv) {
            return E_POINTER;
        }
        if (riid == WEBVIEW2_IID_IUnknown || riid == WEBVIEW2_IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) {
            *ppv = static_cast<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    HRESULT STDMETHODCALLTYPE Invoke(HRESULT error_code, ICoreWebView2Controller *controller) override {
        if (FAILED(error_code) || !controller) {
            if (error_code == HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND) ||
                error_code == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
                report_missing_runtime();
            } else {
                report_failure(L"WebView2 could not create its window.", error_code);
            }
            return S_OK;
        }

        g_controller = controller;
        g_controller->AddRef();

        ICoreWebView2 *webview = nullptr;
        HRESULT hr = g_controller->get_CoreWebView2(&webview);
        if (FAILED(hr) || !webview) {
            report_failure(L"WebView2 did not hand back its view.", hr);
            return S_OK;
        }
        g_webview = webview; /* ownership stays with the controller */

        g_controller->put_IsVisible(TRUE);

        /* Match the notebook paper colour so there is no white flash while the page loads.
           put_DefaultBackgroundColor lives on ICoreWebView2Controller2. */
        ICoreWebView2Controller2 *tinted = nullptr;
        if (SUCCEEDED(g_controller->QueryInterface(WEBVIEW2_IID_ICoreWebView2Controller2,
                                                   reinterpret_cast<void **>(&tinted))) &&
            tinted) {
            COREWEBVIEW2_COLOR paper = {255, 0xf7, 0xf0, 0xd8};
            tinted->put_DefaultBackgroundColor(paper);
            tinted->Release();
        }

        ICoreWebView2Settings *settings = nullptr;
        if (SUCCEEDED(g_webview->get_Settings(&settings)) && settings) {
            settings->put_IsStatusBarEnabled(FALSE);
            settings->put_AreDevToolsEnabled(g_enable_devtools ? TRUE : FALSE);
            settings->put_IsZoomControlEnabled(FALSE); /* the page owns its own scaling */
            settings->put_AreDefaultContextMenusEnabled(TRUE);
            settings->put_IsBuiltInErrorPageEnabled(TRUE);
            settings->Release();
        }

        /* Serve www/ next to the executable over a private https origin. */
        ICoreWebView2_3 *host_mapping = nullptr;
        if (SUCCEEDED(g_webview->QueryInterface(WEBVIEW2_IID_ICoreWebView2_3,
                                               reinterpret_cast<void **>(&host_mapping))) &&
            host_mapping) {
            std::wstring www = executable_directory() + L"\\www";
            hr = host_mapping->SetVirtualHostNameToFolderMapping(VIRTUAL_HOST,
                                                                www.c_str(),
                                                                COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
            host_mapping->Release();
            if (FAILED(hr)) {
                report_failure(L"Could not map the game folder to a virtual host.", hr);
                return S_OK;
            }
        } else {
            report_failure(L"This WebView2 runtime is too old for virtual host mapping.", E_NOINTERFACE);
            return S_OK;
        }

        auto navigation_handler = new NavigationCompletedHandler();
        EventRegistrationToken token = {};
        g_webview->add_NavigationCompleted(navigation_handler, &token);
        navigation_handler->Release();

        std::wstring url = std::wstring(L"https://") + VIRTUAL_HOST + L"/index.html";
        hr = g_webview->Navigate(url.c_str());
        if (FAILED(hr)) {
            report_failure(L"Could not start the game page.", hr);
        }

        apply_bounds();
        return S_OK;
    }

private:
    ULONG m_ref = 1;
};

class EnvironmentHandler final : public ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler {
public:
    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_ref); }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG remaining = InterlockedDecrement(&m_ref);
        if (remaining == 0) {
            delete this;
        }
        return remaining;
    }
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppv) override {
        if (!ppv) {
            return E_POINTER;
        }
        if (riid == WEBVIEW2_IID_IUnknown || riid == WEBVIEW2_IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler) {
            *ppv = static_cast<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    HRESULT STDMETHODCALLTYPE Invoke(HRESULT error_code, ICoreWebView2Environment *environment) override {
        if (FAILED(error_code) || !environment) {
            if (error_code == HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND) ||
                error_code == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
                report_missing_runtime();
            } else {
                report_failure(L"WebView2 runtime could not start.", error_code);
            }
            return S_OK;
        }
        HRESULT hr = environment->CreateCoreWebView2Controller(g_window, new ControllerHandler());
        if (FAILED(hr)) {
            report_failure(L"WebView2 refused to create a controller.", hr);
        }
        return S_OK;
    }

private:
    ULONG m_ref = 1;
};

/* -------------------------------------------------------------- winmain --- */

LRESULT CALLBACK window_procedure(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
    case WM_SIZE:
        apply_bounds();
        return 0;
    case WM_GETMINMAXINFO: {
        auto *info = reinterpret_cast<MINMAXINFO *>(lparam);
        UINT dpi = query_dpi(window);
        RECT frame = {0, 0, scale_by_dpi(MIN_CLIENT_WIDTH, dpi), scale_by_dpi(MIN_CLIENT_HEIGHT, dpi)};
        adjust_frame(&frame, static_cast<DWORD>(GetWindowLongPtrW(window, GWL_STYLE)), dpi);
        info->ptMinTrackSize.x = frame.right - frame.left;
        info->ptMinTrackSize.y = frame.bottom - frame.top;
        return 0;
    }
    case WM_DPICHANGED: {
        /* Windows hands over the rectangle the window should occupy on the new monitor; taking it
           keeps the notebook the same size in CSS pixels after the move. */
        auto *suggested = reinterpret_cast<RECT *>(lparam);
        SetWindowPos(window, nullptr, suggested->left, suggested->top,
                     suggested->right - suggested->left, suggested->bottom - suggested->top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
        apply_bounds();
        return 0;
    }
    case WM_CLOSE:
        DestroyWindow(window);
        return 0;
    case WM_DESTROY:
        if (g_controller) {
            g_controller->Close();
            g_controller->Release();
            g_controller = nullptr;
        }
        g_webview = nullptr;
        g_window = nullptr;
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wparam, lparam);
    }
}

int start_webview() {
    std::wstring directory = executable_directory();
    std::wstring loader_path = directory.empty() ? std::wstring(WEBVIEW2_LOADER) : directory + L"\\" + WEBVIEW2_LOADER;

    HMODULE loader = LoadLibraryW(loader_path.c_str());
    if (!loader) {
        loader = LoadLibraryW(WEBVIEW2_LOADER); /* fall back to the DLL search order */
    }
    if (!loader) {
        MessageBoxW(g_window,
                    L"WebView2Loader.dll could not be loaded.\n\n"
                    L"Make sure it sits next to PhysicsDraw.exe, and that the Microsoft Edge "
                    L"WebView2 runtime is installed.",
                    WIDEN(APP_NAME),
                    MB_OK | MB_ICONERROR);
        return 1;
    }

    auto create_environment = reinterpret_cast<CreateEnvironmentFn>(
        reinterpret_cast<void *>(GetProcAddress(loader, "CreateCoreWebView2EnvironmentWithOptions")));
    if (!create_environment) {
        MessageBoxW(g_window,
                    L"WebView2Loader.dll does not export CreateCoreWebView2EnvironmentWithOptions.",
                    WIDEN(APP_NAME),
                    MB_OK | MB_ICONERROR);
        return 1;
    }

    std::wstring folder = user_data_folder();
    HRESULT hr = create_environment(nullptr,
                                    folder.empty() ? nullptr : folder.c_str(),
                                    nullptr,
                                    new EnvironmentHandler());
    if (FAILED(hr)) {
        if (hr == HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND) || hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
            report_missing_runtime();
        } else {
            report_failure(L"CreateCoreWebView2EnvironmentWithOptions failed.", hr);
        }
        return 1;
    }
    return 0;
}

} /* namespace */

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR command_line, int show_command) {
    if (command_line && wcsstr(command_line, L"--devtools")) {
        g_enable_devtools = true;
    }

    HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(com) && com != RPC_E_CHANGED_MODE) {
        return 1;
    }

    /* Per-monitor DPI so the notebook stays crisp on scaled displays. */
    typedef BOOL(WINAPI * SetDpiContextFn)(DPI_AWARENESS_CONTEXT);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32) {
        auto set_context = reinterpret_cast<SetDpiContextFn>(
            reinterpret_cast<void *>(GetProcAddress(user32, "SetProcessDpiAwarenessContext")));
        if (set_context) {
            set_context(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        }
    }

    HICON icon = LoadIconW(instance, MAKEINTRESOURCEW(IDI_APP));

    WNDCLASSEXW window_class = {};
    window_class.cbSize = sizeof(window_class);
    window_class.lpfnWndProc = window_procedure;
    window_class.hInstance = instance;
    window_class.hIcon = icon;
    window_class.hIconSm = icon;
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    window_class.lpszClassName = L"PhysicsDrawPuzzleWindow";
    if (!RegisterClassExW(&window_class)) {
        CoUninitialize();
        return 1;
    }

    /* Default to a client area that shows the notebook at its real 400x650 size, but never
       taller or wider than the work area of the screen it opens on. Both are physical pixels. */
    const UINT initial_dpi = query_dpi(nullptr);
    RECT work_area = {0, 0, DESIGN_CLIENT_WIDTH, DESIGN_CLIENT_HEIGHT};
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
    int client_width = scale_by_dpi(DESIGN_CLIENT_WIDTH, initial_dpi);
    int client_height = scale_by_dpi(DESIGN_CLIENT_HEIGHT, initial_dpi);
    int work_width = work_area.right - work_area.left;
    int work_height = work_area.bottom - work_area.top;
    if (work_width > 0 && client_width > work_width) {
        client_width = work_width;
    }
    if (work_height > 0 && client_height > work_height) {
        client_height = work_height;
    }

    RECT frame = {0, 0, client_width, client_height};
    adjust_frame(&frame, WS_OVERLAPPEDWINDOW, initial_dpi);
    int window_width = frame.right - frame.left;
    int window_height = frame.bottom - frame.top;
    int left = work_area.left + (work_width > window_width ? (work_width - window_width) / 2 : 0);
    int top = work_area.top + (work_height > window_height ? (work_height - window_height) / 2 : 0);

    g_window = CreateWindowExW(0,
                               window_class.lpszClassName,
                               WIDEN(APP_NAME),
                               WS_OVERLAPPEDWINDOW,
                               left,
                               top,
                               window_width,
                               window_height,
                               nullptr,
                               nullptr,
                               instance,
                               nullptr);
    if (!g_window) {
        CoUninitialize();
        return 1;
    }
    ShowWindow(g_window, show_command);
    UpdateWindow(g_window);

    /* When the runtime or the loader DLL is missing, start_webview() has already shown a dialog.
       The window stays open so that dialog keeps an owner and the user can read it. */
    (void)start_webview();

    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }

    CoUninitialize();
    return static_cast<int>(message.wParam);
}
