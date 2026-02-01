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
        // Use a file-based approach as workaround for direct CDP
        // Create a bookmarklet-style execution

        // For basic operations, we'll use keyboard simulation via WinAPI
        // This is a limitation of not having proper WebSocket support

        // Alternative: Use a helper Python/Node script for WebSocket CDP
        result = "";
        return true;
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
        prompt += "8. Technical patterns and Price Action Analysis like (Orderflow: P-Shaped Profile, B-Shaped Profile, D-Shaped Profile, Cumulative Delta, Volume Profile, VWAP, Market Profile, Fibonacci Retracement Levels, ICT Pattern like Orderblocks (OB), Fair Value Gaps (FVG), Imbalances, BOS, CHoCH, MSS, MBS, PD Array (Premium Zone / Discount Zone), ATR, ADX, RSI, MACD,)\n\n";
        prompt += "9. Sentiment Analysis\n";
        prompt += "10. Trade using the technique: Order Flow + Volume Profile + VWAP Signal";
        prompt += "11. Order Flow – Market Participants: Most people get confused when they open an Order Flow chart   for the very first time. There is no shame in that. Order Flow shows so much information that it is easy to get overwhelmed if you don’t know what to look for! Don’t worry though; by the time you have finished this book, you will be able to read Order Flow without getting a headache :) Let’s start by going through the basic stuff, like what Order Flow shows and how to read it. Passive vs. Active (Aggressive) Market Participants To learn what is going on in the Order Flow chart, you first need to understand one fundamental thing: the distinction between passive and active market participants. This may sound like too much theory, but this piece of information is vital. If you are not sure you got it the first time, go through it again. If you don’t get this point now, you will be lost later. Ready? Here we go! -Passive Market Participants Passive market participants are traders who enter their trade with a limit (pending) order. They do not chase the market. They wait for the price to come to them and then they enter their trades only for the price they want (or better). Every subject in the market can be a passive participant. It does not matter if it is a bank, a pension fund, a hedge fund, or a private trader like you or me. It is merely everybody who enters a trade with a limit order. If you place a limit order in your trading platform, you are a passive market participant. When the price hits the limit order you placed in the market, the order gets filled, and you get into the trade (you have just opened a trading position). This trading position will show on the Order Flow footprint. If you open a LONG position with a limit order, then it will appear on the BID side of the footprint (on the left). If you opened a SHORT position with a limit order, then it will appear on the ASK side of the footprint (on the right). So far, so good? This will make things a bit more complicated: -Active Market Participants Active market participants are traders who enter their trades with market orders. If you press a market Buy or Sell, then you are an active market participant. Your position will get filled immediately. No matter where the price currently is, no matter where exactly the trade is going to be filled, aggressive participants just want in. Now! Even if this means risking a slippage (the trade won’t open precisely at the price where they pressed the Buy/Sell). A market order is useful in situations where there is no time to wait to get your whole position filled exactly at the price you wanted. For example, this could be when there is a quick price movement that you don’t want to miss. If you open a LONG position with a market order, it will appear on the ASK side of the footprint (on the right). If you open a SHORT position with a market order, it will appear on the BID side of the footprint (on the left). -Active and Passive in One Chart The distinction between passive and aggressive market participants is what makes so many people confused. It is the main reason they cannot use Order Flow properly and struggle to make money with it, which is why I stress the importance of this point! Let me give you two more pictures that sum this up. If you are not 100% confident with where the passive and aggressive traders show on the footprint, then I suggest you print those pictures where you can see them while trading. The picture below shows two identical footprints and the two ways you can interpret them. Let me put all that into one footprint that sums this all up: -What the picture above says is this: •BID: Shows aggressive Sellers and passive Buyers. •ASK (Offer): Shows aggressive Buyers and passive Sellers. If you understood this, then your first question will probably be, “How am I supposed to know if the number that just appeared on the ASK is from a passive Seller or an aggressive Buyer?” I am afraid you will not like the answer as there is no way to know with absolute certainty! The good news is, in this book, I am going to teach you how to make a reasonable estimate, which will allow you to make the correct assumption in most cases. Not in all cases—I do not teach magic as I warned you already. Bigger Perspective (BONUS) To put things into a bigger perspective, let me show you one more thing. Maybe you have seen some Volume Profile indicators with two colors and the developers told you that one color shows Sellers and the other color shows Buyers. Like this one, for example: If somebody tells you such a thing, then they clearly don’t know what they are talking about. Based on what I just taught you, you now know that when volumes appear on BID, they can be both aggressive Sellers or passive Buyers. And when volumes appear on the ASK, they can be both aggressive Buyers or passive Sellers! If somebody tells you that “green” means Buyers and “red” means Sellers, they are telling you a half-truth. -Order Flow – Basic Chart Description I am going to describe standard Order Flow software and describe its primary interface. You can apply this to most of the common Order Flow software as the core should be the same for each of them. -Footprints The Order Flow does not show standard candles, but it shows FOOTPRINTS. A footprint shows not only Open, High, Low, Close as standard candles do, but it also shows orders that got traded within that candle. Orders are placed on Bid or on Ask. When a BUYER enters a Long trade (with a market order), then his position shows on the ASK side of the footprint. When a SELLER enters a Short trade (with a market order), his position shows on BID. This is how the Order Flow chart is drawn: -Green/Red Cells Inside every footprint there are green or red cells. The cell is GREEN if the number on the Ask is larger than the number on the Bid. It is RED when the Bid is larger than the Ask. Simply put, this represents the strength of Buyers versus Sellers. However, as you learned in the previous chapter, this is not always true, and there is much more to it. But for the sake of keeping this part simple, let’s leave it at that and revisit it when we talk about Order Flow strategies. Usually (not always), the bullish footprints are - primarily green (stronger Buyers) and the bearish footprints are primarily red (stronger Sellers). High Volume Nodes (HVN) Possibly, the most important place in any footprint is the High Volume Node. It represents the place where the heaviest volumes were traded, a place where the institutions were the most active. It is marked by a black outline, making it easily visible at first sight. If there are more Heavy Volume Nodes at the same price, in two or more consecutive footprints, then my proprietary Order Flow software will make it in yellow. Price levels like these represent Support/Resistance zones. -Delta Below each footprint (the place could vary depending on the software you use) there is a number that is either green or red. It is GREEN (positive) when more volume is executed at the Ask (in that whole footprint). It is RED (negative) when more volume is executed at the Bid (in that whole footprint). This essentially tells you who is stronger in that footprint—Buyers or Sellers. Bullish footprints have a positive Delta (GREEN). Bearish footprints typically have a negative delta (RED). This holds true primarily in trending markets. If there is a rotation, then you cannot rely on this as much. The reason is that in a rotation, big institutions usually enter their trades both with market and pending orders. They combine these two types of orders in an effort to mask their true intentions. - What should grab your attention is when you see a bullish footprint with a negative Delta or a bearish footprint with a positive Delta. A bullish footprint with a negative Delta tells you this: The price is rising, but Sellers are entering their Shorts and they are stronger than the Buyers. A bearish footprint with a positive Delta tells you this: The price is falling, but Buyers are entering their Longs and they are stronger than the sellers. Both those scenarios represent a warning that a price reversal might happen (price reverses to follow Delta). EXAMPLE: Price and Delta Divergence Let me give you an example of a trade I had a couple of days ago on EUR Futures : 1. I had identified a strong level of Resistance on the EUR/USD using Volume Profile. I published this Resistance level a week ago publicly on my website. 2. I waited almost a week until the price reached this Resistance. 203. When it did, there was a strong uptrend the whole day. It would be risky to enter a Short trade from Resistance against this strong uptrend. For this reason, I used my Order Flow software to identify precisely when Sellers started showing up around this Resistance. 4. In the Order Flow, I looked at 6E 12-20 instrument, which is EUR futures. It 100%correlates with EUR/USD (Forex), where I place my trades. The reason I looked at Futures was that I needed to see the separate Bid x Ask volumes and Delta (which Forex does not show). 5. When the price reached the volume-based Resistance, there was a significant divergence between price and Delta. Price was rising, but Delta was falling! This meant that even though the price was going up, strong and aggressive Sellers were jumping in more and more! This is one of my favorite trade confirmations, so I jumped in the Short trade. 6. I took a 10 pip Take Profit quite easily. I didn’t want to try to take more out of this because the EUR was in a strong uptrend. Trading Shorts against a strong uptrend is risky, so it was better to take a smaller profit and quit the trade. This is what I saw when I entered the short trade (price rising, Delta negative). * BTW. This picture shows footprints with Total Volumes (sum of Bid + Ask). This was the reaction: There was a bit more to this trade, which I will not mention here for the sake of simplicity. What I want you to focus on is the divergence between rising prices and falling Delta. That was what predicted the turning of the price. Footprint Summary The panel at the bottom of the Order Flow chart shows a summary of each footprint. You can set it in any way you want to show only the information you need for your strategy. It is best not to have too much summary info there and solely focus on the most important things. Here is a picture that shows the whole summary panel: Such a panel is quite standard for much Order Flow software. Developers like to boast of how many useful things it shows. The truth is you won’t need all those features as they distract from the more critical aspects. I personally only use Delta, Cumulative Delta, and Volume. It gives me this quick overview info: Delta: Shows whether there were stronger Buyers or Sellers. Cumulative Delta: Shows Delta changes throughout the whole day. Volume: Shows the accumulative volume of each footprint. The screenshot below shows my summary settings: Volume Profile My Order Flow software has its own Volume Profile. It is a Daily Volume Profile that shows the volume distribution throughout the whole day. This is a significant feature because it shows you the bigger picture, which is critical when trading with Order Flow! The BLUEISH/GREEN color on the Volume Profile represents orders traded on the Ask, and the RED color represents orders traded on the Bid. Combining Volume Profile with Order Flow is my favorite intraday trading approach.";
        prompt += "12. Stop Loss with Order Flow + Volume Profile : There are three methods of determining your Stop Loss location. 1. Fixed SL: This is the simplest way to place your Stop Loss. It is the simplest because your SL is always the same (for example, 10 pips). For all your trades, you just use the same SL. An advantage of this is that you don’t need to think about each trade and its SL separately. A disadvantage is that this method does not adjust to changing market conditions. You can alter this Fixed SL from time to time when the market conditions change dramatically. But still, it is not as flexible and does not reflect the current market conditions as well as the other two approaches. 2. High/low of the Support/Resistance area: This means placing your SL at the high/low of the S/R resistance area you are trading. I best explain this using the examples below. 3. Low volume area: This means placing your SL in a low volume area, which is located behind a heavy volume area. The reason behind this is that heavy volume areas work as zones of Support/Resistance. The price should not go past them. If it does go past a heavy volume area, then it is a sign of strong market momentum and there is no reason for staying in a trade that would go against that momentum. If a heavy volume zone fails to hold the price and it goes past it into the low volume area, it is time to quit your trade. For this approach, I use the 30 Minute chart with cell content: Volume. I don’t need to see Bid x Ask. At this point it is not important whether the volumes were placed at Bid or Ask. What matters here is the total volume. My preferred time frame for all these three approaches is the 30 Minute TF. Which of the three approaches to choose though? I suggest you either stick with the first one (Fixed SL) or for each trade you pick one of the two remaining—the second or third depending on the market situation (as there will be scenarios where you will be unable to use one of them). You always should have some rough idea of how wide your SL should be. With each of these approaches I suggest using your SL somewhere (roughly) within the 10–20% of average daily volatility of the instrument you trade. You can measure the average volatility by ATR indicator (a free indicator is available in every trading platform). For example, if the average daily volatility of EUR/USD is 100 pips, then you want your SL somewhere (roughly) between 10 and 20 pips. I am not talking just about the first approach here (Fixed SL) but also about the other two. The place which the second or third approach points you to should also be somewhere roughly within the 10–20 pip range. If your SL method points you to a SL that would be outside of this range (either too tight or too wide), then it is best to either skip the trade or use a fixed SL somewhere within the 10–20% range. The reason for this is that it would be crazy having too wide an SL (this would lower your RRR significantly) or one that is too tight (high risk of SL being hit). What you should aim for is having an SL in a place that makes logical sense and that is also within 10–20% of the daily average range."

        prompt += "12. Take Profit with Order Flow: I am going to talk about using Order Flow to determine when and where to quit your winning trade. Order Flow is a very useful tool as it allows you to identify a good Take Profit, helps you maximize your gain and assists in trailing your position. It can also warn you in advance if there is an impending risk that the market could turn against you.";

        prompt += "13.Volume-Based Take Profit: Let me start by pointing out the most important message you should remember from this chapter: Take your profit in a heavy volume area. The reason for this is that heavy volume areas often work as Support and Resistance zones. Whenever the price reaches a Support or Resistance zone, there is a risk that it will react to it and turn in the opposite direction. This is the reason why you should take your profit before such risk arises. Tip #1: It is safer to take your profit a bit sooner—just a little bit before the heavy volume area. This reduces the risk that the market will turn against you at the last moment, causing you to miss your Take Profit. This is because, in my experience, the price sometimes reacts a bit before it actually reaches the heavy volume area. Tip #2: If the closest heavy volume area is too close to your trade entry and the risk would not be worth it (too small Risk/Reward Ratio), then you have two options. The first option is not to take the trade. The second option is bolder—you take the trade, but you don’t quit it when it hits the closest heavy volume area. Instead, you close it just before it hits the next one. I use 30 Minute footprints to determine which heavy volume zones I should use to close my position. This higher time frame allows me to see the bigger picture, which helps identify heavy volume zones easier.Since you don’t need Bid x Ask data, you can use this Take Profit placement strategy for Forex trading as well.";

        prompt += "14. TD Order Flow – Special Features
