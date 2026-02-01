//+------------------------------------------------------------------+
//| BrowserAgent.mqh - Production Browser Agent for AI Analysis      |
//| Uses Chrome DevTools Protocol (CDP) for real browser automation  |
//| Author: Production Implementation                                 |
//| Version: 2.0                                                      |
//+------------------------------------------------------------------+

#ifndef BROWSERAGENT_MQH
#define BROWSERAGENT_MQH

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>
#include "../Core/SocketClient.mqh"
#include "../Core/AI_JSON_FILE.mqh"

//+------------------------------------------------------------------+
//| WinAPI Imports                                                   |
//+------------------------------------------------------------------+
#import "kernel32.dll"
    int CreateProcessW(string lpApplicationName, string lpCommandLine,
                       long lpProcessAttributes, long lpThreadAttributes,
                       int bInheritHandles, int dwCreationFlags,
                       long lpEnvironment, string lpCurrentDirectory,
                       uchar &lpStartupInfo[], uchar &lpProcessInformation[]);
    int CloseHandle(long hObject);
    int TerminateProcess(long hProcess, int uExitCode);
    int WaitForSingleObject(long hHandle, int dwMilliseconds);
    int GetLastError();
    void Sleep(int dwMilliseconds);
    int CreateDirectoryW(string lpPathName, long lpSecurityAttributes);
    int GetTempPathW(int nBufferLength, ushort &lpBuffer[]);
    int GetTickCount();
    long CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode,
                     long lpSecurityAttributes, uint dwCreationDisposition,
                     uint dwFlagsAndAttributes, long hTemplateFile);
    int WriteFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToWrite,
                  uint &lpNumberOfBytesWritten[], long lpOverlapped);
    int ReadFile(long hFile, uchar &lpBuffer[], uint nNumberOfBytesToRead,
                 uint &lpNumberOfBytesRead[], long lpOverlapped);
    int DeleteFileW(string lpFileName);
    long GetCurrentProcess();
    int GetExitCodeProcess(long hProcess, uint &lpExitCode);
#import

#import "user32.dll"
    long FindWindowW(string lpClassName, string lpWindowName);
    int SetForegroundWindow(long hWnd);
    int ShowWindow(long hWnd, int nCmdShow);
    int GetWindowThreadProcessId(long hWnd, uint &lpdwProcessId);
    int EnumWindows(long lpEnumFunc, long lParam);
    int GetWindowTextW(long hWnd, ushort &lpString[], int nMaxCount);
    int IsWindow(long hWnd);
#import

#import "winhttp.dll"
    long WinHttpOpen(string pszAgentW, int dwAccessType, string pszProxyW,
                     string pszProxyBypassW, int dwFlags);
    long WinHttpConnect(long hSession, string pswzServerName, int nServerPort, int dwReserved);
    long WinHttpOpenRequest(long hConnect, string pwszVerb, string pwszObjectName,
                            string pwszVersion, string pwszReferrer,
                            long ppwszAcceptTypes, int dwFlags);
    int WinHttpSendRequest(long hRequest, string lpszHeaders, int dwHeadersLength,
                           uchar &lpOptional[], int dwOptionalLength,
                           int dwTotalLength, long dwContext);
    int WinHttpReceiveResponse(long hRequest, long lpReserved);
    int WinHttpQueryDataAvailable(long hRequest, int &lpdwNumberOfBytesAvailable);
    int WinHttpReadData(long hRequest, uchar &lpBuffer[], int dwNumberOfBytesToRead,
                        int &lpdwNumberOfBytesRead);
    int WinHttpCloseHandle(long hInternet);
    int WinHttpSetOption(long hInternet, int dwOption, uchar &lpBuffer[], int dwBufferLength);
    int WinHttpAddRequestHeaders(long hRequest, string lpszHeaders, int dwHeadersLength, int dwModifiers);
    int WinHttpQueryHeaders(long hRequest, int dwInfoLevel, string pwszName,
                            uchar &lpBuffer[], int &lpdwBufferLength, int &lpdwIndex);
#import

#import "shell32.dll"
    long ShellExecuteW(long hwnd, string lpOperation, string lpFile,
                       string lpParameters, string lpDirectory, int nShowCmd);
#import

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define INVALID_HANDLE_VALUE        -1
#define CREATE_NO_WINDOW            0x08000000
#define CREATE_NEW_CONSOLE          0x00000010
#define NORMAL_PRIORITY_CLASS       0x00000020
#define STARTF_USESHOWWINDOW        0x00000001
#define SW_HIDE                     0
#define SW_SHOW                     5
#define SW_MINIMIZE                 6
#define INFINITE                    0xFFFFFFFF
#define WAIT_OBJECT_0               0
#define WAIT_TIMEOUT                258
#define STILL_ACTIVE                259

// WinHTTP Constants
#define WINHTTP_ACCESS_TYPE_DEFAULT_PROXY       0
#define WINHTTP_ACCESS_TYPE_NO_PROXY            1
#define WINHTTP_FLAG_SECURE                     0x00800000
#define WINHTTP_OPTION_SECURITY_FLAGS           31
#define WINHTTP_ADDREQ_FLAG_ADD                 0x20000000
#define WINHTTP_QUERY_STATUS_CODE               19
#define WINHTTP_QUERY_FLAG_NUMBER               0x20000000
#define SECURITY_FLAG_IGNORE_ALL_CERT_ERRORS    0x00003300

// File Constants
#define GENERIC_READ                0x80000000
#define GENERIC_WRITE               0x40000000
#define FILE_SHARE_READ             0x00000001
#define FILE_SHARE_WRITE            0x00000002
#define CREATE_ALWAYS               2
#define OPEN_EXISTING               3
#define FILE_ATTRIBUTE_NORMAL       0x00000080

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_BROWSER_TYPE {
    BROWSER_CHROME,
    BROWSER_EDGE,
    BROWSER_CHROMIUM
};

enum ENUM_AGENT_STATUS {
    AGENT_IDLE,
    AGENT_STARTING,
    AGENT_NAVIGATING,
    AGENT_LOGGING_IN,
    AGENT_ANALYZING,
    AGENT_EXTRACTING,
    AGENT_WAITING,
    AGENT_COMPLETE,
    AGENT_ERROR
};

enum ENUM_SENTIMENT_TYPE {
    SENTIMENT_BULLISH,
    SENTIMENT_BEARISH,
    SENTIMENT_NEUTRAL,
    SENTIMENT_MIXED
};

enum ENUM_AI_PROVIDER {
    AI_DEEPSEEK,
    AI_QWEN,
    AI_CLAUDE,
    AI_GEMINI,
    AI_CHATGPT,
    AI_CUSTOM
};

//+------------------------------------------------------------------+
//| Structures                                                       |
//+------------------------------------------------------------------+
struct SCDPTarget {
    string id;
    string type;
    string title;
    string url;
    string webSocketDebuggerUrl;
    string devtoolsFrontendUrl;
    bool   attached;
};

struct SHTTPResponse {
    int    status_code;
    string headers;
    string body;
    int    content_length;
    bool   success;
    string error;
};

struct SAIAnalysisResult {
    datetime            timestamp;
    datetime            valid_until;
    ENUM_SENTIMENT_TYPE directional_bias;
    double              confidence;
    double              entry_price;
    double              stop_loss;
    double              take_profit;
    double              risk_reward_ratio;
    string              reasoning;
    string              key_levels[];
    string              patterns[];
    bool                is_valid;

    void Init() {
        timestamp = TimeCurrent();
        valid_until = timestamp + 3600;
        directional_bias = SENTIMENT_NEUTRAL;
        confidence = 50.0;
        risk_reward_ratio = 2.0;
        is_valid = false;
    }
};

struct SPageContent {
    string url;
    string title;
    string html;
    string text;
    int    load_time_ms;
    bool   success;
};

struct SAnalysisRequest {
    string              request_id;
    string              symbol;
    ENUM_TIMEFRAMES     timeframe;
    ENUM_AI_PROVIDER    provider;
    string              prompt;
    datetime            created;
    datetime            timeout;
    int                 retries;
    int                 max_retries;
    bool                processed;
};

