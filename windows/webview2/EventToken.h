/* Minimal stand-in for the Windows SDK header EventToken.h.
 *
 * The official Microsoft WebView2.h includes "EventToken.h", which ships with the Windows SDK
 * but is missing from the mingw-w64 headers Zig bundles. Both tokens below have been a single
 * 64-bit value since Windows 8 (EventToken lives in EventToken.h, EventRegistrationToken in
 * the WinRT foundation header) and WebView2 uses them for its event registration pairs, so
 * these declarations match the SDK exactly and let WebView2.h compile with
 * `zig c++ -target x86_64-windows-gnu` on any host, with no Windows SDK installed.
 *
 * CI cross-checks the vendored WebView2.h against the official Microsoft.Web.WebView2 NuGet
 * package; this shim is the only hand-written part of the WebView2 dependency.
 */
#ifndef PHYSICS_DRAW_WEBVIEW2_EVENT_TOKEN_H
#define PHYSICS_DRAW_WEBVIEW2_EVENT_TOKEN_H

#ifndef _EVENT_TOKEN_H_
#define _EVENT_TOKEN_H_

typedef struct EventToken {
    __int64 value;
} EventToken;

#endif

#ifndef _WINRT_EVENTREGISTRATIONTOKEN_DEFINED
#define _WINRT_EVENTREGISTRATIONTOKEN_DEFINED

typedef struct EventRegistrationToken {
    __int64 value;
} EventRegistrationToken;

#endif

#endif
