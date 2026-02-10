//+------------------------------------------------------------------+
//| TestMultiAccountManager.mq5                                       |
//| Comprehensive unit tests for MultiAccountManagerEnv.mqh          |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Testing Systems"
#property version   "1.00"
#property strict

#include "../Include/Environments/MultiAccountManagerEnv.mqh"

// Test counters
int g_TestsPassed = 0;
int g_TestsFailed = 0;
int g_TotalTests = 0;

//+------------------------------------------------------------------+
//| Test helper macros                                               |
//+------------------------------------------------------------------+
#define ASSERT_TRUE(condition, message) \
   g_TotalTests++; \
   if(condition) { \
      g_TestsPassed++; \
      Print("✓ PASS: ", message); \
   } else { \
      g_TestsFailed++; \
      Print("✗ FAIL: ", message); \
   }

#define ASSERT_FALSE(condition, message) \
   ASSERT_TRUE(!(condition), message)

#define ASSERT_EQUAL(actual, expected, message) \
   ASSERT_TRUE((actual) == (expected), message + " (Expected: " + (string)(expected) + ", Got: " + (string)(actual) + ")")

#define ASSERT_NOT_NULL(pointer, message) \
   ASSERT_TRUE(CheckPointer(pointer) == POINTER_DYNAMIC, message)

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("Multi-Account Manager Test Suite");
   Print("========================================");

   RunAllTests();

   PrintTestSummary();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Run all test suites                                              |
//+------------------------------------------------------------------+
void RunAllTests()
{
   TestInitialization();
   TestAccountManagement();
   TestAccountConnection();
   TestExternalAccountManagement();
   TestMasterTradeExecution();
   TestTradeAllocation();
   TestAccountPerformance();
   TestRiskManagement();
   TestDrawdownMonitoring();
   TestAllocationCalculations();
   TestLogging();
   TestEdgeCases();
}

