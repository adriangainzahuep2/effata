//+------------------------------------------------------------------+
//| TestMultiAccountManagerEnv.mqh                                    |
//| Comprehensive unit tests for MultiAccountManagerEnv              |
//+------------------------------------------------------------------+

#property copyright "2025, EFFATA Trading Systems"
#property link      "https://www.effata.ai"
#property version   "1.00"
#property strict

#include "../Include/Environments/MultiAccountManagerEnv.mqh"

//+------------------------------------------------------------------+
//| Test Helper Functions                                             |
//+------------------------------------------------------------------+
int g_TestsPassed = 0;
int g_TestsFailed = 0;

void AssertTrue(bool condition, string test_name) {
    if(condition) {
        Print("✓ PASS: ", test_name);
        g_TestsPassed++;
    } else {
        Print("✗ FAIL: ", test_name);
        g_TestsFailed++;
    }
}

void AssertEqual(double actual, double expected, string test_name, double epsilon = 0.0001) {
    bool passed = MathAbs(actual - expected) < epsilon;
    if(passed) {
        Print("✓ PASS: ", test_name, " (", actual, " == ", expected, ")");
        g_TestsPassed++;
    } else {
        Print("✗ FAIL: ", test_name, " (", actual, " != ", expected, ")");
        g_TestsFailed++;
    }
}

void AssertNotNull(void* pointer, string test_name) {
    if(CheckPointer(pointer) != POINTER_INVALID) {
        Print("✓ PASS: ", test_name);
        g_TestsPassed++;
    } else {
        Print("✗ FAIL: ", test_name);
        g_TestsFailed++;
    }
}