struct SAnalysisResponse {
    string              request_id;
    string              symbol;
    bool                success;
    string              raw_response;
    SAIAnalysisResult   result;
    int                 processing_time_ms;
    string              error;
};

//+------------------------------------------------------------------+
//| CJSONParser - Simple JSON Parser                                 |
//+------------------------------------------------------------------+
class CJSONParser {
private:
    string m_json;
    int    m_pos;

    void SkipWhitespace() {
        while(m_pos < StringLen(m_json)) {
            ushort c = StringGetCharacter(m_json, m_pos);
            if(c != ' ' && c != '\t' && c != '\n' && c != '\r')
                break;
            m_pos++;
        }
    }

    string ReadString() {
        if(StringGetCharacter(m_json, m_pos) != '"')
            return "";
        m_pos++;

        string result = "";
        bool escaped = false;

        while(m_pos < StringLen(m_json)) {
            ushort c = StringGetCharacter(m_json, m_pos);

            if(escaped) {
                switch(c) {
                    case 'n': result += "\n"; break;
                    case 'r': result += "\r"; break;
                    case 't': result += "\t"; break;
                    case '"': result += "\""; break;
                    case '\\': result += "\\"; break;
                    default: result += CharToString((uchar)c);
                }
                escaped = false;
            } else if(c == '\\') {
                escaped = true;
            } else if(c == '"') {
                m_pos++;
                break;
            } else {
                result += CharToString((uchar)c);
            }
            m_pos++;
        }
        return result;
    }

    string ReadValue() {
        SkipWhitespace();

        if(m_pos >= StringLen(m_json))
            return "";

        ushort c = StringGetCharacter(m_json, m_pos);

        if(c == '"') {
            return ReadString();
        } else if(c == '{' || c == '[') {
            int depth = 1;
            int start = m_pos;
            m_pos++;

            while(m_pos < StringLen(m_json) && depth > 0) {
                ushort ch = StringGetCharacter(m_json, m_pos);
                if(ch == '{' || ch == '[') depth++;
                else if(ch == '}' || ch == ']') depth--;
                else if(ch == '"') {
                    m_pos++;
                    while(m_pos < StringLen(m_json)) {
                        if(StringGetCharacter(m_json, m_pos) == '"' &&
                           StringGetCharacter(m_json, m_pos-1) != '\\')
                            break;
                        m_pos++;
                    }
                }
                m_pos++;
            }
            return StringSubstr(m_json, start, m_pos - start);
        } else {
            // Number, boolean, null
            string result = "";
            while(m_pos < StringLen(m_json)) {
                c = StringGetCharacter(m_json, m_pos);
                if(c == ',' || c == '}' || c == ']' || c == ' ' || c == '\n' || c == '\r')
                    break;
                result += CharToString((uchar)c);
                m_pos++;
            }
            return result;
        }
    }

public:
    CJSONParser() : m_pos(0) {}

    void Parse(string json) {
        m_json = json;
        m_pos = 0;
    }

    string GetString(string key) {
        m_pos = 0;
        string search = "\"" + key + "\"";
        int keyPos = StringFind(m_json, search);

        if(keyPos < 0)
            return "";

        m_pos = keyPos + StringLen(search);
        SkipWhitespace();

        if(m_pos < StringLen(m_json) && StringGetCharacter(m_json, m_pos) == ':') {
            m_pos++;
            SkipWhitespace();
            return ReadValue();
        }
        return "";
    }

    double GetDouble(string key) {
        string val = GetString(key);
        return StringToDouble(val);
    }

    int GetInteger(string key) {
        string val = GetString(key);
        return (int)StringToInteger(val);
    }

    bool GetBool(string key) {
        string val = GetString(key);
        return val == "true";
    }

    int GetArraySize(string key) {
        string arr = GetString(key);
        if(StringLen(arr) < 2 || StringGetCharacter(arr, 0) != '[')
            return 0;

        if(arr == "[]")
            return 0;

        int count = 1;
        int depth = 0;
        bool inString = false;

        for(int i = 1; i < StringLen(arr) - 1; i++) {
            ushort c = StringGetCharacter(arr, i);
            if(c == '"' && StringGetCharacter(arr, i-1) != '\\')
                inString = !inString;
            if(!inString) {
                if(c == '{' || c == '[') depth++;
                else if(c == '}' || c == ']') depth--;
                else if(c == ',' && depth == 0) count++;
            }
        }
        return count;
    }

    string GetArrayElement(string key, int index) {
        string arr = GetString(key);
        if(StringLen(arr) < 2 || StringGetCharacter(arr, 0) != '[')
            return "";

        int currentIndex = 0;
        int depth = 0;
        int start = 1;
        bool inString = false;

        for(int i = 1; i < StringLen(arr); i++) {
            ushort c = StringGetCharacter(arr, i);

            if(c == '"' && (i == 0 || StringGetCharacter(arr, i-1) != '\\'))
                inString = !inString;

            if(!inString) {
                if(c == '{' || c == '[') depth++;
                else if(c == '}' || c == ']') depth--;
                else if((c == ',' || c == ']') && depth == 0) {
                    if(currentIndex == index) {
                        string element = StringSubstr(arr, start, i - start);
                        StringTrimLeft(element);
                        StringTrimRight(element);
                        return element;
                    }
                    currentIndex++;
                    start = i + 1;
                }
            }
        }
        return "";
    }
};

//+------------------------------------------------------------------+
//| CHTTPClient - HTTP Client using WinHTTP                          |
//+------------------------------------------------------------------+
class CHTTPClient {
private:
    long   m_hSession;
    string m_userAgent;
    int    m_timeout;
    bool   m_initialized;

public:
    CHTTPClient() {
        m_hSession = 0;
        m_userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
        m_timeout = 30000;
        m_initialized = false;
    }

    ~CHTTPClient() {
        Close();
    }

    bool Initialize() {
        if(m_initialized)
            return true;

        m_hSession = WinHttpOpen(m_userAgent, WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, "", "", 0);

        if(m_hSession == 0) {
            Print("WinHTTP: Failed to open session, Error: ", kernel32::GetLastError());
            return false;
        }

        m_initialized = true;
        return true;
    }

    void Close() {
        if(m_hSession != 0) {
            WinHttpCloseHandle(m_hSession);
            m_hSession = 0;
        }
        m_initialized = false;
    }

    bool Get(string url, SHTTPResponse &response) {
        return Request("GET", url, "", "", response);
    }

    bool Post(string url, string data, string content_type, SHTTPResponse &response) {
        return Request("POST", url, data, content_type, response);
    }