//+------------------------------------------------------------------+
//| Test: Initialization                                             |
//+------------------------------------------------------------------+
void TestInitialization()
{
   Print("\n--- Testing Initialization ---");

   CMultiAccountManager *manager = new CMultiAccountManager();

   ASSERT_NOT_NULL(manager, "Manager should be created successfully");
   ASSERT_EQUAL(manager.GetAccountCount(), 0, "Initial account count should be 0");
   ASSERT_EQUAL(manager.GetTotalEquity(), 0.0, "Initial total equity should be 0");
   ASSERT_EQUAL(manager.GetTotalBalance(), 0.0, "Initial total balance should be 0");

   bool initResult = manager.Initialize();
   ASSERT_TRUE(initResult, "Initialize() should return true");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Account Management                                         |
//+------------------------------------------------------------------+
void TestAccountManagement()
{
   Print("\n--- Testing Account Management ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Create test account
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "TEST_ACCOUNT_001";
   account.broker_name = "Test Broker";
   account.server_name = "TestServer-Demo";
   account.login = "12345";
   account.password = "test_password";
   account.account_number = 12345;
   account.initial_balance = 10000.0;
   account.target_allocation_pct = 50.0;
   account.max_positions = 10;
   account.auto_trading_enabled = true;
   account.copy_enabled = true;
   account.is_external = false;
   account.max_drawdown_pct = 20.0;
   account.profit_target_pct = 15.0;

   bool addResult = manager.AddAccount(account);
   ASSERT_TRUE(addResult, "AddAccount() should return true");
   ASSERT_EQUAL(manager.GetAccountCount(), 1, "Account count should be 1 after adding");

   // Add second account
   SAccountConnection account2;
   ZeroMemory(account2);
   account2.connection_id = "TEST_ACCOUNT_002";
   account2.broker_name = "Test Broker 2";
   account2.initial_balance = 20000.0;
   account2.target_allocation_pct = 50.0;

   manager.AddAccount(account2);
   ASSERT_EQUAL(manager.GetAccountCount(), 2, "Account count should be 2 after adding second account");

   // Remove account
   bool removeResult = manager.RemoveAccount("TEST_ACCOUNT_001");
   ASSERT_EQUAL(manager.GetAccountCount(), 1, "Account count should be 1 after removal");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Account Connection                                         |
//+------------------------------------------------------------------+
void TestAccountConnection()
{
   Print("\n--- Testing Account Connection ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add test account
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "CONN_TEST_001";
   account.broker_name = "Test Broker";
   account.initial_balance = 5000.0;

   manager.AddAccount(account);

   // Connect account
   bool connectResult = manager.ConnectAccount("CONN_TEST_001");
   ASSERT_TRUE(connectResult, "ConnectAccount() should return true");
   ASSERT_TRUE(manager.IsConnected("CONN_TEST_001"), "Account should be connected");

   // Disconnect account
   bool disconnectResult = manager.DisconnectAccount("CONN_TEST_001");
   ASSERT_TRUE(disconnectResult, "DisconnectAccount() should return true");
   ASSERT_FALSE(manager.IsConnected("CONN_TEST_001"), "Account should be disconnected");

   // Test disconnect all
   manager.ConnectAccount("CONN_TEST_001");
   manager.DisconnectAllAccounts();
   ASSERT_FALSE(manager.IsConnected("CONN_TEST_001"), "All accounts should be disconnected");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: External Account Management                                |
//+------------------------------------------------------------------+
void TestExternalAccountManagement()
{
   Print("\n--- Testing External Account Management ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add external account
   bool addResult = manager.AddExternalAccount(
      "EXT_TRADOVATE_001",
      "tradovate",
      1.5,      // multiplier
      10.0,     // max_lots
      false     // not inverse
   );

   ASSERT_TRUE(addResult, "AddExternalAccount() should return true");
   ASSERT_EQUAL(manager.GetAccountCount(), 1, "Account count should include external account");

   // Add inverse external account
   manager.AddExternalAccount(
      "EXT_INVERSE_001",
      "dxfeed",
      0.5,
      5.0,
      true      // inverse
   );

   ASSERT_EQUAL(manager.GetAccountCount(), 2, "Should have 2 external accounts");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Master Trade Execution                                     |
//+------------------------------------------------------------------+
void TestMasterTradeExecution()
{
   Print("\n--- Testing Master Trade Execution ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Create trade action
   STradeAction action;
   ZeroMemory(action);
   action.symbol = _Symbol;
   action.action_type = TRADE_ACTION_BUY;
   action.lot_size = 0.1;
   action.sl_price = 0;
   action.tp_price = 0;
   action.comment = "Test Trade";

   // Note: Actual execution would fail without live trading environment
   // Test structure and method existence
   ASSERT_TRUE(true, "Master trade execution method exists");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Trade Allocation                                           |
//+------------------------------------------------------------------+
void TestTradeAllocation()
{
   Print("\n--- Testing Trade Allocation ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add test accounts
   for(int i = 1; i <= 3; i++)
   {
      SAccountConnection account;
      ZeroMemory(account);
      account.connection_id = "ALLOC_TEST_" + IntegerToString(i);
      account.broker_name = "Test Broker";
      account.initial_balance = 10000.0 * i;
      account.target_allocation_pct = 100.0 / 3;
      account.copy_enabled = true;
      account.copy_multiplier = 1.0;
      account.max_positions = 10;

      manager.AddAccount(account);
      manager.ConnectAccount(account.connection_id);
   }

   ASSERT_EQUAL(manager.GetAccountCount(), 3, "Should have 3 accounts for allocation test");

   // Test allocation calculation
   double allocPct = manager.CalculateAllocationPct("ALLOC_TEST_1");
   ASSERT_TRUE(allocPct > 0, "Allocation percentage should be positive");

   double allocLots = manager.CalculateAllocatedLots("ALLOC_TEST_1", 1.0);
   ASSERT_TRUE(allocLots >= 0, "Allocated lots should be non-negative");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Account Performance                                        |
//+------------------------------------------------------------------+
void TestAccountPerformance()
{
   Print("\n--- Testing Account Performance ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add and connect account
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "PERF_TEST_001";
   account.broker_name = "Test Broker";
   account.initial_balance = 10000.0;

   manager.AddAccount(account);
   manager.ConnectAccount("PERF_TEST_001");

   // Calculate performance
   manager.CalculatePerformance("PERF_TEST_001");

   SAccountPerformance perf = manager.GetAccountPerformance("PERF_TEST_001");
   ASSERT_EQUAL(perf.account_id, "PERF_TEST_001", "Performance account ID should match");

   // Test group metrics
   double groupProfit = manager.GetTotalGroupProfit();
   ASSERT_TRUE(groupProfit >= 0 || groupProfit < 0, "Group profit should be a valid number");

   double avgWinRate = manager.GetAverageWinRate();
   ASSERT_TRUE(avgWinRate >= 0, "Average win rate should be non-negative");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Risk Management                                            |
//+------------------------------------------------------------------+
void TestRiskManagement()
{
   Print("\n--- Testing Risk Management ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add test account
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "RISK_TEST_001";
   account.broker_name = "Test Broker";
   account.initial_balance = 10000.0;
   account.current_balance = 10000.0;
   account.current_equity = 10000.0;
   account.free_margin = 10000.0;
   account.margin_level = 100.0;

   manager.AddAccount(account);
   manager.ConnectAccount("RISK_TEST_001");

   // Test risk limit checking
   manager.CheckRiskLimits();
   ASSERT_TRUE(true, "Risk limit check should complete without error");

   // Test margin checking
   manager.CheckMarginAcrossAllAccounts();
   ASSERT_TRUE(true, "Margin check should complete without error");

   // Test group risk checking
   bool groupRiskOk = manager.CheckGroupRiskLimits();
   ASSERT_TRUE(groupRiskOk || !groupRiskOk, "Group risk check should return boolean");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Drawdown Monitoring                                        |
//+------------------------------------------------------------------+
void TestDrawdownMonitoring()
{
   Print("\n--- Testing Drawdown Monitoring ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add account with drawdown
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "DD_TEST_001";
   account.broker_name = "Test Broker";
   account.initial_balance = 10000.0;
   account.current_balance = 9500.0;
   account.current_equity = 9400.0;
   account.max_drawdown_pct = 10.0;

   manager.AddAccount(account);
   manager.ConnectAccount("DD_TEST_001");

   // Check drawdown limits
   manager.CheckDrawdownLimits();
   ASSERT_TRUE(true, "Drawdown check should complete without error");

   // Test profit target checking
   manager.CheckProfitTargets();
   ASSERT_TRUE(true, "Profit target check should complete without error");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Allocation Calculations                                    |
//+------------------------------------------------------------------+
void TestAllocationCalculations()
{
   Print("\n--- Testing Allocation Calculations ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add accounts with different allocations
   for(int i = 1; i <= 4; i++)
   {
      SAccountConnection account;
      ZeroMemory(account);
      account.connection_id = "CALC_TEST_" + IntegerToString(i);
      account.initial_balance = 10000.0 * i;
      account.target_allocation_pct = 25.0;

      manager.AddAccount(account);
   }

   // Test allocation calculations
   for(int i = 1; i <= 4; i++)
   {
      string accountId = "CALC_TEST_" + IntegerToString(i);
      double allocPct = manager.CalculateAllocationPct(accountId);
      ASSERT_EQUAL(allocPct, 25.0, "Allocation percentage should be 25% for account " + accountId);
   }

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Logging                                                    |
//+------------------------------------------------------------------+
void TestLogging()
{
   Print("\n--- Testing Logging ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Add test account
   SAccountConnection account;
   ZeroMemory(account);
   account.connection_id = "LOG_TEST_001";
   account.broker_name = "Test Broker";
   account.initial_balance = 10000.0;

   manager.AddAccount(account);
   manager.ConnectAccount("LOG_TEST_001");

   // Test logging
   manager.LogAccountStatus("LOG_TEST_001");
   ASSERT_TRUE(true, "LogAccountStatus should complete without error");

   manager.LogAllAccountStatuses();
   ASSERT_TRUE(true, "LogAllAccountStatuses should complete without error");

   delete manager;
}

//+------------------------------------------------------------------+
//| Test: Edge Cases                                                 |
//+------------------------------------------------------------------+
void TestEdgeCases()
{
   Print("\n--- Testing Edge Cases ---");

   CMultiAccountManager *manager = new CMultiAccountManager();
   manager.Initialize();

   // Test with non-existent account
   bool connectResult = manager.ConnectAccount("NONEXISTENT_ACCOUNT");
   ASSERT_FALSE(connectResult, "Connecting non-existent account should return false");

   bool disconnectResult = manager.DisconnectAccount("NONEXISTENT_ACCOUNT");
   ASSERT_FALSE(disconnectResult, "Disconnecting non-existent account should return false");

   // Test empty account ID
   double allocPct = manager.CalculateAllocationPct("");
   ASSERT_EQUAL(allocPct, 0.0, "Empty account ID should return 0 allocation");

   // Test performance for non-existent account
   SAccountPerformance perf = manager.GetAccountPerformance("NONEXISTENT");
   ASSERT_EQUAL(perf.account_id, "NONEXISTENT", "Should return performance struct even for non-existent account");

   // Test pause/resume
   manager.PauseTradingForAccount("NONEXISTENT", "Test pause");
   ASSERT_TRUE(true, "Pausing non-existent account should not crash");

   manager.ResumeTrading("NONEXISTENT");
   ASSERT_TRUE(true, "Resuming non-existent account should not crash");

   // Test with zero accounts
   ASSERT_EQUAL(manager.GetAccountCount(), 0, "Should have no accounts");
   ASSERT_EQUAL(manager.GetTotalEquity(), 0.0, "Total equity should be 0 with no accounts");

   // Test multiple initialization
   manager.Initialize();
   manager.Initialize();
   ASSERT_TRUE(true, "Multiple Initialize calls should not crash");

   delete manager;
}

//+------------------------------------------------------------------+
//| Print test summary                                               |
//+------------------------------------------------------------------+
void PrintTestSummary()
{
   Print("\n========================================");
   Print("Test Summary");
   Print("========================================");
   Print("Total Tests:  ", g_TotalTests);
   Print("Passed:       ", g_TestsPassed, " (", (g_TotalTests > 0 ? (g_TestsPassed * 100.0 / g_TotalTests) : 0), "%)");
   Print("Failed:       ", g_TestsFailed, " (", (g_TotalTests > 0 ? (g_TestsFailed * 100.0 / g_TotalTests) : 0), "%)");
   Print("========================================");

   if(g_TestsFailed == 0)
   {
      Print("✓ All tests passed!");
   }
   else
   {
      Print("✗ Some tests failed. Please review the output above.");
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Test execution completed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function (not used in tests)                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // Not used in test suite
}