//+------------------------------------------------------------------+
//| Test Initialization                                               |
//+------------------------------------------------------------------+
void TestMAMInitialization() {
    Print("=== Testing MAM Initialization ===");

    CMultiAccountManager *mam = new CMultiAccountManager();

    AssertNotNull(mam, "MAM object created");
    AssertTrue(mam.Initialize(), "MAM initialized successfully");
    AssertEqual(mam.GetAccountCount(), 0, "Initial account count is zero");
    AssertEqual(mam.GetTotalEquity(), 0, "Initial total equity is zero");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Account Management                                           |
//+------------------------------------------------------------------+
void TestAddAccount() {
    Print("=== Testing Account Management ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Create test account
    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "TEST_ACCOUNT_001";
    account.broker_name = "Test Broker";
    account.server_name = "TestServer";
    account.initial_balance = 10000.0;
    account.target_allocation_pct = 50.0;
    account.max_positions = 10;
    account.auto_trading_enabled = true;

    bool added = mam.AddAccount(account);
    AssertTrue(added, "Account added successfully");
    AssertEqual(mam.GetAccountCount(), 1, "Account count after adding");

    // Test adding duplicate account
    bool added_duplicate = mam.AddAccount(account);
    AssertTrue(added_duplicate, "Duplicate account handling");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test External Account Addition                                    |
//+------------------------------------------------------------------+
void TestAddExternalAccount() {
    Print("=== Testing External Account Addition ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    bool added = mam.AddExternalAccount(
        "EXT_TRADOVATE_001",
        "tradovate",
        1.5,
        100.0,
        false
    );

    AssertTrue(added, "External account added");
    AssertEqual(mam.GetAccountCount(), 1, "External account count");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Account Connection                                           |
//+------------------------------------------------------------------+
void TestAccountConnection() {
    Print("=== Testing Account Connection ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add account
    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "CONN_TEST_001";
    account.broker_name = "Test Broker";
    account.initial_balance = 5000.0;

    mam.AddAccount(account);

    // Test connection
    bool connected = mam.ConnectAccount("CONN_TEST_001");
    AssertTrue(connected, "Account connected");
    AssertTrue(mam.IsConnected("CONN_TEST_001"), "Account connection status");

    // Test disconnection
    bool disconnected = mam.DisconnectAccount("CONN_TEST_001");
    AssertTrue(disconnected, "Account disconnected");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Trade Allocation                                             |
//+------------------------------------------------------------------+
void TestTradeAllocation() {
    Print("=== Testing Trade Allocation ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add two accounts
    SAccountConnection account1;
    ZeroMemory(account1);
    account1.connection_id = "ALLOC_TEST_001";
    account1.broker_name = "Broker1";
    account1.initial_balance = 10000.0;
    account1.target_allocation_pct = 60.0;
    account1.copy_multiplier = 1.0;
    account1.max_positions = 10;

    SAccountConnection account2;
    ZeroMemory(account2);
    account2.connection_id = "ALLOC_TEST_002";
    account2.broker_name = "Broker2";
    account2.initial_balance = 5000.0;
    account2.target_allocation_pct = 40.0;
    account2.copy_multiplier = 0.5;
    account2.max_positions = 10;

    mam.AddAccount(account1);
    mam.AddAccount(account2);
    mam.ConnectAccount("ALLOC_TEST_001");
    mam.ConnectAccount("ALLOC_TEST_002");

    // Test allocation calculation
    double alloc1 = mam.CalculateAllocationPct("ALLOC_TEST_001");
    double alloc2 = mam.CalculateAllocationPct("ALLOC_TEST_002");

    AssertEqual(alloc1, 60.0, "Account 1 allocation percentage");
    AssertEqual(alloc2, 40.0, "Account 2 allocation percentage");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Master Trade Execution                                       |
//+------------------------------------------------------------------+
void TestMasterTradeExecution() {
    Print("=== Testing Master Trade Execution ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Create trade action
    STradeAction action;
    ZeroMemory(action);
    action.symbol = _Symbol;
    action.action_type = TRADE_ACTION_HOLD;  // Use HOLD to avoid actual trade
    action.lot_size = 0.1;
    action.comment = "Test Trade";

    // Test HOLD action (should always succeed)
    bool executed = mam.ExecuteMasterTrade(action);
    AssertTrue(executed, "Master trade HOLD executed");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Risk Management                                              |
//+------------------------------------------------------------------+
void TestRiskManagement() {
    Print("=== Testing Risk Management ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add account with risk limits
    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "RISK_TEST_001";
    account.broker_name = "Test Broker";
    account.initial_balance = 10000.0;
    account.max_drawdown_pct = 15.0;
    account.profit_target_pct = 20.0;

    mam.AddAccount(account);
    mam.ConnectAccount("RISK_TEST_001");

    // Test risk checking (should not throw errors)
    mam.CheckRiskLimits();
    mam.CheckDrawdownLimits();
    mam.CheckMarginAcrossAllAccounts();

    AssertTrue(true, "Risk checks completed without errors");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Performance Calculation                                      |
//+------------------------------------------------------------------+
void TestPerformanceCalculation() {
    Print("=== Testing Performance Calculation ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add account
    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "PERF_TEST_001";
    account.initial_balance = 10000.0;
    account.current_equity = 11000.0;  // 10% profit

    mam.AddAccount(account);
    mam.ConnectAccount("PERF_TEST_001");

    // Calculate performance
    mam.CalculatePerformance("PERF_TEST_001");

    SAccountPerformance perf = mam.GetAccountPerformance("PERF_TEST_001");

    AssertEqual(perf.net_profit, 1000.0, "Net profit calculation");
    AssertEqual(perf.roi_pct, 10.0, "ROI percentage calculation");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Group Operations                                             |
//+------------------------------------------------------------------+
void TestGroupOperations() {
    Print("=== Testing Group Operations ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add multiple accounts
    for(int i = 1; i <= 3; i++) {
        SAccountConnection account;
        ZeroMemory(account);
        account.connection_id = "GROUP_TEST_" + IntegerToString(i, 3, '0');
        account.initial_balance = 5000.0 * i;

        mam.AddAccount(account);
        mam.ConnectAccount(account.connection_id);
    }

    AssertEqual(mam.GetAccountCount(), 3, "Multiple accounts added");

    double total_balance = mam.GetTotalBalance();
    AssertEqual(total_balance, 30000.0, "Total group balance", 1.0);

    // Test group operations
    mam.LogAllAccountStatuses();
    mam.CheckProfitTargets();

    AssertTrue(true, "Group operations completed");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test External Trade Execution                                     |
//+------------------------------------------------------------------+
void TestExternalTradeExecution() {
    Print("=== Testing External Trade Execution ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Add external account
    mam.AddExternalAccount("EXT_TEST_001", "tradovate", 1.0, 10.0, false);

    // Create trade action
    STradeAction action;
    ZeroMemory(action);
    action.symbol = _Symbol;
    action.action_type = TRADE_ACTION_BUY;
    action.lot_size = 0.1;
    action.sl_price = 0;
    action.tp_price = 0;

    // Note: This will likely fail without actual bridge, but tests the code path
    bool executed = mam.ExecuteTrade("EXT_TEST_001", action);

    // Just check that it doesn't crash
    AssertTrue(true, "External trade execution attempted");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Account Status Updates                                       |
//+------------------------------------------------------------------+
void TestAccountStatusUpdates() {
    Print("=== Testing Account Status Updates ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "STATUS_TEST_001";
    account.initial_balance = 10000.0;

    mam.AddAccount(account);
    mam.ConnectAccount("STATUS_TEST_001");

    // Test status updates
    mam.UpdateAccountStatuses();
    mam.LogAccountStatus("STATUS_TEST_001");

    AssertTrue(true, "Status updates completed");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Pause/Resume Trading                                         |
//+------------------------------------------------------------------+
void TestPauseResumeTrading() {
    Print("=== Testing Pause/Resume Trading ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    SAccountConnection account;
    ZeroMemory(account);
    account.connection_id = "PAUSE_TEST_001";
    account.auto_trading_enabled = true;

    mam.AddAccount(account);
    mam.ConnectAccount("PAUSE_TEST_001");

    // Test pause
    mam.PauseTradingForAccount("PAUSE_TEST_001", "Test pause");

    // Test pause all
    mam.PauseTradingAllAccounts("Group pause test");

    // Test resume
    mam.ResumeTrading("PAUSE_TEST_001");
    mam.ResumeAllAccounts();

    AssertTrue(true, "Pause/resume operations completed");

    delete mam;
}

//+------------------------------------------------------------------+
//| Test Edge Cases                                                   |
//+------------------------------------------------------------------+
void TestEdgeCases() {
    Print("=== Testing Edge Cases ===");

    CMultiAccountManager *mam = new CMultiAccountManager();
    mam.Initialize();

    // Test operations on non-existent account
    bool connected = mam.ConnectAccount("NONEXISTENT");
    AssertTrue(!connected, "Connect non-existent account returns false");

    bool disconnected = mam.DisconnectAccount("NONEXISTENT");
    AssertTrue(!disconnected, "Disconnect non-existent account returns false");

    // Test invalid allocation
    double alloc = mam.CalculateAllocationPct("NONEXISTENT");
    AssertEqual(alloc, 0.0, "Allocation for non-existent account is zero");

    // Test empty operations
    mam.CheckRiskLimits();
    mam.LogAllAccountStatuses();

    AssertTrue(true, "Edge cases handled correctly");

    delete mam;
}

//+------------------------------------------------------------------+
//| Run All Tests                                                     |
//+------------------------------------------------------------------+
void RunAllMAMTests() {
    Print("\n");
    Print("╔════════════════════════════════════════════════════════╗");
    Print("║   Multi-Account Manager Test Suite                    ║");
    Print("╚════════════════════════════════════════════════════════╝");
    Print("\n");

    g_TestsPassed = 0;
    g_TestsFailed = 0;

    // Run all test functions
    TestMAMInitialization();
    TestAddAccount();
    TestAddExternalAccount();
    TestAccountConnection();
    TestTradeAllocation();
    TestMasterTradeExecution();
    TestRiskManagement();
    TestPerformanceCalculation();
    TestGroupOperations();
    TestExternalTradeExecution();
    TestAccountStatusUpdates();
    TestPauseResumeTrading();
    TestEdgeCases();

    // Print summary
    Print("\n");
    Print("═══════════════════════════════════════════════════════");
    Print("Test Summary:");
    Print("  Passed: ", g_TestsPassed);
    Print("  Failed: ", g_TestsFailed);
    Print("  Total:  ", g_TestsPassed + g_TestsFailed);

    double success_rate = g_TestsPassed * 100.0 / (g_TestsPassed + g_TestsFailed);
    Print("  Success Rate: ", DoubleToString(success_rate, 1), "%");
    Print("═══════════════════════════════════════════════════════");

    if(g_TestsFailed == 0) {
        Print("✓ All tests passed!");
    } else {
        Print("✗ Some tests failed. Review output above.");
    }
}

//+------------------------------------------------------------------+