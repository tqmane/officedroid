/* SPDX-License-Identifier: MIT
 * Exercise the Windows HTTPS stack used by installers, including certificate validation. */
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>

int main(void)
{
    HINTERNET session = NULL, connection = NULL, request = NULL;
    DWORD status = 0, size = sizeof(status), error = 0;
    int result = 1;
    session = WinHttpOpen(L"OfficeDroid network check", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                         WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!session) goto done;
    if (!WinHttpSetTimeouts(session, 15000, 15000, 15000, 15000)) goto done;
    connection = WinHttpConnect(session, L"download.microsoft.com", INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!connection) goto done;
    request = WinHttpOpenRequest(connection, L"HEAD",
        L"/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe",
        NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE);
    if (!request) goto done;
    if (!WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0)) goto done;
    if (!WinHttpReceiveResponse(request, NULL)) goto done;
    if (!WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                            WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX)) goto done;
    printf("HTTP_STATUS=%lu\n", status);
    if (status == 200) { puts("TLS_OK"); result = 0; }
done:
    error = GetLastError();
    if (result) fprintf(stderr, "HTTPS check failed: Win32 error %lu, HTTP status %lu\n", error, status);
    if (request) WinHttpCloseHandle(request);
    if (connection) WinHttpCloseHandle(connection);
    if (session) WinHttpCloseHandle(session);
    return result;
}
