/* One-Line Physics Draw - offline Windows launcher
 *
 * The self-contained offline build of index.html is compiled into the executable
 * (generated_assets.h). At start-up the launcher serves that page on
 * http://127.0.0.1:<port>/ and opens the default browser.
 *
 * Why a loopback server instead of just opening the HTML file?
 * Chromium browsers (Edge, Chrome, Brave, Opera) give file:// documents an opaque origin and
 * refuse localStorage for them, which would silently throw away unlocked levels, stars, hints
 * and the language setting. Serving from http://127.0.0.1:<port> keeps the origin stable, so
 * progress persists exactly like the web and Android builds. The page itself is inlined, so no
 * internet connection is required at any point.
 *
 * Build (Zig cross-compiles from Linux/macOS/Windows, no MSVC or MinGW install needed):
 *   zig cc -O2 -target x86_64-windows-gnu -o Physics-Draw.exe launcher.c -lws2_32 -lshell32
 * The same source builds for POSIX hosts, which is how CI tests the serving logic:
 *   zig cc -O2 -target x86_64-linux-gnu -o physics-draw-launcher-test launcher.c
 */

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <shellapi.h>
typedef SOCKET sock_t;
#define SOCK_INVALID INVALID_SOCKET
#define SOCK_ERRNO WSAGetLastError()
#define SOCK_IN_USE WSAEADDRINUSE
#define sock_close closesocket
#else
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
typedef int sock_t;
#define SOCK_INVALID (-1)
#define SOCK_ERRNO errno
#define SOCK_IN_USE EADDRINUSE
#define sock_close close
#endif

#include <stdio.h>
#include <string.h>

#include "generated_assets.h"

#define DEFAULT_PORT 4173
#define PORT_CANDIDATES 12
#define HEALTH_PATH "/__physics-draw/health"
#define IO_TIMEOUT_MS 5000
#define REQUEST_BUFFER 4096

static sock_t listening_socket = SOCK_INVALID;
static int running = 1;

/* --------------------------------------------------------------- helpers --- */

static void log_line(const char *message) {
    printf("%s\n", message);
    fflush(stdout);
}

static int send_all(sock_t client, const char *data, size_t length) {
    size_t sent = 0;
    while (sent < length) {
        int chunk = (int)((length - sent) > 65536 ? 65536 : (length - sent));
        int written = send(client, data + sent, chunk, 0);
        if (written <= 0) {
            return 0;
        }
        sent += (size_t)written;
    }
    return 1;
}

static void send_response(sock_t client,
                          int status,
                          const char *status_text,
                          const char *content_type,
                          const unsigned char *body,
                          size_t body_length,
                          int headers_only) {
    char header[512];
    int header_length = snprintf(header,
                                 sizeof(header),
                                 "HTTP/1.1 %d %s\r\n"
                                 "Content-Type: %s\r\n"
                                 "Content-Length: %lu\r\n"
                                 "Cache-Control: no-store\r\n"
                                 "X-Content-Type-Options: nosniff\r\n"
                                 "Connection: close\r\n"
                                 "\r\n",
                                 status,
                                 status_text,
                                 content_type,
                                 (unsigned long)body_length);
    if (header_length <= 0 || header_length >= (int)sizeof(header)) {
        return;
    }
    if (!send_all(client, header, (size_t)header_length)) {
        return;
    }
    if (!headers_only && body_length > 0) {
        send_all(client, (const char *)body, body_length);
    }
}

static void health_body(char *buffer, size_t size) {
    snprintf(buffer,
             size,
             "{\"app\":\"%s\",\"version\":\"%s\",\"asset\":\"index.html\",\"asset_bytes\":%lu}",
             HEALTH_TOKEN,
             APP_VERSION,
             (unsigned long)INDEX_HTML_LEN);
}