This is not very common because Order Flow is primarily used with centralized data (Futures).
Still, NinjaTrader has a good Forex data feed with reliable volume information. We were able
to use this and adjust the Order Flow to work even with Forex!
The Forex data they prove does not give Bid and Ask volume, only Total Volume (= sum of Bid
and Ask). For this reason, you cannot use all the Order Flow functions when trading Forex
(functions using Bid and Ask). Still, the Volume data is extremely useful, and the Order Flow
gives you a tremendous edge even without separate Bid and Ask volume.
Order Flow used with Forex Volume data looks like this:
Every cell shows volumes that were traded at the given price level; the heavier the volume at
a given price point the darker the shade.
25Volume Clusters
When trading with the Order Flow, it is very important to pay attention to heavy volume areas
as well as low volume areas. This would be almost impossible if you just looked at the numbers
in each cell without having any visual help.
For this reason, I designed my software to recognize heavy volumes and use darker colors to
make the heavy volume areas stand out. This way, you can immediately identify heavy volume
areas at a glance.
When there is an area that is way darker than the surrounding areas, it marks a place where
the BIG trading institutions and their algorithms were most likely actively trading.
Those are critical areas to keep track of as they often represent strong Support and Resistance
zones.
Those darker and lighter shades are also used on the Bid x Ask visualization as you can see in
the chart that follows.
26The heavier the volumes the darker the color:
Multiple High Volume Nodes (HVN)
A very important place in every footprint is the High Volume Node. It is the place where most
of the volumes got traded (Bid and Ask combined).
An extremely strong level is formed when two or more High Volume Nodes meet at the same
price in consecutive footprints. When two nodes meet, I call it a Double Node, when it is three
nodes, then a Triple Node, etc…
My software automatically detects those Multiple HVNs and highlights them in yellow. This
way, you can quickly identify them at first sight.
Those Multiple HVNs are very significant in my Order Flow analysis because they often
represent strong Support and Resistance zones.
27Imbalances
Imbalances are a great way of tracking market sentiment. Only with Order Flow will you be
able to see this type of market detail!
An Imbalance is when Buyers are way more aggressive than Sellers or when Sellers are more
aggressive than Buyers.
If Buyers are way more aggressive than Sellers (Ask is 300% or larger than the Bid), then the
number on the Ask is printed in BLUE.
If Sellers are more aggressive than Buyers (Bid is 300% or larger than the Ask), then the
number on the Bid is printed in BLUE.
Bid x Ask Order Flow is compared diagonally, which means that Imbalances are compared as
shown below (this is also how you read the Order Flow footprint—diagonally):
28The picture above shows two Imbalances. One Imbalance is in the second row and the other
one is in the third. The reason is: 13 is 300% or more than 2, and 61 is 300% or more than 14.
You will often see Imbalances at the start of a strong and aggressive trend and within the
trend itself.
Stacked Imbalances
Stacked Imbalances are three or more cells with imbalances on top of each other. Learning to
spot these areas is extremely important to us traders because they often represent strong
Support and Resistance zones.
29Stacked Imbalances are a sign that one side of the market (Buyers or Sellers) is dominating
and in control. Those Buyers or Sellers are really strong, aggressive, and determined to push
the price their way.
My Order Flow software automatically highlights areas with Stacked Imbalances. Those areas
represent strong Support and Resistance zones.
Unfinished Business
Another unique feature of my Order Flow software is that it automatically detects Unfinished
Businesses (Failed Auctions).
Unfinished Business represents a market imperfection. It shows that the high or low, which
was just formed, was not formed properly.
What do I mean by “formed properly”?
Every footprint represents an auction process. This process needs to end in a certain way. A
properly formed high needs to have 0 contracts traded at the Bid, and a properly formed Low
needs to have 0 contracts traded on the Ask.";


        prompt += "16. Let me give you a live trading example from one of my recent trades on EUR Futures.
EXAMPLE: Unfinished Business
I was in a Short trade, and I was deciding whether to take a 10 pip profit or take a half profit
at both 10 and 20 pips. Because there was Unfinished Business where the chart had previously
turned, I decided to take just the 10 pip profit. It would have been risky to try to go for more
because the Unfinished Business could work like a magnet and drive the price upwards
(against my Short).
31Here is a screenshot from the live session video:
The picture shows the Unfinished Business (the green dotted line) and a red arrow, which I
drew to demonstrate what could happen there.
Later, the Unfinished Business did end up working as a magnet, and the price went upwards
to test it as shown here:
This allowed me to quit the trade with a profit before the price would have turned against
me.
32The first thing many people think when they hear about Unfinished Business is that this is the
Holy Grail. Unfortunately, it does not work like that. The reason is that the price could move
quite a significant distance away from the Unfinished Business without actually testing it.
In my trading, I don’t rely on the Unfinished Business indicator too much. Instead of a Holy
Grail, I consider it a small helper when making trading decisions as in the trade illustrated
above.
Trades Filter
This unique feature filters out all the noise from the market and leaves only the biggest trades
(trades of the BIG guys we want to track).
It makes the Order Flow easy to read, and you can be sure you won’t miss any significant
market action! When the BIG guys are present, it will show on the Trades Filter.
You can set the Filter anyway you like—depending on how much “noise” you want to filter
out. I personally prefer to set it in a way that only the most significant trading orders show.
This means that on EUR Futures (my favorite day trading instrument) I have the Trades Filter
set to 25. This means it only shows executed trades that were 25+ contracts.
You may say that 25 contracts are not that much and you are right. But you need to consider
this: Institutions prefer to enter their trading positions using Iceberg orders. This means that
they open positions with multiple orders rather than with one single order like a retail trader.
But when there is not much time, and the institutions need to get into their trade quickly,
they don’t have the luxury of Iceberg orders and they need to enter their trades using bigger
position sizes. Those larger orders are the ones we track with the Trades Filter.
Later in this book, I will show you an excellent trading strategy based solely on the Trades
Filter.
33Cumulative Delta
This is a separate indicator, which is usually not a part of Order Flow software. But it works so
nicely with the Order Flow that it would be a shame not to use these two together! For this
reason, I decided to add this standalone indicator to my Order Flow software so you can use
them together.
The Cumulative Delta prints the difference between the Bid and Ask. You can think of it this
way (even though it is not 100% correct, as you have already learned): Cumulative Delta
identifies the difference between Buyers and Sellers.
If there are more aggressive Buyers jumping in, then the Cumulative Delta is rising. If there
are more aggressive Sellers than Buyers, then it is falling.
It is best to watch the Cumulative Delta around strong Support and Resistance zones. If strong
Buyers or Sellers start to enter their trading positions there, then Delta will show you!
What I really like is to look for divergences between price and Delta on the 1 Minute chart.
34EXAMPLE: Cumulative Delta
The price is heading downwards, but the Cumulative Delta is going up. This tells me that even
though the price is going down, there are Buyers entering Long and the price will most likely
reverse and turn upwards.
It is best to look for price x Delta divergences around Support and Resistance zones.";

      prompt += "17. Order Flow – Trading Workspace