    bool Request(string method, string url, string data, string content_type, SHTTPResponse &response) {
        ZeroMemory(response);
        response.success = false;

        if(!m_initialized && !Initialize()) {
            response.error = "HTTP client not initialized";
            return false;
        }

        // Parse URL
        string protocol, host, path;
        int port;

        if(!ParseURL(url, protocol, host, port, path)) {
            response.error = "Invalid URL: " + url;
            return false;
        }

        bool isSecure = (protocol == "https");
        if(port == 0)
            port = isSecure ? 443 : 80;

        // Connect
        long hConnect = WinHttpConnect(m_hSession, host, (int)port, 0);
        if(hConnect == 0) {
            response.error = "Connection failed to " + host;
            return false;
        }

        // Open request
        int flags = isSecure ? WINHTTP_FLAG_SECURE : 0;
        long hRequest = WinHttpOpenRequest(hConnect, method, path, "", "", 0, flags);

        if(hRequest == 0) {
            WinHttpCloseHandle(hConnect);
            response.error = "Failed to open request";
            return false;
        }

        // For HTTPS, ignore certificate errors (for development)
        if(isSecure) {
            uchar secFlags[4];
            secFlags[0] = (uchar)(SECURITY_FLAG_IGNORE_ALL_CERT_ERRORS & 0xFF);
            secFlags[1] = (uchar)((SECURITY_FLAG_IGNORE_ALL_CERT_ERRORS >> 8) & 0xFF);
            secFlags[2] = (uchar)((SECURITY_FLAG_IGNORE_ALL_CERT_ERRORS >> 16) & 0xFF);
            secFlags[3] = (uchar)((SECURITY_FLAG_IGNORE_ALL_CERT_ERRORS >> 24) & 0xFF);
            WinHttpSetOption(hRequest, WINHTTP_OPTION_SECURITY_FLAGS, secFlags, 4);
        }

        // Add headers
        string headers = "Accept: */*\r\n";
        if(StringLen(content_type) > 0) {
            headers += "Content-Type: " + content_type + "\r\n";
        }
        WinHttpAddRequestHeaders(hRequest, headers, -1, WINHTTP_ADDREQ_FLAG_ADD);

        // Send request
        uchar dataBytes[];
        int dataLen = 0;
        if(StringLen(data) > 0) {
            dataLen = StringToCharArray(data, dataBytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
            if(dataLen < 0) dataLen = 0;
        }

        if(dataLen > 0) {
            if(!WinHttpSendRequest(hRequest, "", 0, dataBytes, dataLen, dataLen, 0)) {
                WinHttpCloseHandle(hRequest);
                WinHttpCloseHandle(hConnect);
                response.error = "Send request failed";
                return false;
            }
        } else {
            uchar empty[];
            ArrayResize(empty, 1);
            empty[0] = 0;
            if(!WinHttpSendRequest(hRequest, "", 0, empty, 0, 0, 0)) {
                WinHttpCloseHandle(hRequest);
                WinHttpCloseHandle(hConnect);
                response.error = "Send request failed";
                return false;
            }
        }

        // Receive response
        if(!WinHttpReceiveResponse(hRequest, 0)) {
            WinHttpCloseHandle(hRequest);
            WinHttpCloseHandle(hConnect);
            response.error = "Receive response failed";
            return false;
        }

        // Get status code
        uchar statusBuf[4];
        int statusLen = 4;
        int index = 0;
        WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                           "", statusBuf, statusLen, index);
        response.status_code = statusBuf[0] | (statusBuf[1] << 8) |
                              (statusBuf[2] << 16) | (statusBuf[3] << 24);

        // Read response body
        string bodyResult = "";
        int bytesAvailable = 0;

        while(WinHttpQueryDataAvailable(hRequest, bytesAvailable)) {
            if(bytesAvailable == 0)
                break;

            uchar buffer[];
            ArrayResize(buffer, bytesAvailable + 1);
            int bytesRead = 0;

            if(WinHttpReadData(hRequest, buffer, bytesAvailable, bytesRead)) {
                if(bytesRead > 0) {
                    buffer[bytesRead] = 0;
                    bodyResult += CharArrayToString(buffer, 0, bytesRead, CP_UTF8);
                }
            }

            if(bytesRead == 0)
                break;
        }

        response.body = bodyResult;
        response.content_length = StringLen(bodyResult);
        response.success = (response.status_code >= 200 && response.status_code < 300);

        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);

        return response.success;
    }

private:
    bool ParseURL(string url, string &protocol, string &host, int &port, string &path) {
        int protoEnd = StringFind(url, "://");
        if(protoEnd < 0) {
            protocol = "http";
            protoEnd = 0;
        } else {
            protocol = StringSubstr(url, 0, protoEnd);
            protoEnd += 3;
        }

        string remainder = StringSubstr(url, protoEnd);
        int pathStart = StringFind(remainder, "/");

        string hostPort;
        if(pathStart < 0) {
            hostPort = remainder;
            path = "/";
        } else {
            hostPort = StringSubstr(remainder, 0, pathStart);
            path = StringSubstr(remainder, pathStart);
        }

        int portPos = StringFind(hostPort, ":");
        if(portPos < 0) {
            host = hostPort;
            port = 0;
        } else {
            host = StringSubstr(hostPort, 0, portPos);
            port = (int)StringToInteger(StringSubstr(hostPort, portPos + 1));
        }

        return StringLen(host) > 0;
    }
};

//+------------------------------------------------------------------+
//| CCDPClient - Chrome DevTools Protocol Client                     |
//+------------------------------------------------------------------+
class CCDPClient {
private:
    CHTTPClient     m_http;
    string          m_debuggerUrl;
    int             m_port;
    SCDPTarget      m_targets[];
    SCDPTarget      m_activeTarget;
    int             m_commandId;
    bool            m_connected;
    CJSONParser     m_parser;

public:
    CCDPClient() : m_port(9222), m_commandId(0), m_connected(false) {}

    ~CCDPClient() {
        Disconnect();
    }

    bool Connect(int port = 9222) {
        m_port = port;
        m_debuggerUrl = "http://127.0.0.1:" + IntegerToString(port);

        if(!m_http.Initialize()) {
            Print("CDP: Failed to initialize HTTP client");
            return false;
        }

        // Get available targets
        if(!RefreshTargets()) {
            Print("CDP: Failed to get browser targets");
            return false;
        }

        // Find a page target
        for(int i = 0; i < ArraySize(m_targets); i++) {
            if(m_targets[i].type == "page") {
                m_activeTarget = m_targets[i];
                m_connected = true;
                Print("CDP: Connected to target: ", m_activeTarget.title);
                return true;
            }
        }

        // Create new tab if no page target found
        if(CreateNewTab("about:blank")) {
            RefreshTargets();
            for(int i = 0; i < ArraySize(m_targets); i++) {
                if(m_targets[i].type == "page") {
                    m_activeTarget = m_targets[i];
                    m_connected = true;
                    return true;
                }
            }
        }

        Print("CDP: No page targets available");
        return false;
    }

    void Disconnect() {
        m_http.Close();
        m_connected = false;
        ArrayFree(m_targets);
    }

    bool IsConnected() { return m_connected; }

    bool RefreshTargets() {
        SHTTPResponse response;

        if(!m_http.Get(m_debuggerUrl + "/json/list", response)) {
            return false;
        }

        if(!response.success) {
            Print("CDP: Failed to get targets, status: ", response.status_code);
            return false;
        }

        // Parse targets JSON array
        ArrayFree(m_targets);

        // Simple array parsing
        string json = response.body;
        if(StringLen(json) < 3)
            return true;

        // Remove outer brackets
        if(StringGetCharacter(json, 0) == '[')
            json = StringSubstr(json, 1, StringLen(json) - 2);

        // Split by objects
        int depth = 0;
        int start = 0;

        for(int i = 0; i < StringLen(json); i++) {
            ushort c = StringGetCharacter(json, i);
            if(c == '{') {
                if(depth == 0) start = i;
                depth++;
            } else if(c == '}') {
                depth--;
                if(depth == 0) {
                    string objJson = StringSubstr(json, start, i - start + 1);
                    ParseTarget(objJson);
                }
            }
        }

        return true;
    }

    bool CreateNewTab(string url) {
        SHTTPResponse response;
        string endpoint = m_debuggerUrl + "/json/new?" + url;

        if(!m_http.Get(endpoint, response)) {
            return false;
        }

        return response.success;
    }

    bool Navigate(string url) {
        if(!m_connected) {
            Print("CDP: Not connected");
            return false;
        }

        string cmd = BuildCommand("Page.navigate", "\"url\":\"" + EscapeJSON(url) + "\"");
        return ExecuteCommand(cmd);
    }

    bool WaitForLoad(int timeout_ms = 30000) {
        if(!m_connected)
            return false;

        int startTime = GetTickCount();

        while(GetTickCount() - startTime < timeout_ms) {
            string result;
            if(EvaluateScript("document.readyState", result)) {
                if(StringFind(result, "complete") >= 0 || StringFind(result, "interactive") >= 0) {
                    Sleep(500); // Extra wait for dynamic content
                    return true;
                }
            }
            Sleep(500);
        }

        return false;
    }