static void handle_client(sock_t client) {
    char request[REQUEST_BUFFER];
    int received = recv(client, request, (int)sizeof(request) - 1, 0);
    if (received <= 0) {
        return;
    }
    request[received] = '\0';

    char method[16] = {0};
    char target[1024] = {0};
    if (sscanf(request, "%15s %1023s", method, target) != 2) {
        send_response(client, 400, "Bad Request", "text/plain; charset=utf-8",
                      (const unsigned char *)"Bad Request", 11, 0);
        return;
    }

    /* Ignore any query string; the launcher only serves fixed assets. */
    char *query = strchr(target, '?');
    if (query != NULL) {
        *query = '\0';
    }

    int headers_only = (strcmp(method, "HEAD") == 0);
    if (strcmp(method, "GET") != 0 && !headers_only) {
        send_response(client, 405, "Method Not Allowed", "text/plain; charset=utf-8",
                      (const unsigned char *)"Method Not Allowed", 20, headers_only);
        return;
    }

    if (strcmp(target, "/") == 0 || strcmp(target, "/index.html") == 0) {
        send_response(client, 200, "OK", "text/html; charset=utf-8",
                      INDEX_HTML, INDEX_HTML_LEN, headers_only);
        return;
    }
    if (strcmp(target, "/favicon.ico") == 0) {
        send_response(client, 200, "OK", "image/png",
                      FAVICON_PNG, FAVICON_PNG_LEN, headers_only);
        return;
    }
    if (strcmp(target, HEALTH_PATH) == 0) {
        char body[256];
        health_body(body, sizeof(body));
        send_response(client, 200, "OK", "application/json; charset=utf-8",
                      (const unsigned char *)body, strlen(body), headers_only);
        return;
    }

    send_response(client, 404, "Not Found", "text/plain; charset=utf-8",
                  (const unsigned char *)"Not Found", 9, headers_only);
}

/* ---------------------------------------------------------------- server --- */

static void set_io_timeouts(sock_t socket_fd) {
#ifdef _WIN32
    DWORD timeout = IO_TIMEOUT_MS;
    setsockopt(socket_fd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&timeout, sizeof(timeout));
    setsockopt(socket_fd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&timeout, sizeof(timeout));
#else
    struct timeval timeout;
    timeout.tv_sec = IO_TIMEOUT_MS / 1000;
    timeout.tv_usec = (IO_TIMEOUT_MS % 1000) * 1000;
    setsockopt(socket_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(socket_fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
#endif
}

static sock_t start_server(int port) {
    sock_t server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd == SOCK_INVALID) {
        return SOCK_INVALID;
    }

#ifdef _WIN32
    /* SO_EXCLUSIVEADDRUSE: never hijack a port another process already owns. */
    BOOL exclusive = TRUE;
    setsockopt(server_fd, SOL_SOCKET, SO_EXCLUSIVEADDRUSE, (const char *)&exclusive, sizeof(exclusive));
#else
    int reuse = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
#endif

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons((unsigned short)port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK); /* 127.0.0.1 only - never the LAN */

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        sock_close(server_fd);
        return SOCK_INVALID;
    }
    if (listen(server_fd, 16) != 0) {
        sock_close(server_fd);
        return SOCK_INVALID;
    }
    return server_fd;
}

static int bind_any_port(sock_t server_fd, int *port_out) {
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        return 0;
    }
    if (listen(server_fd, 16) != 0) {
        return 0;
    }
    socklen_t length = sizeof(address);
    if (getsockname(server_fd, (struct sockaddr *)&address, &length) != 0) {
        return 0;
    }
    *port_out = ntohs(address.sin_port);
    return 1;
}

/* Returns 1 when another copy of this launcher already owns the port. */
static int probe_running(int port) {
    sock_t client = socket(AF_INET, SOCK_STREAM, 0);
    if (client == SOCK_INVALID) {
        return 0;
    }
    set_io_timeouts(client);

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons((unsigned short)port);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    int matched = 0;
    if (connect(client, (struct sockaddr *)&address, sizeof(address)) == 0) {
        const char *request = "GET " HEALTH_PATH " HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
        if (send_all(client, request, strlen(request))) {
            char body[1024];
            int received = recv(client, body, (int)sizeof(body) - 1, 0);
            if (received > 0) {
                body[received] = '\0';
                matched = (strstr(body, "\"" HEALTH_TOKEN "\"") != NULL);
            }
        }
    }
    sock_close(client);
    return matched;
}