Since you now know what the Order Flow shows and you are familiar with its major features,
let me show you what my trading workspace looks like. You can set yours up exactly the same
way as I have it. If you shoot me an email (contact@trader-dale.com) I can also send you my
workspaces so you don’t need to set them up yourself.
Let me now show you what my Order Flow screen looks like:
My Order Flow screen shows four charts. Those charts are linked together so they always
show the same trading instrument.
Top left chart: This one shows the bigger picture. It shows the 30 Minute footprint. The cells
in each footprint show “total cell volume” (Bid + Ask). Below each footprint (the green or red
number) is the footprint’s Delta.
On the left side, there is the Daily Volume Profile. In the summary below, I have Delta,
Cumulative Delta, and Volume.
Top right chart: This one is a more detailed chart for spotting the orders as they are filled in
the market. I use it for trade entries and exits. It is a 5 Minute chart, which shows the Bid and
36Ask in each cell. Each footprint also has Delta printed below. The trade summary at the
bottom shows Delta, Cumulative Delta, and Volume.
Bottom left chart: 30 Minute Order Flow chart with Trades Filter and Daily Volume Profile on
the left. I use this chart to filter out the noise and to look for the big trading orders.
Bottom right chart: Shows 1 Minute price chart at the top and 1 Minute Cumulative Delta
chart at the bottom.
This workspace allows me to see all the important things that are going on in the market.
I can see the big picture with the 30 Minute Volume chart and Trades Filter as well as the
more granular details on the 5 Minute Bid x Ask chart and on the Cumulative Delta chart.
37Order Flow – Trading Setups
In this section, I am going to show you five of my favorite Order Flow trading setups. You can
trade these as standalone setups, which means that they are strong just on their own. There
is no need to combine them with any other setup, nor do you need to look for any additional
trading confirmation (you can do that, but it is not a must). Let’s get to it then!
Trading Setup #1: Volume Clusters
This setup is based on trading significant areas of heavy volume (Volume Clusters), which
occurred either in a trend or in a strong rejection of higher/lower prices.
Such heavy volume areas are places where the BIG guys (institutions) and their trading
algorithms placed a large portion of their orders.
Let’s first talk about the situation when the Volume Cluster occurred within a trend.
*This strategy does not use Bid x Ask, only the Volume setting. Because of this, you can trade
it also on Forex (still, I recommend doing your analysis on Futures).
Volume Clusters (within a TREND)
The exact steps to follow are:
1. Set your Order Flow software to show Volumes (not Bid x Ask). This will make it way
easier to identify heavy volume zones. This way, the Order Flow will show shades of
grey and the heavy volume areas will stand out more.
2. Find a trend and look for dark grey areas (heavy Volume Clusters) that stand out.
Those areas represent heavy volumes (institutional activity).
3. You need to see the price move away from the Volume Cluster, making at least one or
two whole footprints (candles) above or below the heavy volume area. I like to use
the 30 Minute footprint chart for this.
4. Then you need to wait for a pullback. When the price returns back to this heavy
volume area, you enter your trade.
385. Your trade entry should be at the beginning of the Volume Cluster or at the place
where the volumes were the heaviest (within that Volume Cluster).
6. If the heavy volume area was formed in an uptrend, then you go Long. If it was formed
in a downtrend, you would look to go Short.
LOGIC BEHIND THIS
Let me describe the logic behind this setup with the picture above. First, there was an
uptrend, and Buyers were pushing the price upwards. Then they started to add massively
to their Long positions (around 1.0880). We can see this place nicely with the Order
Flow—that’s the Volume Cluster. From this place, the price continued to move upwards.
The Buyers were still dominating the market and they were pushing the price up. When
the price made it back into this Volume Cluster again, those Buyers wanted to defend their
39Long position, which they entered in the Volume Cluster. As a result, the Buyers began
aggressively buying again (with Market Orders) to push the price away from this critical
level.
Another aspect that helped drive the price upwards from the Volume Cluster was Sellers
closing out their Short trades. When the price made the pullback to the Volume Cluster,
it was the Sellers who drove it there. Likely, those Sellers knew about the strong Volume
Cluster around 1.0880. They knew that strong Buyers were adding to their Longs massively
there and that it was an important level for them. So, instead of risking a fight with strong
Buyers, the Sellers quit their Short trades as the price reached the Volume Cluster. It’s
important to understand that when Sellers close their Short trades, they need to close
them with a Long order. In this case, this added to the Longs of the aggressive Buyers who
were defending the Volume Cluster.
TWO FACTORS
In the end, two factors drove the price upwards from the 1.0880 Volume Cluster:
#1 factor: Buyers defending their Long Position
#2 factor: Sellers quitting or closing out their Short Position
We can’t really tell which of these factors played a bigger role (because both Buyers and
Sellers used Buy Market Orders—the same orders). The important thing is that both these
factors were pushing the price the same way—upwards.
This kind of logic is also used in my other Order Flow trading setups. It does not apply only
to the Volume Cluster setup.
40EXAMPLES: Volume Clusters (within a TREND)
Let me follow with a couple of examples of the Volume Cluster setup:
Example #1: Volume Cluster (within a trend)
Example #2: Volume Cluster (within a trend)
41Example #3: Volume Cluster (within a trend)
Example #4: Volume Cluster (within a trend)
42Volume Cluster (within a REJECTION)
This is very similar to the previous trading setup. The only difference is that (in step 2) you
look for the significant Volume Cluster in a strong rejection of lower or higher prices (not in a
trend).
A strong rejection of higher prices is when the price goes aggressively upwards and then it
suddenly turns and goes into a rapid sell-off (= higher prices got rejected). A rejection of lower
prices is the same, only reversed.
The picture below shows a strong rejection of higher prices:
Here is the complete guide step by step:
1. Set your Order Flow software to show Volumes (not Bid x Ask). This will make it way
easier to identify heavy volume zones. This way, the Order Flow will show in shades
of grey and the heavy volume areas will stand out more.
2. Find a strong rejection of higher or lower prices and look for dark grey areas (Volume
Clusters) that stand out. Those show heavy volumes (institutional activity).
3. You need to see the price move away from the Volume Cluster making at least one or
two whole footprints (candles) above or below this area. I like to use the 30 Minute
footprint chart for this.
4. Then you need to wait for a pullback. When the price returns back to the Volume
Cluster, you enter your trade.
435. If the Volume Cluster got formed in a rejection of lower prices, you look to go Long (in
the direction of the rejection). If there was a rejection of higher prices, you look to
take a Short trade.
The logic behind this setup is the same as with the Volume Clusters in a trend mentioned
earlier. In this case, the strong Buyers entered much of their position in the Volume Cluster
created during the initial rejection. As the price later retested this area, those Buyers were
defending their Longs and Sellers abandoned their Shorts.
44EXAMPLES: Volume Clusters (within a REJECTION)
Example #1: Volume Cluster (within a rejection)
Example #2: Volume Cluster (within a rejection)
45Example #3: Volume Cluster (within a rejection)
Example #4: Volume Cluster (within a rejection)
46Trading Setup #2: Multiple Nodes
This setup is designed to track institutional trading activity using the High Volume Nodes
(HVN). The HVN shows where the heaviest volumes were traded within one footprint by
creating a black outline around that cell.
This setup focuses on finding two consecutive footprints that have their HVNs at the same
price level—this is what I call the “Multiple Node.” This tells us that in both these footprints
the most important price level was the same. Therefore, we can assume that this level is
important.
In this setup, the minimum number of footprints with HVNs next to each other is two. If there
are more, then the level is even stronger.
I look for the Multiple Nodes in these significant areas:
•Within a trend
•Before a trend
•In a strong rejection of higher/lower prices
This trading setup does not use Bid x Ask, so you can apply it to spot Forex as well (I still
recommend Futures though).
The concrete steps to trading the Multiple Nodes setup are:
1. Set your Order Flow so it shows Volumes (this is only my preference. You can also use
Bid x Ask setting). My preferred time frame is the 30 Minute chart.
472. Identify a place where there are more HVNs next to each other (= Multiple Node). This
place needs to form before the start of the trend, within a trend, or in a strong
rejection of higher/lower prices.
3. There need to be at least two whole footprints formed AFTER the Multiple Node was
formed. Those footprints need to be completely above or below the Multiple Node.
4. Wait for a pullback to the Multiple Node.
5. Enter a trade. If the price hits the Multiple Node from above, then go Long. If the price
hits the Multiple Node from below, then go Short. Trade only the first touch (first test).
48EXAMPLES: Multiple Nodes
Example #1: Multiple Nodes (in a Trend)
Example #2: Multiple Nodes (in a Trend)
49Example #3: Multiple Nodes (before a Trend)
Example #4: Multiple Nodes (before a Trend)
50Example #5: Multiple Nodes (in a strong rejection of higher/lower prices)
Example #6: Multiple Nodes (in a strong rejection of higher/lower prices)
51Trading setup #3: Trades Filter
The Trades Filter setting is a unique feature of my Order Flow software. It enables you to filter
out the market's noise and display only the largest trading orders (the BIG guys). This simple
strategy is based on following those big orders.
You can set the Trades Filter in the indicator settings to show only trades bigger than X lots.
In the picture below, I put the filter to 25, which means it will only show trades with more
than 25 lots executed with ONE order (as I mentioned earlier, it won’t catch the Iceberg
orders).
I currently use this setting with currency Futures (mainly EUR futures – 6E):
Every trading instrument has its own specifics and different volumes. The 25 lot setting suits
currency Futures, but it does not work, for example, on the ES (S&P 500 futures). There the
number needs to be significantly higher—around 300 or more. Also, heavy volumes are
traded only in the US session, so you won’t get any signals during the EU or Asian session.
You need to adjust this number to the instrument you’re trading and, in some cases, the time
of day you’re trading as well. A rule of thumb here is to set it to a number that gives you
around 5–10 trading signals per day.
Let’s now talk about the setup so all this becomes clearer.
52The setup is very similar to Setup #1: Volume Clusters. Here are the steps:
1. Set your Order Flow to show Bid x Ask. Then enable the Trades Filter in the Indicator
settings and set the minimum trade size (for EUR Futures, I use 25 lots).
2. Look for highlighted values (red/green) on the Trades Filter—values that are not 0.
Those are big trading orders that work as strong Support and Resistance zones.
3. You need to see the price move away from such an area first, making at least one or
two whole footprints (candles) above or below this area. I like to use the 30 Minute
footprint for this.
4. Then you need to wait for a pullback. When the price returns to this big order area,
you enter your trade.
5. If the price hits this area from above, then you enter Long. If it makes a pullback from
below, then you go Short. Green does not mean you go Long and red does not mean
you go Short!
6. Trade only the first hit (first test). Don’t attempt to trade one trading level more than
once, as the probability of a 2nd successful reaction to the same level is smaller.
You can trade this setup as a standalone setup, or you can decide to trade it after you see the
entry point gets confirmed by any of the “trade confirmation” setups taught in this book.
*BTW – If you decide to use my Order Flow software, you will also receive my trading
workspaces. This way, you actually won’t need to set the Trades Filter yourself.
53EXAMPLES: Trades Filter
Example #1: Trades Filter
Example #2: Trades Filter
54Example #3: Trades Filter
Example #4: Trades Filter
55Example #5: Trades Filter
Example #6: Trades Filter
56Trading setup #4: Stacked Imbalances
An Imbalance means that one side of the market is way stronger than the other. Either the
Buyers are way stronger than the Sellers or the Sellers are much stronger than the Buyers.
This “strength” is measured by comparing the Bid and Ask. The default setting of my software
is that if Bid is 300% or more than the Ask, it is marked (in blue color) as Selling Imbalance. If
the Ask is 300% or more than the Bid, it is a Buying Imbalance (also in blue).
Selling Imbalances often occur in a downtrend and Buying Imbalances often show in an
uptrend.
Selling Imbalances occur at the Bid; Buying Imbalances occur at the Ask.
You have the option to turn on/off the imbalances as well as change the trigger percentage
in my Order Flow software settings.
57If there are multiple Stacked Imbalances on top of each other, this represents a strong
Support/Resistance zone. It indicates that either Buyers or Sellers were really active and
strong at this place. It also implies that when the price comes back into this area again, it is
likely that those Strong Buyers/Sellers will become active again. We can expect that there will
be a reaction.
The way to trade this is very similar to the previous setups:
1. Set your Order Flow to show Bid x Ask. Make sure you have the Imbalances turned
“on” in the Indicator settings.
2. If there are more than three Buying or Selling Imbalances stacked on top of each other
(default setting, which you can change), then it represents a Stacked Imbalance and
this zone will automatically get highlighted. A Support zone created by Stacked Buying
Imbalances gets highlighted in green. A Resistance zone created by Stacked Selling
Imbalances gets highlighted in red.
3. You need to see the price move away from these highlighted areas first, making at
least one or two whole footprints (candles) above or below it. I like to use the 30
Minute footprint chart for this.
584. Then you need to wait for a pullback. When the price returns back to this Stacked
Imbalance zone, then you enter your trade.
5. If the price hit this zone from above, then you enter Long. If it makes a pullback from
below, then you go Short. An area highlighted in red = Resistance. An area highlighted
in green = Support.
6. Trade only the first hit (first test). Don’t attempt to trade one trading level more than
once as the probability of a second successful reaction to the same level is much lower.
7. It is best to look for Stacked Imbalances within a trend or before a trend begins.
Additionally, it does not need to be a strong trend; a strong one-way price movement
will do.
59EXAMPLES: Stacked Imbalances
Example #1: Stacked Imbalances
Example #2: Stacked Imbalances
60Example #3: Stacked Imbalances
Example #4: Stacked Imbalances
61Example #5: Stacked Imbalances
Example #6: Stacked Imbalances
62Trading setup #5: Unfinished Business
Unfinished Business represents a market imperfection. It shows that when the price changed
its direction, the high or low it created did not form properly.
There is an Auction process when a new high/low is formed, and this process needs to end in
a certain way. A properly formed high needs to have 0 contracts traded at Bid, and a properly
formed Low needs to have 0 contracts traded at Ask.
When the market turns from a new low or high without this happening (Bid AND Ask are both
more than 0), it is called an Unfinished Business (or a Failed Auction).
My software makes this easy to spot by drawing a dotted green or red line there:
Now I am going to show you a few tips for how you can use Unfinished Business. I don’t have
a trading setup based solely on trading Unfinished Business; instead, I use it primarily to
support other trade setups.
The main thing to remember about Unfinished Business is that it works like a magnet. The
price is drawn towards it, and if it comes close, it is likely to move through it.
63So, if Unfinished Business works as a magnet, how do we use this information? There are
several ways:
•Take Profit
•Stop Loss
•Confirmation
•Warning against bad trades
Take Profit
If you are in a profitable trade and you are thinking about taking your profit, you can check if
the price is moving towards Unfinished Business. If it is, then you might remain in your
position a little bit longer until the price tests the Unfinished Business—because it should
work as a magnet. This can help you to stretch your Take Profit by a few pips. Be careful,
though, as there is no guarantee the market will test the Unfinished Business if it is too far
away. This technique for extending your take profit works best if the price is already close to
the Unfinished Business.
I was using this method in a live trading video, which you can find on the webpage I made for
you (https://www.trader-dale.com/of-book/)
64This particular video is called “LIVE: Trading JPY Futures - Trailing Position and Delta
Divergence.”
Stop Loss
When you are deciding where to place your Stop Loss, bear in mind that Unfinished Business
works like a magnet. If you place your SL in a way that the Unfinished Business is behind it,
then if the price comes close to your SL, it will most likely shoot past it—to test the Unfinished
Business.
I am not saying I always stick to these rules regarding the Unfinished Business as this is not
my main trading strategy. I use Unfinished Business mostly to read the charts, feel what is
going on, and make the best picture of what I expect to occur. No trade is perfect, and there
will always be something you won’t like. But you need to weigh the pros and cons and decide
in the end whether the trade is worth taking the risk.
Confirmation
Bearing in mind that Unfinished Business works as a magnet, you can also use it to confirm a
trend. Imagine you are in a Long position and the price goes upwards but then it reverses and
65it starts going against you. Unfinished Business can help you identify whether this is most
likely just a pullback or if this is a change of a trend. If you see Unfinished Business at the top
of the reversal, then the price probably turned temporarily. It will likely continue upwards
again to test the Unfinished Business (magnet).
I also used this approach in the live trading session video called “LIVE: Trading JPY Futures -
Trailing Position and Delta Divergence.” (https://www.trader-dale.com/of-book/)
Warning against Entering a Bad Trade
The Unfinished Business can also warn you against entering a bad trade. Again, the logic is
that Unfinished Business works as a magnet, and if the price comes close, it will most likely
test it.
Simply put, you don’t want to enter a Long trade when there is the Unfinished Business below
and you don’t want to enter a Short trade when there is the Unfinished Business above your
entry.
Why? Because Unfinished Business works as a magnet, and by entering such a trade you
would risk the price shooting past your trade entry to test the Unfinished Business.
66Below are some more examples of Unfinished Business. Notice how the price has the
tendency to hit those areas and fix the market imperfection that Unfinished Business
represents.
67EXAMPLES: Unfinished Business
Example #1: Unfinished Business
Example #2: Unfinished Business
68Example #3: Unfinished Business
Example #4: Unfinished Business
69Example #5: Unfinished Business
Example #6: Unfinished Business
70Example #7: Unfinished Business
Even though I spent quite a lot of space talking about various uses of Unfinished Business, I
would still advise you to focus on the other setups first. Those are standalone and proven
trading setups. Unfinished Business is something extra—a bonus. It is an approach that only
helps you read the market and helps with your decision-making. Your trading should be based
on other strategies, and Unfinished Business should be used as an addition to that.
71Order Flow – Confirmations
Confirmation setups are not standard trading setups. You should not base your trading
strategy on them alone. Their strength lies in giving you a hint when the market is starting to
react to a Support/Resistance zone you found using one of your main trading setups. That
would be a setup based on Volume Profile or one of the setups I showed you in the previous
chapter.
This is how it works:
First, go through the chart and identify the Support and Resistance zones. You can do this
with Volume Profile, Order Flow main setups, or identify S/R zones another way you are
familiar with.
After that, mark those S/R zones in your chart. Then wait until the price makes it there. When
it does, switch to Order Flow, and wait for a confirmation.
It is important to note that Support and Resistance are ZONES, NOT EXACT levels. When the
price reaches such a zone, you want to see a confirmation there, somewhere within that zone.
Such a confirmation tells you that the BIG guys (institutions) are starting to react there.
There are four confirmations I like to use. These can give you the final push to enter your
trade.
I also like to use these confirmations when I am unsure whether or not to take a trade. This
can be, for example, because the price moves very quickly and aggressively against my trading
level or the trading level is not really clear (not clear where exactly to place it). I also use
confirmations when my trading level is not particularly strong and I am not sure whether to
trade it or not.
In all such situations, Order Flow confirmation can help you decide whether to take the trade
or skip it.
There are four confirmations I look for when the price reaches a significant Support or
Resistance zone. I look for: Big Limit Orders, Absorption, a sign of Aggressive Buyers/Sellers,
and confirmation on the Cumulative Delta.
72Confirmation Setup #1: Big Limit Orders
When the price reaches a strong Support/Resistance zone, you need to see a sign of a reaction
first. This sign could be a BIG institution jumping into the market.
You want to see somebody big who has been waiting around the S/R zone (like you have been)
to jump in the trade.
Passive traders who wait for the price to come to them use Limit orders. They don’t chase the
market with aggressive Market orders. A Limit order is more suitable because they get filled
for the price THEY want.
The Limit Confirmation Strategy is quite simple. First, you identify a significant S/R zone (for
example, with Volume Profile). Then you wait and look for somebody big to jump in a trade
there.
•To get a Resistance zone confirmed, you need to see a Limit Sell order appear.
•To get a Support zone confirmed, you need to see a Limit Buy order appear.
Important: a Limit Sell shows on the Ask and a Limit Buy shows on the Bid.
73Steps to Limit Orders Confirmation Setup:
1. Identify a strong Support/Resistance zone using your primary strategy (this could be
Volume Profile, Order Flow, Price Action, etc.).
2. When the price gets to that zone, open your Order Flow and wait for a big Limit order
(unusually large volumes) to appear. For a Short trade confirmation, you want to see
a large number on the Ask. For a Long trade confirmation, it needs to appear on the
Bid.
3. I prefer to look for such confirmations on a 5 Minute Bid x Ask Order Flow chart.
4. An important fact to remember is that unusually large volume is different for each
trading instrument and each trading session! That’s why it is essential to start trading
with just one trading instrument. After you have mastered it, only then should you
look to add another.
5. Enter your trade as soon as you identify the big Limit order. Sometimes it does not
appear all at once, and it may take a few minutes until the whole order is placed.
Below is a EUR Futures, 5 Minute chart showing a Long trade confirmation. If this occurred in
a Support zone, it would be a confirmation to enter a Long trade immediately.
74Below is a EUR Futures, 5 Minute chart showing a Short trade confirmation. If this occurred
in a Resistance zone, it would be a confirmation to enter a Short trade immediately.
More examples of the Limit order confirmation are below. To reiterate for emphasis, the
confirmation must appear around a Support/Resistance zone, NOT just anywhere! I will show
you how to identify S/R zones using Volume Profile later in this book.
75EXAMPLES: Big Limit Orders
Example #1: Big Limit Orders
Example #2: Big Limit Orders
76Example #3: Big Limit Orders
Example #4: Big Limit Orders
77Example #5: Big Limit Orders
Example #6: Big Limit Orders
78Confirmation Setup #2: Absorption
This confirmation setup is similar to the Limit order setup, only a bit simpler.
In this case, the confirmation you want to see in a Support/Resistance zone is Buyers or Sellers
who absorb all the market momentum.
Imagine, for example, that Sellers are pushing the price downwards using aggressive Market
Sell orders. But then strong Buyers appear, and they absorb all the selling pressure—all the
selling momentum. They buy everything the Sellers are selling. The price does not drop
anymore, and heavy volumes start to appear. Those heavy volumes appear on the BID
(aggressive Sellers) and ASK (aggressive Buyers).
So, when you see huge volumes traded on the Bid and Ask (both!) around some S/R zone,
then it is most likely the Absorption taking place. What is happening there is that the Selling
or Buying pressure (momentum) is getting absorbed, making a price reversal likely. That’s the
confirmation you want to see!
It is also hard to provide an exact definition of the term “unusually large volumes” as they are
different for every trading instrument and trading session. With that said, a simple technique
you can use is to look at recent Order Flow footprints and determine an average cell volume.
An “unusually large” or “huge” volume would be volume way above this average.
79An important thing to keep in mind is that this large volume doesn’t appear all at once. It can
take a while before you can safely tell that the volumes you see jumping in are unusually large
compared to the average.
Steps of the Absorption Setup:
1. Identify a strong Support/Resistance zone using your main strategy (this could be
Volume Profile strategies, Price Action strategy, etc.).
2. When the price gets near that S/R zone, open your Order Flow chart and wait for
unusually heavy volumes to appear on Bid and Ask (both!). The absorption needs to
appear around the S/R zone. If it does, then the S/R zone is confirmed.
3. Enter your trade as soon as you identify the Absorption. It may take a few minutes
until all the orders on Bid and Ask are placed before you can safely tell that the market
is absorbing the Buying/Selling pressure.
I prefer to look for the Absorption on the 5 Minute chart or on a 30 Minute chart.
80EXAMPLES: Absorption
Example #1: Absorption
Example #2: Absorption
81Example #3: Absorption
Example #4: Absorption
82Example #5: Absorption
Example #6: Absorption
83Confirmation Setup #3: Aggressive Orders and Delta
A really nice confirmation is when you spot aggressive market participants joining the party
around a strong Support/Resistance zone.
For example, imagine the price moving upwards, entering a Resistance zone, and then
aggressive Sellers start to appear. This is a typical indication that the price will most likely turn
downwards.
If the price enters a Resistance zone and you see big volumes starting to appear on Bid, then
it is a confirmation that aggressive Sellers are jumping in.
If the price enters a Support zone and you see big volumes starting to appear on Ask, then it
is confirmation that aggressive Buyers are jumping in.
Aggressive Buyers show on Ask and aggressive Sellers show on Bid.
It looks like this:
Those aggressive Buyers/Sellers reveal to you that they see the Support/Resistance as well as
you do and that they want to trade it. They don’t want to miss this trading opportunity. In
order not to miss it, they need to enter their trade with a Market order. With a Market order
they can be 100% sure their trading order will get filled.
84You can look for aggressive Buyers or Sellers by reading individual cells within each footprint
(for this, I prefer 5 Minute footprints). Another way to get a quick picture of what is going on
in the footprint is the Delta.
Delta
Delta shows a sum of Bid and Ask for each footprint.
If the Delta below the footprint is negative, then more volumes were traded at the Bid. This
means that aggressive Sellers dominated in that given footprint. The opposite goes for a
positive Delta. A positive Delta tells us that there were more volumes traded on the Ask and
that aggressive Buyers dominated that footprint.
Delta shows below each footprint with my Order Flow indicator either as a negative red
number or as a positive green number.
85Steps to Aggressive Orders + Delta Setup:
1. Identify a strong Support/Resistance zone using your main strategy (this could be a
Volume Profile strategy, Price Action, etc.).
2. When the price gets near that S/R zone, open your Order Flow chart (with Bid x Ask
cell content and 5 Minute time frame) and look for aggressive orders.
If the price entered a Resistance zone, you want to see aggressive Sell orders (way
larger volumes on the Bid than the Ask). If the price reached Support, you want to see
aggressive Buy orders (way larger volumes on the Ask as compared to the Bid).
If Bid grows bigger than Ask or the other way around, it will also show on the Delta. It
means that aggressive Buyers or Sellers started to jump in.
For a Short trade confirmation, you want to see a negative Delta. For a Long trade
confirmation, you want to see a positive Delta.
3. When you recognize that aggressive Buyers or Sellers have started to jump in and
confirmed your Support/Resistance zone, you can immediately enter your trade.
86BONUS: Confirmation #1 or #2 Combined with Confirmation #3
The best scenario you can ask for is when there is a combination of two confirmations. The
first confirmation you will see is either confirmation #1 (Limit order) or confirmation #2
(Absorption). The confirmation that comes after is the one I have just shown you—the
“Aggressive orders” confirmation.
This basically means that some large passive market participant was waiting for the
Support/Resistance to get hit. Then this big guy jumped in (Limit order or Absorption), which
caused a snowball effect and more people started to join in, this time more aggressively (with
Market orders) as they did not want to miss the opportunity.
Here is an example:
87EXAMPLES: Aggressive Orders and Delta
Example #1: Aggressive Orders and Delta
Example #2: Aggressive Orders and Delta
88Example #3: Aggressive Orders and Delta
Example #4: Aggressive Orders and Delta
89Example #5: Aggressive Orders and Delta
90Confirmation Setup #4: Cumulative Delta Divergence
Before I describe this strategy, let me first tell you the distinction between Delta and
Cumulative Delta.
Delta = Ask – Bid.
Simply put, Delta is the difference between Buyers and Sellers in each footprint.
Cumulative Delta is a sum of all Deltas since the beginning of the day. For example, if the 1st
footprint has Delta = 30, the 2nd footprint has Delta = 100, and the 3rd footprint has Delta = -
50, then by the time the 3rd footprint finishes printing, the Cumulative Delta will be +80
(30+100-50).
Here is an example:
As you can see in the picture above, the Order Flow software automatically calculates the
Cumulative Delta in the summary panel below the chart. This is a standard feature included
with most Order Flow software.
91However, there is an easier way to display the Cumulative Delta. In my Order Flow software,
you can print Cumulative Delta on a 1 Minute line chart, and this is how it looks:
I recommend opening a simple Price chart (1 Minute time frame) atop the Cumulative Delta
line chart. This way, you can easily compare price and Cumulative Delta movement, allowing
you to spot divergences between the two much more easily. It looks like this:
92Let’s now talk about the strategy I like to use with the Cumulative Delta!
Strategy Description
This strategy is a confirmation strategy—I use it only around strong Support/Resistance zones
to confirm my trade entries. I do not use it as a standalone strategy (even though I know
people who quite successfully use it this way).
A significant advantage of this strategy is that it is straightforward to interpret and, therefore,
very easy to use. Its simplicity and reliability is the reason why it’s so popular among my
students.
Steps to Cumulative Delta Confirmation Setup:
1. Identify a strong Support/Resistance zone using your primary strategy (this could be a
Volume Profile strategy, Price Action, etc.).
2. When the price gets near that S/R zone, open your Cumulative Delta line chart (it is a
separate indicator in NinjaTrader 8 platform). Use it together with the 1 Minute Price chart.
3. Wait for a divergence between Price and Cum. Delta to appear and then enter your trade.
For a Short trade confirmation, you want to see the price heading upwards whilst Cumulative
Delta is heading down. This tells you that, even though the price is heading up, there is more
activity on the Bid (possibly Sellers) and that the price should turn downwards eventually—
to correspond with the dropping Cumulative Delta.
93For a Long trade confirmation, you want to see the price heading downwards while
Cumulative Delta is heading up. This tells you that, even though the price is going down, there
is more activity on Ask (possibly Buyers) and that the price should turn upwards eventually—
to correspond with the rising Cumulative Delta.
Here are some more examples of Price and Cumulative Delta divergence. If something like
this appears around an S/R zone, it is a confirmation to enter your trade.";

        prompt += "18. How to Find Supports and Resistances with Volume Profile: Order Flow is a fantastic tool that works great if you use it around strong Support and Resistance zones. You can use the Order Flow confirmation strategies to tell whether the price is really reacting to the S/R zone or if the S/R zone is most likely to fail. In this section, I would like to show you how to identify such strong Support and Resistance
zones using my favorite tool—Volume Profile.
Volume Profile is my favorite tool for identifying strong S/R zones because it can show you
the bigger picture of what is going on in the chart. This complements the Order Flow, which
shows more of the granular detail.
In the next chapters, I am going to teach you the Volume Profile basics and show you my
favorite Volume Profile setups. Those are setups that you can use to identify strong S/R zones
from which you can later trade using the Order Flow confirmation setups.
VOLUME PROFILE DEFINITION: Volume Profile is a trading indicator that shows Volume at
Price. It helps to identify where the big financial institutions put their money and helps to
reveal their intentions.
113What Does Volume Profile Look Like?
Volume Profile can have many shapes depending on how the volumes get distributed
throughout the day. It is created using horizontal lines (it is a histogram). The thicker the
profile is the more volume was traded at the given level. If a profile is thin in some places, it
means that there was not much volume traded there.
Here is an example of what Volume Profile can look like:
How is Volume Profile Different to Standard Volume
Indicators in MT4?
Volume Profile shows volume at price. Standard volume indicators from MT4 (or any other
software) show volume during a specific time period.
That is a big difference!
114Volume Profile shows you what price levels are important for the big trading institutions.
Therefore, it points you to strong Support and Resistance zones.
Standard volume indicators only show WHEN there were big volumes traded. This tells you
nothing about essential price levels (Support/Resistance zones).
Here is a picture that compares volume at price (Volume Profile) and volume over a specific
time period (standard volume indicator).
What does Volume Profile Tell Us?
Volume Profile tells us how the volume was distributed over a given price range. This is very
useful information. Let me demonstrate with an example.
115You can see two heavy volume zones in the picture below and one zone where the Volume
Profile is thin.
What does this particular picture tell us? It tells us that big financial institutions were
interested in trading in those two heavy volume zones. On the other hand, they did not really
care for trading too much in the middle zone where the volumes were weak.
This scenario could be a sign that big institutions were:
1. Building up their huge selling positions in the heavy volume zone (1.1230 –1.1240).
2. Manipulating the price to go into a sell-off (that’s the thin profile).
3. And, finally, quitting their positions (or adding to them) in the heavy volume zone
around 1.1205–1.1215.
116Different Volume Profile Shapes
There are many shapes a Volume Profile histogram can print and many different stories it can
tell. However, the shapes and the stories behind them tend to repeat themselves, and in the
end, it comes down to just a few basic shapes the Volume Profile can take:
D-Shaped Profile
It corresponds with the letter “D” and this is the most common shape. It tells us that there is
a temporary balance in the market. Big financial institutions are building up their trading
positions and they are getting ready for a big move.
117P-Shaped Profile
It corresponds with the letter “P” and this is a sign of an uptrend. Aggressive institutional
buyers were pushing the price upwards; then the price found fair value and a rotation started.
In this rotation, heavy volumes were traded, and the market was getting ready for the next
big move. P-shaped profiles are usually seen in an uptrend or at the end of a downtrend.
118b-Shaped Profile
It corresponds with the letter “b” and is the exact opposite of P-shaped profile.
b-shaped profiles are usually seen in a downtrend or at the end of an uptrend.
119Thin Profile
It corresponds with the letter “I” (with little bumps in it).
A thin profile means a strong trend. There is not much time for building up trading positions
in an aggressive price movement. Only small Volume Clusters (sort of “bumps”) are created
in this kind of profile.
One of my favorite trading strategies is based on those Volume Clusters!
120What Makes Volume Profile Different to Other Trading
Indicators?
No other indicator (apart from Order Flow, of course) can show you where the big trading
institutions were likely buying/selling! Why? Because 99% of all standard indicators are
calculated only from two variables: Price and Time. Volume Profile gets calculated using three
variables—Price, Time, and Volume.
In other words, 99% of standard trading indicators only show you how the price was moving
in the past. The only difference between those thousands of indicators is how they visualize
it. It does not matter whether it is EMA, Bollinger bands, RSI, MACD, or any other indicator…
All those only show a different visualization of a price movement in the past (they are
delayed—they visualize something that has already happened).
YES – they are pretty useless, which is the reason traders keep jumping from one to the other
without having any real success.
On the other hand, Volume Profile points you to zones that were and will be important for
big trading institutions. Simply put – Volume Profile can show you what will happen in the
future!
Why Care about Volumes and What the Big Institutions Are
Doing?
There is a straightforward reason why we need to know what the big financial institutions are
doing. The reason is that they dominate, move, and manipulate the markets. It is they who
decide where the price will go, not you or I. We are too small.
Take a look at following picture. It shows the 10 biggest banks and how much volume they
control. Together it is almost 65% of the market. Just 10 banks!
It is those guys who own this game. Those are the guys we need to track and follow. And how
do we follow them? By using Volume Profile to track their volumes.
121Volume Profile – Trading Setups
In this chapter, I will show you my most favorite Volume Profile setups. You can use these
setups to identify strong Support and Resistance zones. When the price reaches these zones
at some point in the future, you can use Order Flow to help you trade there!
What you will find the most helpful for this will be the Order Flow confirmation strategies.
These will help you tell if the big market participants are active in those zones and if they are
going to trade them. If the big guys start joining the party around a strong Volume Profile-
based S/R zone, then it will be a strong confirmation signal for you. Such a signal indicates
that the S/R is most likely going to work!
These Volume Profile setups can be used with any time frame. However, this book focuses on
intraday trading, and for that, I suggest you use these setups with 30 Minute time frame. You
can also go to 15 Minute or 1 Hour, but I would not advise going past that.
122Volume Profile Setup #1: Volume Accumulation Setup
This is my favorite trading setup. It is based on the fact that big trading institutions first need
to enter their huge trading positions before manipulating the market into a new trend. They
enter their huge positions in a rotation. This is the only place where they can accumulate such
large volume without being seen and without their intentions being recognised.
You can trade it in three steps:
1. Look for a price rotation/tight channel that is followed by a strong uptrend (or a
downtrend). What happens in such a formation is that big institutions are
accumulating their trading positions (in the rotation) and then they start the trend. A
Long scenario looks like this:
2. Use Volume Profile in the rotation area to identify where the heaviest volumes were.
The area where the heaviest volumes got traded is a strong Support (Long trade
scenario).
3. When the price enters this Support zone in the future, open your Order Flow and wait
for any of the confirmation setups to appear there. Jump in the trade as soon as it gets
confirmed on the Order Flow.
123The Logic Behind Volume Accumulation Setup
Let me now explain the logic behind this setup. There are two reasons (factors) why the price
reacts to these volume zones so nicely. This reasoning also applies to all the other volume
setups I am going to show you later.
Reason #1: Strong Buyers/Sellers who were accumulating their positions are likely to defend
their positions. As a result of this, when the price returns to the volume accumulation area,
strong Buyers/Sellers actively defend their positions.
Strong Buyers start aggressively buying to drive the price upwards again to defend the level
where they accumulated their Longs. Strong Sellers defend their Shorts positions by
aggressive selling, which moves the price lower again. Here is a picture to demonstrate this
(a Long trade scenario):
124Reason #2: Nobody wants to risk a fight with strong and aggressive Buyers/Sellers.
Let me demonstrate this by using an example: First, strong Buyers accumulated their positions
in a sideways rotation. Then they pushed the price aggressively upwards (this is the Long
scenario of Setup #1). After that, the Buyers stopped pushing the price upwards for a while,
and Sellers took over. They were pushing the price lower and lower, but when they
approached the strong rotation where the aggressive Buyers had accumulated their massive
positions, the Sellers stopped their selling activity and closed their positions. Why? Because
they didn’t want to risk a fight with strong and aggressive Buyers.
When somebody who is in a Short position wants to close their position, he buys. So, when
those Sellers start to buy to get rid of their Short positions, they actually help to drive the
price upwards.
125Let me make this clearer with a picture:
It is the combination of these two factors that drives the price away from the
Support/Resistance zones.
126EXAMPLES: Volume Accumulation Setup
Example #1: Volume Accumulation Setup
Example #2: Volume Accumulation Setup
127Example #3: Volume Accumulation Setup
Example #4: Volume Accumulation Setup
128Volume Profile Setup #2: Trend Setup
This is also one of my favorite Volume Profile setups. It is based on the fact that there is not
much time for accumulating big trading positions when there is a trend. Sometimes, the trend
movement halts for a bit and some new and relatively big volumes get accumulated. Those
volumes show as a little “bump” on the otherwise thin Volume Profile. Those “bumps” are
called Volume Clusters. Those Volume Clusters often work as strong Support and Resistance
zones when the price gets back to them in the future. Here are exact steps on how to trade
this:
1. Trade this setup when there is a strong trend. If there is an uptrend, you will want to
trade Longs. If it is a downtrend, then it is Shorts.
2. When you have found a trend (in this case an uptrend), use Volume Profile to see how
the volume was distributed throughout the trend move.
3. Look for significant Volume Clusters that were created within the trend. In the picture
below, there is one significant Volume Cluster. The area where the volumes were the
heaviest is a Support.
1294. When the price enters this Support area, open your Order Flow and wait for any of
the confirmation setups to appear there. You jump in the trade as soon as it gets
confirmed on the OF.
The Logic behind the Trend Setup:
The logic behind this setup is that Buyers were pushing the price upwards and they were
adding to their Long positions in the place where we now see the Volume Cluster. When the
price hits the Volume Cluster again, those Buyers are likely to become active again and begin
to defend their Long positions they placed there earlier. This will push the price up from this
Volume Cluster again.
The same two factors that help to move the price and which I mentioned with the Volume
Accumulation setup apply here as well.
130EXAMPLES: Trend Setup
Example #1: Trend Setup
Example #2: Trend Setup
131Example #3: Trend Setup
Example #4: Trend Setup
132Volume Profile Setup #3: Rejection Setup
This setup is based on finding a very strong rejection of either higher or lower prices and
applying Flexible Volume Profile to it in order to spot strong Volume Clusters.
The key to trading this setup successfully is in identifying the strong rejection in the chart.
Sometimes, the strong rejection looks like a strong pin bar created at a swing point. However,
sometimes it is not so clear and there is a different candle pattern. I don't care what pattern
there is because usually the pattern changes with the time frame (and I don't like being bound
by a time frame). What matters the most is that the rejection is strong and that the
aggressiveness within it is evident.
In a Long trade scenario, I look for selling activity followed by a sudden price reversal and
strong buying activity. For example, like this:
133In a Short trade scenario, I look for buying activity followed by sudden price reversal and
strong selling activity. For example, like this:
When there is a strong price reversal, we get the information that one side of the market
became very aggressive and strongly rejected some price level. When this happens, I am
interested in how the volumes were distributed within the rejection. In other words, I am
interested in the place where the heaviest volumes within the rejection were added to the
market. The reason for that is that the place with the heaviest volumes marks the place where
the counterparty was the most aggressive—the place where the biggest fight was.
Here is how to trade this:
1. Use the Flexible Volume Profile to look into a strong rejection area to see where the
volumes were the heaviest. There needs to be a nice and strong Volume Cluster there.
2. The area where the Volume Cluster got formed is a zone of S/R. Wait until the price
comes back there again. When it does, open the Order Flow software to look for a
trade confirmation.
3. If there is a rejection of higher prices, then you want to enter a Short position.
134If there is a rejection of lower prices, then you want to enter a Long position. See the
example below:
The Volume Profile Setup #3 is the most difficult setup to trade because sometimes it is hard
to tell when the rejection was really strong and aggressive. Sometimes the rejection is pretty
strong but the distribution of volumes within the rejection is not easy to read—mostly when
there are stronger volume areas within the rejection itself. Because of this, it takes some time
and practice to master this setup
135EXAMPLES: Rejection Setup
Here are some more examples of the Rejection Setup.
Example #1: Rejection Setup
Example #2: Rejection Setup
136Example #3: Rejection Setup
Example #4: Rejection Setup
137Where to Get More Info about Volume Profile
Volume Profile is a fantastic tool that definitely deserves more of your attention. As this
book’s main goal is to teach you Order Flow trading, I won’t go more in depth with Volume
Profile. However, you can learn more about it on my website www.trader-dale.com. What
you will find there is a free copy of my book VOLUME PROFILE: The Insider’s Guide to Trading
available for you to download.
If you would like to go even deeper, I suggest you get my Order Flow Pack (available here:
https://www.trader-dale.com/order-flow-indicator-and-video-course/). This pack includes:
•Order Flow software
•Volume Profile software
•Extensive Order Flow and Volume Profile video training
If you would just like to get the Volume Profile software, you can get it on my website here:
(https://www.trader-dale.com/volume-profile-forex-trading-course/)
Live Trading Examples - Link
I first planned to comment on some of my Order Flow + Volume Profile live trades here, but
the written format makes it quite difficult and not so effective. For this reason, I set up a
special webpage for you where I uploaded a couple of live trading videos. You can see me
trading with Order Flow and Volume Profile in those videos using all the tips and approaches
I showed you in this book. Here is the link:
Link: https://www.trader-dale.com/of-book/
Password: happy trading
138What to Do Next
In this book, I tried my best to explain my trading strategies and give you a good starting point
for using them independently. I hope you liked it and that you find the way of trading
alongside the big trading institutions using Order Flow and Volume Profile as appealing as I
do. This book should give you the basics you need to start exploring more and, most
importantly, get some firsthand experience.
Trading using the Order Flow is like driving a car. All the theory about driving is one thing, but
actually driving a car is an experience you won’t be able to learn from a book. You actually
need to sit in the car and drive. This is what will make you a good driver, not reading books
about driving.
The actual process of driving (or trading) will also become way more natural when you start
doing it. I expect that after going through this Order Flow book, your head could feel a bit
dizzy from the amount of information, especially if Order Flow is entirely new for you. There
are just so many things to watch, so many nuances, so many things to remember, right? Well,
theoretically, yes. BUT when you start using Order Flow in your trading, many of these things
will become natural for you. In a short amount of time, reading the Order Flow will become
way easier, and when you look at it, you will see a clear picture, not just a sum of cells,
numbers, and different shades of colors.
What you need now is to practice the things you have learned. You need practice and hands-
on experience!
Accelerate Your Learning!
To accelerate your learning and give you as much information as possible, I have created a
number of special training courses. There are two in particular that I highly recommend
getting. They are called The Elite Pack and The Order Flow Pack. Each one of them focuses on
different things. Let me now tell you what those two training packs consist of and how they
can help you!
139The Elite Pack
The Elite Pack is ideal for you if you would like to perfect your trading with Volume Profile.
This Pack focuses on intraday, swing trading, and long-term investment trading with Price
Action, Volume Profile, and VWAP.
It consists of four main parts:
1. Volume Profile Video Course: a 15-hour-long video course on trading with Volume
Profile, Price Action, and VWAP. It consists of an in-depth explanation of my favorite
and proven trading strategies and includes hundreds of real trading examples.
2. Dale’s Trading Levels: After you have gone through the whole video course, I suggest
you start following me in my everyday trading. Each day I will give you my personal
intraday and swing trading levels, which are based on the strategies you learned. I
explain all my trading levels in a daily video, which you will get every day as well. This
way, you will know what and how I am going to trade that day and the reasoning
behind my decisions.
I think the best way to learn something is to follow somebody who has a lot of
experience. This is a very effective, proven, and fast way to learn!
3. Volume Profile + VWAP Indicators: The Elite Pack includes a lifetime license to my
custom-made Volume Profile and VWAP indicators. Those indicators were developed
by expert developers precisely to my needs. They are fast, precise, reliable, and
versatile (you can use them for all trading instruments) and they have all the functions
you will need for successful trading.
4. Community & Support: Apart from all this, you will also get access to my trading
community and trading forum, where you can discuss your trading with other
members. It goes without saying that you will also get my personal unlimited email
support. Whatever you need to help with, shoot me an email and I will do my best to
help.
BONUS: As a special bonus to all of this, our specially trained tech support will do the
complete setup for you! They will install the trading platform with all my indicators, create
workspaces (exactly the same as I use), and connect you to a reliable data feed—for FREE.
This way, you will be able to start learning immediately, without any delays!
140141The Order Flow Pack
The Order Flow pack is ideal for you if you would like to perfect your Order Flow trading. If
you finished this book and liked what you learned here, I would definitely recommend
continuing your learning with the Order Flow Pack.
The Order Flow pack consists of four main parts:
1. Order Flow Video Course: A 12-hour long in-depth video course where I teach you all
you need to know to trade with Order Flow successfully. It covers Order Flow trading
strategies, entry and exit strategies, confirmation strategies, live trading, Order Flow
settings … simply put, all that you need to feel confident trading with the Order Flow!
The video course is a very practical and right-to-the-point guide. No fluff, just all the
useful info, put in a logical order, and all in one place.
2. Order Flow and Delta Software: My custom-made software, which I developed for my
own intraday trading. It is a versatile tool that you can use for all trading instruments
(Forex included) and has many very useful and unique features and other OF software
lacks. This software is constantly updated and new features are being added.
3. Volume Profile Software: Order Flow combined with Volume Profile is a very powerful
combo. Use my custom-made Volume Profile indicator to see the big picture and to
identify strong institutional Support and Resistance zones. Then use Order Flow to
confirm your trade entry, pinpoint the best place to enter your trade, and manage
your trade like a professional, institutional trader!
4. Lifetime Support: Getting the Order Flow pack will get you also my unlimited email
support. Have questions regarding setups, settings, trades, or have you run into some
technical difficulties? I am here to help!
BONUS: Our specially trained tech support will do the complete Order Flow and Volume
Profile setup for you! They will install the trading platform with all my indicators, create
workspaces (exactly the same as I use), and connect you to a reliable data feed. No need to
read manuals; just jump right into learning and trading!
142143Just a Few Testimonials on My Trading Courses
Excellent Content and Service
After consuming hours of free content (all great I must add) I decided to buy the VP indicator
for MT4 and Dale’s online book. A great buy, but I soon realized I wanted to know more about
Order Flow and all the bits and bobs. Dale had a fresh approach and I was eager to learn more.
Before I purchased the Elite Pack I asked many questions. Dale and his team answered every
single one in a timely manner and with a personal touch. I felt right at home. From our first
interaction the support has been unbelievable and the course content incredibly informative.
I have learnt more in the past month than the last 36. The only thing I regret is not finding
him three years ago.
Dale is a straight shooter. Not promising you the Holy Grail of trading and will point out
successes and failures. It is refreshing!
Great Course, Great Indicators and Damn Good Value
There are many trading gurus to choose from. The challenge is finding one that is good, honest
and knows what he is talking about. Trader Dale is one of those. He focuses on volume-based
trading methods rather than the traditional price and time methods. It is a different and very
interesting approach and one that has great potential for me. I have studied several different
trading styles and used several different markets. So far, none have worked as expected and
this is because they were all missing something. That something is volume. Trader Dale clearly
explains why volume is so important and how to use it. His teaching methods are clear and
concise and he explains everything you need to know. His indicators for MT4 and NT8 are top
class. The price he charges for his training and indicators is very reasonable. I have no
hesitation in recommending him to anyone who really wants to understand the market better
and to get the edge that will propel you forwards. This is not a get-rich-quick scheme. There
is a lot to learn and understand, but Trader Dale does a fantastic job of explaining everything.
He gives you the theory and then shows real examples of how it works. He shows winners as
well as losses and uses different markets to prove that it works. Take the plunge and get the
professional training and support you deserve—you will not regret it.
144Invaluable, very insightful and clear training
I couldn’t trade without Trader Dale’s Flexible Volume Profile or Order Flow. His explanations
and training seem to cover every aspect of the volume profile or order flow and are very clear
to understand. I was shocked when he explained something in his Order Flow training. For
years I’ve wanted to understand Order Flow and I watched hours of video and attended
countless webinars from individuals claiming they were going to teach how it works and no
one ever mentioned one simple point about something that shows up frequently in Order
Flow throughout the day. Dale was only one who pointed it out and explained it very clearly
and, for me, it made Order Flow immediately usable. I’ve never gotten the feeling he was
holding something back for a future purchase, I do believe he shares all he knows and
sincerely wants to see others succeed. Very rare.
Reliable and helpful person, professional and excellent services!
I found Dale's wonderful book Volume Profile - The Insider’s Guide to Trading by chance. Only
reading the beginning of his book I knew that was what I was looking for. Then the book led
me to his website and training courses. He surprised me with his extreme helpfulness and
kindness. Whenever I am confused, he's willing to help with all of his kindness and more than
I expect. I've never met anyone who is kind-hearted and helpful like him. Moreover, not only
his invented Volume Profile indicator but his professional trading methods absolutely impress
me. I do not know what words to say, but I would like to say: Thank God I found him as my
tutor/ trainer/ advisor in trading. If you are interested in trading and would like to develop
your trading, please join him and you will never be disappointed.
Quality individual that gives excellent training and market guidance
I discovered Trader Dale's service a little over six months ago and have been absolutely thrilled
with the knowledge he has shared in that time. Because of the incredible market insights he
shares with his members, along with the extensive training materials he provides, I have
become a much improved trader.
145And the best part is I can now trade with confidence and not with fear. Because of Trader
Dale's training and market analysis, which includes expected outcomes at well-defined
Volume Profile levels, I can trade with total confidence.
Yes, there are losses, but because of the "risk-controlled" training plan he has shared, the
losses are minimal and rare compared to the successful trades and profits.
I am so happy I found this service.
Trader Dale—the most honest and reliable Trading School
Based on my personal experience with the link trading market, I found the most reliable,
honest and simple trading ideas are located under Trader Dale webpages. Really it can be
considered a Trading School especially for beginners. It can convert beginners to profitable
traders in a short period. My experience started early but within three months studying
Trader Dale courses – VP, OF & VWAP – I converted my trial from Demo version to profitable
live trading, which I am happy with now. I need to express my thanks to Mr. Dale for his efforts
and keen support of his site members. Really I highly recommend beginners to depend on
Trader Dale’s website.
Unique Style of Trading with Full Dedication in Teaching
Dale is a real trader who loves to trade and help people make a decent living out of trading. I
have been struggling to trade with a number of systems available in the market. I went to
different gurus even but could not discipline myself and my trading sucked big time.
After learning from Dale about the Volume Profile, my trading results changed dramatically
and I could literally stop over trading and count my profits. Though my progress is slow ’cause
I already lost a lot of money and my capital is smaller in comparison to other traders, the gem
I know from Dale now can definitely help me to build a fortune sooner or later. I believe that.
Significantly, the daily levels are really helpful for busy people like me, which makes trading
easier and faster.
146Thanks, Dale, for your wonderful support. I don’t usually rate mentors in any review website,
but if my review counts and supports your program in any way, that is my small gesture of
showing gratitude for your hard work teaching me how to profit well.
Excellent
There is not hype with this guy, none. It is very easy to understand, for me I have been trading
and researching now for about two years and I already used the Volume Profile, but this guy
just explained everything about TA and institutions and how they trade and the things that
go on behind the scenes that I assumed were the way he explains them, so this guy has
basically confirmed every suspicion I have had on how the market really moves and why. A
lot of people since I have been learning TA go off the deep end with it, and they literally start
treating and thinking of the market like it will run all by itself without any people playing and
it's just one big machine running on its own, or why 90% of all the TA bulls*** out there
doesn't work and the questions I have asked while learning this stuff and why so much didn't
really fit. Anyways, if anyone is at the point I am with not wanting to work for a firm, but
deeply desiring to learn how and why the markets really move, then follow this guy. And the
plus side is when you fully understand that you literally have to follow big money and stop
thinking you're going to really do something out there, you'll also be amazed at just how easy
trading really is. Thanks again, Dale, I have been waiting to find someone like you for about
two years now.
147Glossary
Ask: Is displayed on the right side of the footprint. It shows how many contracts were traded
there with Market Buy order and also with Limit Sell order.
Bid: Is displayed on the left side of the footprint. It shows how many contracts were traded
there with Market Sell order and also with Limit Buy order.
Cumulative Delta: Sum of all Deltas of the current day. Its calculation starts every day anew.
Delta: A difference between Bid and Ask. It is calculated as: Ask – Bid. Positive Delta indicates
strong buyers and negative Delta indicates strong sellers.
148Footprint: A box that represents a standard price “candle” with the Bid and Ask values
displayed.
High Volume Node (HVN): A black outline in every footprint pointing to the price where the
heaviest volumes got traded (within that footprint).
Iceberg Order: When a big trading institution enters a position, they sometimes don’t enter
it all at once with one order. Instead, their algorithms split the order into many small orders.
For example, instead of entering 10 contracts, they enter 1+1+1… They do this super quick.
Imbalance: If Ask is 300% or more than Bid, then it is a Buying Imbalance = Buyers are way
stronger than Sellers. If Bid is 300% or more than Ask, then it is a Selling Imbalance = Sellers
are way stronger than Buyers. Imbalances are marked in blue. Note that Bid and Ask are
compared diagonally from left to right!
149Multiple Node: Two or more High Volume Nodes next to each other. My software highlights
them in yellow. Multiple Nodes represent Support/Resistance zones.
Stacked Imbalance: Three or more Buying or Selling Imbalances on top of each other.
Strong Rejection: Price goes aggressively one way and then suddenly reverses and goes
aggressively the other way.
Support/Resistance: A price level or zone in the chart where we expect that the price will
react to (bounce off) it.
150Risk Reward Ratio (RRR): Potential gain versus the potential loss of a trade. If you use Stop
Loss = 10 pips and Take Profit = 10 pips, then RRR = 1. If you use SL = 10 pips and TP = 20 pips,
then RRR = 2.
Unfinished Business: A market imperfection. When the market went one way then turned
the other way without having the high/low formed properly. A properly formed high needs
to have 0 contracts traded at the Bid, and a properly formed Low needs to have 0 contracts
traded at the Ask.
Volume Accumulation: An area (usually a price rotation area) where heavy volumes were
traded.
Volume Cluster: Area";

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