    bool Click(string selector) {
        string script = StringFormat(
            "var elem = document.querySelector('%s'); " +
            "if(elem) { elem.click(); 'clicked'; } else { 'not found'; }",
            EscapeJS(selector)
        );

        string result;
        if(EvaluateScript(script, result)) {
            return StringFind(result, "clicked") >= 0;
        }
        return false;
    }

    bool Type(string selector, string text) {
        string script = StringFormat(
            "var elem = document.querySelector('%s'); " +
            "if(elem) { " +
            "  elem.focus(); " +
            "  elem.value = '%s'; " +
            "  elem.dispatchEvent(new Event('input', { bubbles: true })); " +
            "  elem.dispatchEvent(new Event('change', { bubbles: true })); " +
            "  'typed'; " +
            "} else { 'not found'; }",
            EscapeJS(selector), EscapeJS(text)
        );

        string result;
        if(EvaluateScript(script, result)) {
            return StringFind(result, "typed") >= 0;
        }
        return false;
    }

    bool GetText(string selector, string &text) {
        string script = StringFormat(
            "var elem = document.querySelector('%s'); " +
            "elem ? (elem.innerText || elem.textContent || elem.value || '') : '';",
            EscapeJS(selector)
        );

        return EvaluateScript(script, text);
    }

    bool GetPageContent(SPageContent &content) {
        content.success = false;

        // Get URL
        EvaluateScript("window.location.href", content.url);

        // Get title
        EvaluateScript("document.title", content.title);

        // Get HTML
        string script = "document.documentElement.outerHTML";
        if(!EvaluateScript(script, content.html)) {
            Print("CDP: Failed to get page HTML");
            return false;
        }

        // Get text content
        script = "document.body ? document.body.innerText : ''";
        EvaluateScript(script, content.text);

        content.success = true;
        return true;
    }

    bool ElementExists(string selector) {
        string script = StringFormat(
            "document.querySelector('%s') !== null",
            EscapeJS(selector)
        );

        string result;
        if(EvaluateScript(script, result)) {
            return result == "true";
        }
        return false;
    }

    bool WaitForElement(string selector, int timeout_ms = 10000) {
        int startTime = GetTickCount();

        while(GetTickCount() - startTime < timeout_ms) {
            if(ElementExists(selector))
                return true;
            Sleep(200);
        }

        return false;
    }

    bool EvaluateScript(string expression, string &result) {
        if(!m_connected)
            return false;

        string escapedExpr = EscapeJSON(expression);
        string cmd = BuildCommand("Runtime.evaluate",
            "\"expression\":\"" + escapedExpr + "\"," +
            "\"returnByValue\":true"
        );

        string response;
        if(!SendCommand(cmd, response))
            return false;

        // Parse result
        m_parser.Parse(response);
        string resultJson = m_parser.GetString("result");

        if(StringLen(resultJson) > 0) {
            m_parser.Parse(resultJson);
            result = m_parser.GetString("value");

            // Clean up quotes
            if(StringLen(result) >= 2) {
                if(StringGetCharacter(result, 0) == '"')
                    result = StringSubstr(result, 1, StringLen(result) - 2);
            }
            return true;
        }

        return false;
    }

    bool TakeScreenshot(string &base64Data) {
        string cmd = BuildCommand("Page.captureScreenshot", "\"format\":\"png\"");
        string response;

        if(!SendCommand(cmd, response))
            return false;

        m_parser.Parse(response);
        base64Data = m_parser.GetString("data");

        return StringLen(base64Data) > 0;
    }

private:
    void ParseTarget(string json) {
        m_parser.Parse(json);

        int idx = ArraySize(m_targets);
        ArrayResize(m_targets, idx + 1);

        m_targets[idx].id = m_parser.GetString("id");
        m_targets[idx].type = m_parser.GetString("type");
        m_targets[idx].title = m_parser.GetString("title");
        m_targets[idx].url = m_parser.GetString("url");
        m_targets[idx].webSocketDebuggerUrl = m_parser.GetString("webSocketDebuggerUrl");
        m_targets[idx].devtoolsFrontendUrl = m_parser.GetString("devtoolsFrontendUrl");
        m_targets[idx].attached = false;
    }

    string BuildCommand(string method, string params) {
        m_commandId++;
        return StringFormat(
            "{\"id\":%d,\"method\":\"%s\",\"params\":{%s}}",
            m_commandId, method, params
        );
    }

    bool ExecuteCommand(string command) {
        string response;
        return SendCommand(command, response);
    }

    bool SendCommand(string command, string &response) {
        if(!m_connected || StringLen(m_activeTarget.id) == 0)
            return false;

        // Use HTTP-based CDP endpoint
        string endpoint = m_debuggerUrl + "/json/protocol";

        // For most operations, we use the Runtime.evaluate endpoint
        // This is a simplified implementation using HTTP
        SHTTPResponse httpResp;

        // Send via POST to the target
        string url = StringFormat("http://127.0.0.1:%d/json/", m_port);

        // Actually execute via evaluate script if it's a script command
        // For navigation, use special endpoint

        if(StringFind(command, "Page.navigate") >= 0) {
            // Extract URL from command
            int urlStart = StringFind(command, "\"url\":\"");
            if(urlStart >= 0) {
                urlStart += 7;
                int urlEnd = StringFind(command, "\"", urlStart);
                string navUrl = StringSubstr(command, urlStart, urlEnd - urlStart);

                // Use activate endpoint first
                m_http.Get(m_debuggerUrl + "/json/activate/" + m_activeTarget.id, httpResp);

                // Navigate via special URL
                // Actually we need WebSocket for proper CDP - using workaround
                string script = "window.location.href = '" + navUrl + "';";
                EvaluateScriptDirect(script, response);
                Sleep(1000);
                return true;
            }
        }

        // For other commands, try direct evaluation approach
        if(StringFind(command, "Runtime.evaluate") >= 0) {
            int exprStart = StringFind(command, "\"expression\":\"");
            if(exprStart >= 0) {
                exprStart += 14;
                int exprEnd = StringFind(command, "\",\"returnByValue", exprStart);
                if(exprEnd < 0) exprEnd = StringFind(command, "\"}", exprStart);

                string expr = StringSubstr(command, exprStart, exprEnd - exprStart);
                expr = UnescapeJSON(expr);

                return EvaluateScriptDirect(expr, response);
            }
        }

        return false;
    }

    bool EvaluateScriptDirect(string script, string &result) {
        // Institutional implementation: Use Socket Bridge to Python
        // Python handles real browser interaction (Playwright/Puppeteer)
        CSocketClient socket("127.0.0.1", 5555);

        JsonValue root(JsonObject, "");
        root["action"]->operator=("evaluate_script");
        root["script"]->operator=(script);

        string request = root.SerializeToString();
        string response = "";

        if(socket.SendAndReceive(request, response)) {
            char jsonChars[];
            int len = StringToCharArray(response, jsonChars);
            int index = 0;
            JsonValue res;
            if(res.DeserializeFromArray(jsonChars, len, index)) {
                if(res["status"].ToString() == "success") {
                    result = res["result"].ToString();
                    return true;
                }
            }
        }

        result = "";
        return false;
    }

    string EscapeJSON(string text) {
        string result = text;
        StringReplace(result, "\\", "\\\\");
        StringReplace(result, "\"", "\\\"");
        StringReplace(result, "\n", "\\n");
        StringReplace(result, "\r", "\\r");
        StringReplace(result, "\t", "\\t");
        return result;
    }

    string UnescapeJSON(string text) {
        string result = text;
        StringReplace(result, "\\\"", "\"");
        StringReplace(result, "\\n", "\n");
        StringReplace(result, "\\r", "\r");
        StringReplace(result, "\\t", "\t");
        StringReplace(result, "\\\\", "\\");
        return result;
    }

    string EscapeJS(string text) {
        string result = text;
        StringReplace(result, "\\", "\\\\");
        StringReplace(result, "'", "\\'");
        StringReplace(result, "\"", "\\\"");
        StringReplace(result, "\n", "\\n");
        StringReplace(result, "\r", "\\r");
        return result;
    }
};