static void serve_forever(void) {
    while (running) {
        struct sockaddr_in peer;
        memset(&peer, 0, sizeof(peer));
        socklen_t peer_length = sizeof(peer);
        sock_t client = accept(listening_socket, (struct sockaddr *)&peer, &peer_length);
        if (client == SOCK_INVALID) {
            if (!running) {
                break;
            }
#ifdef _WIN32
            int error = SOCK_ERRNO;
            if (error == WSAEINTR || error == WSAECONNABORTED) {
                continue;
            }
#else
            int error = SOCK_ERRNO;
            if (error == EINTR || error == ECONNABORTED) {
                continue;
            }
#endif
            continue;
        }
        set_io_timeouts(client);
        handle_client(client);
        shutdown(client, 2);
        sock_close(client);
    }
}

/* --------------------------------------------------------------- browser --- */

static void open_browser(const char *url) {
#ifdef _WIN32
    wchar_t wide_url[256];
    size_t index = 0;
    while (url[index] != '\0' && index < (sizeof(wide_url) / sizeof(wchar_t)) - 1) {
        wide_url[index] = (wchar_t)url[index];
        index += 1;
    }
    wide_url[index] = L'\0';
    HINSTANCE result = ShellExecuteW(NULL, L"open", wide_url, NULL, NULL, SW_SHOWNORMAL);
    if ((INT_PTR)result <= 32) {
        printf("Could not open a browser automatically (ShellExecute error %ld).\n",
               (long)(INT_PTR)result);
        printf("Open this address by hand: %s\n", url);
        fflush(stdout);
    }
#else
    char command[512];
    snprintf(command, sizeof(command), "xdg-open '%s' >/dev/null 2>&1 &", url);
    if (system(command) != 0) {
        printf("Open this address by hand: %s\n", url);
        fflush(stdout);
    }
#endif
}

/* ------------------------------------------------------------- lifecycle --- */

#ifdef _WIN32
static BOOL WINAPI console_handler(DWORD signal) {
    (void)signal;
    running = 0;
    if (listening_socket != SOCK_INVALID) {
        sock_close(listening_socket);
        listening_socket = SOCK_INVALID;
    }
    WSACleanup();
    return FALSE; /* let the default handler terminate the process */
}
#else
static void signal_handler(int signal) {
    (void)signal;
    running = 0;
    if (listening_socket != SOCK_INVALID) {
        sock_close(listening_socket);
        listening_socket = SOCK_INVALID;
    }
}
#endif

static void usage(void) {
    printf("%s %s\n\n", APP_NAME, APP_VERSION);
    printf("Usage: Physics-Draw.exe [options]\n\n");
    printf("  --port <port>      serve on a fixed port (default %d, 0 = any free port)\n", DEFAULT_PORT);
    printf("  --no-browser       do not open the default browser\n");
    printf("  --extract <file>   write the embedded offline index.html to <file> and exit\n");
    printf("  --print-url        print the serving address and exit without opening a browser\n");
    printf("  --version          print the launcher version and exit\n");
    printf("  --help             show this help\n");
}

static int extract_asset(const char *destination) {
    FILE *file = fopen(destination, "wb");
    if (file == NULL) {
        printf("Could not write %s\n", destination);
        return 1;
    }
    size_t written = fwrite(INDEX_HTML, 1, INDEX_HTML_LEN, file);
    fclose(file);
    if (written != INDEX_HTML_LEN) {
        printf("Incomplete write to %s\n", destination);
        return 1;
    }
    printf("Wrote the offline build to %s (%lu bytes)\n", destination, (unsigned long)INDEX_HTML_LEN);
    return 0;
}