//+------------------------------------------------------------------+
//| CBrowserProcess - Browser Process Manager                        |
//+------------------------------------------------------------------+
class CBrowserProcess {
private:
    long                m_processHandle;
    long                m_threadHandle;
    uint                m_processId;
    ENUM_BROWSER_TYPE   m_browserType;
    string              m_browserPath;
    string              m_userDataDir;
    int                 m_debugPort;
    bool                m_headless;
    bool                m_running;

public:
    CBrowserProcess() {
        m_processHandle = 0;
        m_threadHandle = 0;
        m_processId = 0;
        m_browserType = BROWSER_CHROME;
        m_debugPort = 9222;
        m_headless = false;
        m_running = false;
    }

    ~CBrowserProcess() {
        Terminate();
    }

    void SetBrowserType(ENUM_BROWSER_TYPE type) { m_browserType = type; }
    void SetBrowserPath(string path) { m_browserPath = path; }
    void SetDebugPort(int port) { m_debugPort = port; }
    void SetHeadless(bool headless) { m_headless = headless; }
    void SetUserDataDir(string dir) { m_userDataDir = dir; }

    bool IsRunning() { return m_running; }
    int GetDebugPort() { return m_debugPort; }

    bool Start() {
        if(m_running) {
            Print("Browser already running");
            return true;
        }

        // Get browser path
        string browserExe = GetBrowserPath();
        if(StringLen(browserExe) == 0) {
            Print("Browser executable not found");
            return false;
        }

        // Prepare user data directory
        if(StringLen(m_userDataDir) == 0) {
            m_userDataDir = GetTempPath() + "\\MQL5Browser_" + IntegerToString(m_debugPort);
        }
        CreateDirectoryW(m_userDataDir, 0);

        // Build command line
        string cmdLine = "\"" + browserExe + "\" ";
        cmdLine += "--remote-debugging-port=" + IntegerToString(m_debugPort) + " ";
        cmdLine += "--user-data-dir=\"" + m_userDataDir + "\" ";
        cmdLine += "--no-first-run ";
        cmdLine += "--no-default-browser-check ";
        cmdLine += "--disable-default-apps ";
        cmdLine += "--disable-popup-blocking ";
        cmdLine += "--disable-translate ";
        cmdLine += "--disable-background-timer-throttling ";
        cmdLine += "--disable-backgrounding-occluded-windows ";
        cmdLine += "--disable-renderer-backgrounding ";
        cmdLine += "--disable-device-discovery-notifications ";

        if(m_headless) {
            cmdLine += "--headless=new ";
            cmdLine += "--disable-gpu ";
        } else {
            cmdLine += "--start-maximized ";
        }

        cmdLine += "about:blank";

        Print("Starting browser: ", browserExe);
        Print("Command line: ", cmdLine);

        // Create process
        uchar startupInfo[68];
        ArrayInitialize(startupInfo, 0);
        // Set cb (size) - first 4 bytes
        startupInfo[0] = 68; // sizeof(STARTUPINFO)

        uchar processInfo[24];
        ArrayInitialize(processInfo, 0);

        int flags = NORMAL_PRIORITY_CLASS;
        if(m_headless) {
            flags |= CREATE_NO_WINDOW;
        }

        int result = CreateProcessW(
            "",           // Application name (use command line)
            cmdLine,      // Command line
            0,            // Process security attributes
            0,            // Thread security attributes
            0,            // Inherit handles
            flags,        // Creation flags
            0,            // Environment
            "",           // Current directory
            startupInfo,  // Startup info
            processInfo   // Process info
        );

        if(result == 0) {
            int err = kernel32::GetLastError();
            Print("Failed to start browser process. Error: ", err);
            return false;
        }

        // Extract handles from processInfo
        m_processHandle = processInfo[0] | (processInfo[1] << 8) |
                         (processInfo[2] << 16) | ((long)processInfo[3] << 24);
        m_threadHandle = processInfo[4] | (processInfo[5] << 8) |
                        (processInfo[6] << 16) | ((long)processInfo[7] << 24);
        m_processId = processInfo[8] | (processInfo[9] << 8) |
                     (processInfo[10] << 16) | (processInfo[11] << 24);

        Print("Browser process started. PID: ", m_processId);

        // Wait for browser to initialize
        Sleep(3000);

        m_running = true;
        return true;
    }

    void Terminate() {
        if(!m_running)
            return;

        Print("Terminating browser process...");

        if(m_processHandle != 0) {
            TerminateProcess(m_processHandle, 0);
            WaitForSingleObject(m_processHandle, 5000);
            CloseHandle(m_processHandle);
            m_processHandle = 0;
        }

        if(m_threadHandle != 0) {
            CloseHandle(m_threadHandle);
            m_threadHandle = 0;
        }

        m_processId = 0;
        m_running = false;

        Print("Browser terminated");
    }

    bool IsProcessAlive() {
        if(m_processHandle == 0)
            return false;

        uint exitCode = 0;
        if(GetExitCodeProcess(m_processHandle, exitCode)) {
            return exitCode == STILL_ACTIVE;
        }
        return false;
    }

private:
    string GetBrowserPath() {
        if(StringLen(m_browserPath) > 0) {
            return m_browserPath;
        }

        string paths[];

        switch(m_browserType) {
            case BROWSER_CHROME:
                ArrayResize(paths, 4);
                paths[0] = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
                paths[1] = "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe";
                paths[2] = GetEnvVar("LOCALAPPDATA") + "\\Google\\Chrome\\Application\\chrome.exe";
                paths[3] = GetEnvVar("PROGRAMFILES") + "\\Google\\Chrome\\Application\\chrome.exe";
                break;

            case BROWSER_EDGE:
                ArrayResize(paths, 2);
                paths[0] = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
                paths[1] = "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe";
                break;

            case BROWSER_CHROMIUM:
                ArrayResize(paths, 2);
                paths[0] = GetEnvVar("LOCALAPPDATA") + "\\Chromium\\Application\\chrome.exe";
                paths[1] = "C:\\Program Files\\Chromium\\Application\\chrome.exe";
                break;
        }

        for(int i = 0; i < ArraySize(paths); i++) {
            // Check if file exists using shell
            long result = ShellExecuteW(0, "open", paths[i], "", "", 0);
            if(result > 32) {
                return paths[i];
            }

            // Alternative check - try to open and close
            long hFile = CreateFileW(paths[i], GENERIC_READ, FILE_SHARE_READ,
                                    0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
            if(hFile != INVALID_HANDLE_VALUE) {
                CloseHandle(hFile);
                return paths[i];
            }
        }

        return "";
    }

    string GetTempPath() {
        ushort buffer[260];
        int len = kernel32::GetTempPathW(260, buffer);

        if(len > 0) {
            string result = "";
            for(int i = 0; i < len && buffer[i] != 0; i++) {
                result += CharToString((uchar)buffer[i]);
            }
            // Remove trailing backslash
            if(StringLen(result) > 0 && StringGetCharacter(result, StringLen(result)-1) == '\\')
                result = StringSubstr(result, 0, StringLen(result)-1);
            return result;
        }

        return "C:\\Temp";
    }

    string GetEnvVar(string name) {
        // Return common paths as fallback
        if(name == "LOCALAPPDATA")
            return "C:\\Users\\Default\\AppData\\Local";
        if(name == "PROGRAMFILES")
            return "C:\\Program Files";
        return "";
    }
};

//+------------------------------------------------------------------+
//| CBrowserAgent - Main Browser Agent Class                         |
//+------------------------------------------------------------------+
class CBrowserAgent {
private:
    CBrowserProcess     m_browser;
    CCDPClient          m_cdp;
    CHTTPClient         m_http;
    CJSONParser         m_parser;

    ENUM_AGENT_STATUS   m_status;
    bool                m_initialized;

    // Configuration
    ENUM_BROWSER_TYPE   m_browserType;
    bool                m_headless;
    int                 m_debugPort;
    int                 m_pageTimeout;
    int                 m_elementTimeout;

    // AI Service URLs
    string              m_aiUrls[];

    // Request Management
    SAnalysisRequest    m_requests[];
    SAnalysisResponse   m_responses[];
    int                 m_maxRequests;

    // Performance Metrics
    int                 m_totalRequests;
    int                 m_successfulRequests;
    int                 m_failedRequests;
    double              m_avgResponseTime;

    // Logging
    bool                m_loggingEnabled;
    string              m_logFile;
    int                 m_logHandle;

public:
    CBrowserAgent() {
        m_status = AGENT_IDLE;
        m_initialized = false;
        m_browserType = BROWSER_CHROME;
        m_headless = false;
        m_debugPort = 9222;
        m_pageTimeout = 30000;
        m_elementTimeout = 10000;
        m_maxRequests = 100;

        m_totalRequests = 0;
        m_successfulRequests = 0;
        m_failedRequests = 0;
        m_avgResponseTime = 0;

        m_loggingEnabled = false;
        m_logHandle = INVALID_HANDLE;

        // Initialize AI URLs
        ArrayResize(m_aiUrls, 6);
        m_aiUrls[AI_DEEPSEEK] = "https://chat.deepseek.com";
        m_aiUrls[AI_QWEN] = "https://chat.qwen.ai";
        m_aiUrls[AI_CLAUDE] = "https://claude.ai";
        m_aiUrls[AI_GEMINI] = "https://gemini.google.com";
        m_aiUrls[AI_CHATGPT] = "https://chatgpt.com";
        m_aiUrls[AI_CUSTOM] = "";
    }

    ~CBrowserAgent() {
        Shutdown();
    }

    //--- Initialization ---
    bool Initialize() {
        Print("=== Browser Agent Initialization ===");

        if(m_initialized) {
            Print("Already initialized");
            return true;
        }

        // Initialize HTTP client
        if(!m_http.Initialize()) {
            Print("Failed to initialize HTTP client");
            return false;
        }

        m_initialized = true;
        m_status = AGENT_IDLE;

        Print("Browser Agent initialized successfully");
        Print("Browser Type: ", EnumToString(m_browserType));
        Print("Debug Port: ", m_debugPort);
        Print("Headless: ", m_headless ? "Yes" : "No");

        return true;
    }

    void Shutdown() {
        Print("Shutting down Browser Agent...");

        m_cdp.Disconnect();
        m_browser.Terminate();
        m_http.Close();

        if(m_logHandle != INVALID_HANDLE) {
            FileClose(m_logHandle);
            m_logHandle = INVALID_HANDLE;
        }

        m_initialized = false;
        m_status = AGENT_IDLE;

        Print("Browser Agent shut down");
    }

    //--- Browser Control ---
    bool StartBrowser(bool headless = false) {
        if(!m_initialized) {
            if(!Initialize())
                return false;
        }

        m_headless = headless;
        m_status = AGENT_STARTING;

        Print("Starting browser (", headless ? "headless" : "visible", ")...");

        // Configure and start browser
        m_browser.SetBrowserType(m_browserType);
        m_browser.SetDebugPort(m_debugPort);
        m_browser.SetHeadless(headless);

        if(!m_browser.Start()) {
            m_status = AGENT_ERROR;
            return false;
        }

        // Wait for browser to be ready
        Sleep(2000);

        // Connect CDP
        int retries = 5;
        while(retries > 0) {
            if(m_cdp.Connect(m_debugPort)) {
                Print("CDP connected successfully");
                m_status = AGENT_IDLE;
                Log("Browser started and CDP connected");
                return true;
            }
            Print("CDP connection attempt failed, retrying...");
            Sleep(1000);
            retries--;
        }

        Print("Failed to connect CDP after retries");
        m_browser.Terminate();
        m_status = AGENT_ERROR;
        return false;
    }

    void StopBrowser() {
        m_cdp.Disconnect();
        m_browser.Terminate();
        m_status = AGENT_IDLE;
        Log("Browser stopped");
    }

    bool IsBrowserActive() {
        return m_browser.IsRunning() && m_cdp.IsConnected();
    }

    //--- Navigation ---
    bool Navigate(string url, bool waitForLoad = true) {
        if(!IsBrowserActive()) {
            Print("Browser not active");
            return false;
        }

        m_status = AGENT_NAVIGATING;
        Print("Navigating to: ", url);
        Log("Navigate: " + url);

        if(!m_cdp.Navigate(url)) {
            m_status = AGENT_ERROR;
            return false;
        }

        if(waitForLoad) {
            if(!m_cdp.WaitForLoad(m_pageTimeout)) {
                Print("Page load timeout");
                m_status = AGENT_IDLE;
                return false;
            }
        }

        m_status = AGENT_IDLE;
        return true;
    }

    bool NavigateWithRetry(string url, int maxRetries = 3) {
        for(int i = 0; i < maxRetries; i++) {
            if(Navigate(url, true))
                return true;
            Print("Navigation retry ", i + 1, "/", maxRetries);
            Sleep(2000);
        }
        return false;
    }

    //--- Element Interaction ---
    bool Click(string selector) {
        if(!IsBrowserActive())
            return false;

        if(!m_cdp.WaitForElement(selector, m_elementTimeout)) {
            Print("Element not found: ", selector);
            return false;
        }

        return m_cdp.Click(selector);
    }

    bool Type(string selector, string text) {
        if(!IsBrowserActive())
            return false;

        if(!m_cdp.WaitForElement(selector, m_elementTimeout)) {
            Print("Element not found: ", selector);
            return false;
        }

        return m_cdp.Type(selector, text);
    }

    bool GetText(string selector, string &text) {
        if(!IsBrowserActive())
            return false;

        return m_cdp.GetText(selector, text);
    }

    bool WaitForElement(string selector, int timeout_ms = 0) {
        if(timeout_ms == 0)
            timeout_ms = m_elementTimeout;
        return m_cdp.WaitForElement(selector, timeout_ms);
    }

    bool ElementExists(string selector) {
        return m_cdp.ElementExists(selector);
    }

    //--- Page Content ---
    bool GetPageContent(SPageContent &content) {
        if(!IsBrowserActive())
            return false;

        m_status = AGENT_EXTRACTING;
        bool result = m_cdp.GetPageContent(content);
        m_status = AGENT_IDLE;

        return result;
    }

    bool EvaluateScript(string script, string &result) {
        if(!IsBrowserActive())
            return false;

        return m_cdp.EvaluateScript(script, result);
    }

    //--- Authentication ---
    bool Login(string loginUrl, string usernameSelector, string passwordSelector,
               string submitSelector, string username, string password) {

        if(!Navigate(loginUrl))
            return false;

        m_status = AGENT_LOGGING_IN;
        Print("Performing login...");
        Log("Login attempt: " + loginUrl);

        // Wait for form
        if(!WaitForElement(usernameSelector, 15000)) {
            Print("Username field not found");
            m_status = AGENT_IDLE;
            return false;
        }

        // Fill username
        if(!Type(usernameSelector, username)) {
            Print("Failed to enter username");
            m_status = AGENT_IDLE;
            return false;
        }
        Sleep(500);

        // Fill password
        if(!Type(passwordSelector, password)) {
            Print("Failed to enter password");
            m_status = AGENT_IDLE;
            return false;
        }
        Sleep(500);

        // Click submit
        if(!Click(submitSelector)) {
            Print("Failed to click submit");
            m_status = AGENT_IDLE;
            return false;
        }

        // Wait for navigation
        Sleep(3000);
        m_cdp.WaitForLoad(m_pageTimeout);

        m_status = AGENT_IDLE;
        Log("Login completed");

        return true;
    }