int main(int argc, char **argv) {
    int requested_port = DEFAULT_PORT;
    int open_default_browser = 1;
    int print_url_only = 0;

    for (int index = 1; index < argc; index += 1) {
        const char *arg = argv[index];
        if (strcmp(arg, "--help") == 0 || strcmp(arg, "-h") == 0) {
            usage();
            return 0;
        }
        if (strcmp(arg, "--version") == 0 || strcmp(arg, "-v") == 0) {
            printf("%s %s\n", APP_NAME, APP_VERSION);
            return 0;
        }
        if (strcmp(arg, "--no-browser") == 0) {
            open_default_browser = 0;
            continue;
        }
        if (strcmp(arg, "--print-url") == 0) {
            print_url_only = 1;
            open_default_browser = 0;
            continue;
        }
        if (strcmp(arg, "--extract") == 0) {
            if (index + 1 >= argc) {
                printf("--extract needs a file path\n");
                return 2;
            }
            return extract_asset(argv[index + 1]);
        }
        if (strcmp(arg, "--port") == 0) {
            if (index + 1 >= argc) {
                printf("--port needs a number\n");
                return 2;
            }
            requested_port = atoi(argv[index + 1]);
            index += 1;
            continue;
        }
        if (strncmp(arg, "--port=", 7) == 0) {
            requested_port = atoi(arg + 7);
            continue;
        }
        printf("Unknown option: %s\n\n", arg);
        usage();
        return 2;
    }

    if (requested_port < 0 || requested_port > 65535) {
        printf("Port %d is out of range\n", requested_port);
        return 2;
    }

#ifdef _WIN32
    WSADATA wsa_data;
    if (WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
        log_line("Winsock could not start (WSAStartup failed).");
        return 1;
    }
    SetConsoleCtrlHandler(console_handler, TRUE);
#else
    signal(SIGPIPE, SIG_IGN);
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
#endif

    int port = 0;
    /* --port 0 asks the OS for any free loopback port (used by the CI self-test). */
    if (requested_port == 0) {
        listening_socket = socket(AF_INET, SOCK_STREAM, 0);
        if (listening_socket == SOCK_INVALID || !bind_any_port(listening_socket, &port)) {
            log_line("Could not open a loopback port.");
#ifdef _WIN32
            WSACleanup();
#endif
            return 1;
        }
    }

    for (int offset = 0; requested_port != 0 && offset < PORT_CANDIDATES; offset += 1) {
        int candidate = requested_port + offset;
        if (candidate > 65535) {
            break;
        }
        listening_socket = start_server(candidate);
        if (listening_socket != SOCK_INVALID) {
            port = candidate;
            break;
        }
        if (SOCK_ERRNO != SOCK_IN_USE) {
            continue;
        }
        if (probe_running(candidate)) {
            char url[64];
            snprintf(url, sizeof(url), "http://127.0.0.1:%d/", candidate);
            printf("%s is already running at %s\n", APP_NAME, url);
            if (open_default_browser) {
                open_browser(url);
            }
#ifdef _WIN32
            WSACleanup();
#endif
            return 0;
        }
    }

    if (listening_socket == SOCK_INVALID) {
        /* Every preferred port is taken by unrelated software: fall back to a free one. */
        listening_socket = socket(AF_INET, SOCK_STREAM, 0);
        if (listening_socket == SOCK_INVALID || !bind_any_port(listening_socket, &port)) {
            log_line("Could not open a loopback port. Nothing else is listening on the network.");
#ifdef _WIN32
            WSACleanup();
#endif
            return 1;
        }
    }

    char url[64];
    snprintf(url, sizeof(url), "http://127.0.0.1:%d/", port);

    if (print_url_only) {
        printf("%s\n", url);
        sock_close(listening_socket);
        listening_socket = SOCK_INVALID;
#ifdef _WIN32
        WSACleanup();
#endif
        return 0;
    }

    printf("%s %s\n", APP_NAME, APP_VERSION);
    printf("Offline build served at %s\n", url);
    printf("Nothing is downloaded: the page, Matter.js, icons and fonts are inside this executable.\n");
    printf("Your browser saves progress for that address, so keep the port stable.\n");
#ifdef _WIN32
    log_line("Keep this window open while playing. Close it (or press Ctrl+C) to stop.");
#else
    log_line("Keep this process running while playing. Press Ctrl+C to stop.");
#endif

    if (open_default_browser) {
        open_browser(url);
    }

    serve_forever();

    if (listening_socket != SOCK_INVALID) {
        sock_close(listening_socket);
        listening_socket = SOCK_INVALID;
    }
#ifdef _WIN32
    WSACleanup();
#endif
    return 0;
}