    //--- AI Analysis ---
    bool RequestAnalysis(ENUM_AI_PROVIDER provider, string symbol,
                        ENUM_TIMEFRAMES timeframe, SAnalysisResponse &response) {

        ZeroMemory(response);
        response.request_id = GenerateRequestId();
        response.symbol = symbol;

        int startTime = GetTickCount();
        m_totalRequests++;

        m_status = AGENT_ANALYZING;
        Print("Requesting analysis from ", EnumToString(provider), " for ", symbol);
        Log("Analysis request: " + EnumToString(provider) + " - " + symbol);

        // Get AI service URL
        string url = m_aiUrls[provider];
        if(StringLen(url) == 0) {
            response.error = "Invalid AI provider";
            response.success = false;
            m_failedRequests++;
            return false;
        }

        // Navigate to AI service
        if(!Navigate(url)) {
            response.error = "Failed to navigate to AI service";
            response.success = false;
            m_failedRequests++;
            return false;
        }

        // Build analysis prompt
        string prompt = BuildAnalysisPrompt(symbol, timeframe);

        // Submit prompt to AI
        bool submitted = false;

        switch(provider) {
            case AI_DEEPSEEK:
                submitted = SubmitToDeepSeek(prompt);
                break;
            case AI_QWEN:
                submitted = SubmitToQwen(prompt);
                break;
            case AI_CLAUDE:
                submitted = SubmitToClaude(prompt);
                break;
            case AI_GEMINI:
                submitted = SubmitToGemini(prompt);
                break;
            case AI_CHATGPT:
                submitted = SubmitToChatGPT(prompt);
                break;
            default:
                response.error = "Unsupported AI provider";
                break;
        }

        if(!submitted) {
            if(StringLen(response.error) == 0)
                response.error = "Failed to submit prompt";
            response.success = false;
            m_failedRequests++;
            m_status = AGENT_IDLE;
            return false;
        }

        // Wait for response
        Sleep(5000);

        // Extract response
        string rawResponse;
        if(!ExtractAIResponse(provider, rawResponse)) {
            response.error = "Failed to extract response";
            response.success = false;
            m_failedRequests++;
            m_status = AGENT_IDLE;
            return false;
        }

        response.raw_response = rawResponse;
        response.processing_time_ms = GetTickCount() - startTime;

        // Parse response
        if(!ParseAnalysisResponse(rawResponse, response.result)) {
            response.error = "Failed to parse response";
            response.success = false;
            m_failedRequests++;
        } else {
            response.success = true;
            m_successfulRequests++;
        }

        // Update metrics
        UpdateMetrics(response.success, response.processing_time_ms);

        m_status = AGENT_IDLE;
        Log("Analysis complete: " + (response.success ? "Success" : "Failed"));

        return response.success;
    }

    //--- TradingView Integration ---
    bool OpenTradingViewChart(string symbol, ENUM_TIMEFRAMES timeframe) {
        string tfStr = TimeframeToTradingViewInterval(timeframe);
        string normalizedSymbol = NormalizeTradingViewSymbol(symbol);

        string url = "https://www.tradingview.com/chart/?symbol=" +
                     normalizedSymbol + "&interval=" + tfStr;

        Print("Opening TradingView: ", url);
        return Navigate(url);
    }

    bool ExtractTradingViewData(string &technicalRating, string &oscillatorsRating,
                                string &movingAveragesRating) {
        if(!IsBrowserActive())
            return false;

        m_status = AGENT_EXTRACTING;

        // Wait for ratings to load
        Sleep(3000);

        // Extract technical analysis ratings
        string script = @"
            (function() {
                var result = {};
                var ratingElements = document.querySelectorAll('[class*=\"rating\"]');
                for(var i = 0; i < ratingElements.length; i++) {
                    var text = ratingElements[i].textContent;
                    if(text.includes('Strong Buy') || text.includes('Buy') ||
                       text.includes('Neutral') || text.includes('Sell') ||
                       text.includes('Strong Sell')) {
                        return text;
                    }
                }
                return '';
            })();
        ";

        string result;
        if(EvaluateScript(script, result)) {
            technicalRating = result;
        }

        m_status = AGENT_IDLE;
        return true;
    }

    //--- Configuration ---
    void SetBrowserType(ENUM_BROWSER_TYPE type) { m_browserType = type; }
    void SetDebugPort(int port) { m_debugPort = port; }
    void SetPageTimeout(int ms) { m_pageTimeout = ms; }
    void SetElementTimeout(int ms) { m_elementTimeout = ms; }
    void SetAIUrl(ENUM_AI_PROVIDER provider, string url) {
        if(provider >= 0 && provider < ArraySize(m_aiUrls))
            m_aiUrls[provider] = url;
    }

    //--- Metrics ---
    ENUM_AGENT_STATUS GetStatus() { return m_status; }
    int GetTotalRequests() { return m_totalRequests; }
    int GetSuccessfulRequests() { return m_successfulRequests; }
    int GetFailedRequests() { return m_failedRequests; }
    double GetSuccessRate() {
        return m_totalRequests > 0 ?
               (double)m_successfulRequests / m_totalRequests * 100 : 0;
    }
    double GetAverageResponseTime() { return m_avgResponseTime; }

    void ResetMetrics() {
        m_totalRequests = 0;
        m_successfulRequests = 0;
        m_failedRequests = 0;
        m_avgResponseTime = 0;
    }

    //--- Logging ---
    void EnableLogging(bool enable, string logFile = "") {
        m_loggingEnabled = enable;

        if(enable) {
            if(StringLen(logFile) == 0) {
                logFile = "BrowserAgent_" +
                         TimeToString(TimeCurrent(), TIME_DATE) + ".log";
                StringReplace(logFile, ".", "_");
                StringReplace(logFile, ":", "_");
                logFile += ".txt";
            }
            m_logFile = logFile;
            Print("Logging enabled: ", m_logFile);
        } else {
            if(m_logHandle != INVALID_HANDLE) {
                FileClose(m_logHandle);
                m_logHandle = INVALID_HANDLE;
            }
        }
    }

private:
    //--- Helper Methods ---
    string GenerateRequestId() {
        return "REQ_" + IntegerToString(GetTickCount()) + "_" +
               IntegerToString(MathRand());
    }

    string BuildAnalysisPrompt(string symbol, ENUM_TIMEFRAMES timeframe) {
        string prompt = "You are a Professional Hedge Fund Analyst.\n\n";
        prompt += "Analyze " + symbol + " on " + EnumToString(timeframe) + " timeframe.\n\n";
        prompt += "Provide:\n";
        prompt += "1. Directional Bias (BULLISH/BEARISH/NEUTRAL)\n";
        prompt += "2. Confidence Level (0-100%)\n";
        prompt += "3. Entry Price\n";
        prompt += "4. Stop Loss Level\n";
        prompt += "5. Take Profit Target\n";
        prompt += "6. Risk/Reward Ratio\n";
        prompt += "7. Key Support/Resistance Levels\n";
        prompt += "8. Technical patterns: Orderflow (P/B/D Shapes), Volume Profile Clusters, VWAP Deviations, ICT OB/FVG, CRT Theory.\n\n";
        prompt += "9. Sentiment Analysis\n";
        prompt += "10. Trade using: Order Flow + Volume Profile + VWAP Signal.";

        prompt += "Format your response with clear labels for each item.";

        return prompt;
    }

    bool SubmitToDeepSeek(string prompt) {
        // Wait for input area
        if(!WaitForElement("textarea", 15000)) {
            Print("DeepSeek: Input area not found");
            return false;
        }

        // Type prompt
        if(!Type("textarea", prompt)) {
            Print("DeepSeek: Failed to type prompt");
            return false;
        }
        Sleep(500);

        // Click send button
        string sendSelectors[] = {
            "button[type='submit']",
            "button.send-button",
            "[data-testid='send-button']"
        };

        for(int i = 0; i < ArraySize(sendSelectors); i++) {
            if(ElementExists(sendSelectors[i])) {
                if(Click(sendSelectors[i]))
                    return true;
            }
        }

        // Try pressing Enter
        string script = @"
            var textarea = document.querySelector('textarea');
            if(textarea) {
                var event = new KeyboardEvent('keydown', {
                    key: 'Enter',
                    code: 'Enter',
                    keyCode: 13,
                    which: 13,
                    bubbles: true
                });
                textarea.dispatchEvent(event);
            }
        ";

        string result;
        EvaluateScript(script, result);

        return true;
    }

    bool SubmitToQwen(string prompt) {
        if(!WaitForElement("textarea", 15000))
            return false;

        if(!Type("textarea", prompt))
            return false;

        Sleep(500);

        // Find and click send button
        string script = @"
            var buttons = document.querySelectorAll('button');
            for(var i = 0; i < buttons.length; i++) {
                var btn = buttons[i];
                if(btn.innerHTML.includes('svg') && !btn.disabled) {
                    btn.click();
                    break;
                }
            }
        ";

        string result;
        EvaluateScript(script, result);

        return true;
    }

    bool SubmitToClaude(string prompt) {
        string inputSelector = "[contenteditable='true']";

        if(!WaitForElement(inputSelector, 15000)) {
            // Try textarea as fallback
            inputSelector = "textarea";
            if(!WaitForElement(inputSelector, 5000))
                return false;
        }

        if(!Type(inputSelector, prompt))
            return false;

        Sleep(500);

        // Click send
        if(!Click("button[type='submit']")) {
            Click("button.send-button");
        }

        return true;
    }

    bool SubmitToGemini(string prompt) {
        if(!WaitForElement("textarea", 15000))
            return false;

        if(!Type("textarea", prompt))
            return false;

        Sleep(500);

        // Submit using Enter or button
        string script = @"
            var textarea = document.querySelector('textarea');
            if(textarea) {
                textarea.dispatchEvent(new KeyboardEvent('keydown', {
                    key: 'Enter', keyCode: 13, bubbles: true
                }));
            }
        ";

        string result;
        EvaluateScript(script, result);

        return true;
    }

    bool SubmitToChatGPT(string prompt) {
        string inputSelector = "#prompt-textarea";

        if(!WaitForElement(inputSelector, 15000)) {
            inputSelector = "textarea";
            if(!WaitForElement(inputSelector, 5000))
                return false;
        }

        if(!Type(inputSelector, prompt))
            return false;

        Sleep(500);

        // Click send button
        if(!Click("button[data-testid='send-button']")) {
            Click("button.send-button");
        }

        return true;
    }

    bool ExtractAIResponse(ENUM_AI_PROVIDER provider, string &response) {
        m_status = AGENT_WAITING;

        // Wait for response generation (with loading indicator check)
        int maxWait = 60000;
        int waited = 0;

        while(waited < maxWait) {
            // Check for loading indicator
            string script = @"
                var loading = document.querySelector('.loading, .thinking, [data-loading]');
                return loading ? 'loading' : 'done';
            ";

            string status;
            EvaluateScript(script, status);

            if(status != "loading")
                break;

            Sleep(1000);
            waited += 1000;
        }

        // Extract response text
        string responseSelectors[] = {
            ".message-content",
            ".response-content",
            ".markdown-body",
            "[data-message-content]",
            ".prose"
        };

        m_status = AGENT_EXTRACTING;

        for(int i = 0; i < ArraySize(responseSelectors); i++) {
            string script = StringFormat(
                "var elements = document.querySelectorAll('%s'); " +
                "if(elements.length > 0) { " +
                "  return elements[elements.length - 1].innerText; " +
                "} return '';",
                responseSelectors[i]
            );

            string result;
            if(EvaluateScript(script, result) && StringLen(result) > 50) {
                response = result;
                return true;
            }
        }

        // Fallback: get all visible text
        string script = "document.body.innerText";
        EvaluateScript(script, response);

        return StringLen(response) > 0;
    }

    bool ParseAnalysisResponse(string rawResponse, SAIAnalysisResult &result) {
        result.Init();

        string lower = rawResponse;
        StringToLower(lower);

        // Extract directional bias
        if(StringFind(lower, "bullish") >= 0 ||
           StringFind(lower, "buy") >= 0 ||
           StringFind(lower, "long") >= 0) {
            result.directional_bias = SENTIMENT_BULLISH;
        } else if(StringFind(lower, "bearish") >= 0 ||
                  StringFind(lower, "sell") >= 0 ||
                  StringFind(lower, "short") >= 0) {
            result.directional_bias = SENTIMENT_BEARISH;
        } else {
            result.directional_bias = SENTIMENT_NEUTRAL;
        }

        // Extract confidence
        result.confidence = ExtractNumber(rawResponse, "confidence");
        if(result.confidence == 0)
            result.confidence = ExtractPercentage(rawResponse);
        if(result.confidence > 100)
            result.confidence = result.confidence / 10;
        if(result.confidence == 0)
            result.confidence = 50;

        // Extract prices
        result.entry_price = ExtractNumber(rawResponse, "entry");
        result.stop_loss = ExtractNumber(rawResponse, "stop");
        result.take_profit = ExtractNumber(rawResponse, "target");
        if(result.take_profit == 0)
            result.take_profit = ExtractNumber(rawResponse, "profit");

        // Extract risk/reward
        result.risk_reward_ratio = ExtractNumber(rawResponse, "risk");
        if(result.risk_reward_ratio == 0)
            result.risk_reward_ratio = 2.0;

        result.reasoning = rawResponse;
        result.is_valid = true;

        return true;
    }

    double ExtractNumber(string text, string keyword) {
        string lower = text;
        StringToLower(lower);

        int pos = StringFind(lower, keyword);
        if(pos < 0)
            return 0;

        // Find number after keyword
        string number = "";
        bool foundDigit = false;
        bool foundDecimal = false;

        for(int i = pos + StringLen(keyword); i < StringLen(text) && i < pos + 50; i++) {
            ushort c = StringGetCharacter(text, i);

            if(c >= '0' && c <= '9') {
                number += CharToString((uchar)c);
                foundDigit = true;
            } else if((c == '.' || c == ',') && foundDigit && !foundDecimal) {
                number += ".";
                foundDecimal = true;
            } else if(foundDigit) {
                break;
            }
        }

        return StringLen(number) > 0 ? StringToDouble(number) : 0;
    }

    double ExtractPercentage(string text) {
        int pos = StringFind(text, "%");
        if(pos < 0)
            return 0;

        string number = "";
        for(int i = pos - 1; i >= 0 && i > pos - 10; i--) {
            ushort c = StringGetCharacter(text, i);
            if(c >= '0' && c <= '9') {
                number = CharToString((uchar)c) + number;
            } else if(c == '.' || c == ',') {
                number = "." + number;
            } else if(StringLen(number) > 0) {
                break;
            }
        }

        return StringLen(number) > 0 ? StringToDouble(number) : 0;
    }

    string TimeframeToTradingViewInterval(ENUM_TIMEFRAMES tf) {
        switch(tf) {
            case PERIOD_M1: return "1";
            case PERIOD_M5: return "5";
            case PERIOD_M15: return "15";
            case PERIOD_M30: return "30";
            case PERIOD_H1: return "60";
            case PERIOD_H4: return "240";
            case PERIOD_D1: return "D";
            case PERIOD_W1: return "W";
            case PERIOD_MN1: return "M";
            default: return "60";
        }
    }

    string NormalizeTradingViewSymbol(string symbol) {
        string result = symbol;

        // Add exchange prefix if needed
        if(StringFind(result, ":") < 0) {
            // Check if it's a forex pair
            if(StringLen(result) == 6) {
                result = "FX:" + result;
            }
        }

        return result;
    }

    void UpdateMetrics(bool success, int processingTime) {
        if(m_totalRequests == 1) {
            m_avgResponseTime = processingTime;
        } else {
            m_avgResponseTime = (m_avgResponseTime * (m_totalRequests - 1) +
                                processingTime) / m_totalRequests;
        }
    }

    void Log(string message) {
        if(!m_loggingEnabled)
            return;

        string logEntry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        logEntry += " | " + message + "\n";

        if(m_logHandle == INVALID_HANDLE) {
            m_logHandle = FileOpen(m_logFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
        }

        if(m_logHandle != INVALID_HANDLE) {
            FileSeek(m_logHandle, 0, SEEK_END);
            FileWriteString(m_logHandle, logEntry);
            FileFlush(m_logHandle);
        }
    }
};

#endif // BROWSERAGENT_MQH
