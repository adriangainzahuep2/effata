//+------------------------------------------------------------------+
//| EFFATA_ORCHESTRATOR_HFT_TRADING.mq5                              |
//| Advanced Multi-Agent Reinforcement Learning Trading System      |
//| with DeepSeek V3.2 Self-Verification Architecture               |
//| Copyright 2025, EFFATA Reinforcement Trading Systems             |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Reinforcement Trading Systems"
#property link      "https://www.effata.ai"
#property version   "3.20"
#property description "LLM Multi-Agent RL Trading Orchestrator with DeepSeek V3.2 Self-Verification"

// Compatibility layer for MQL4
#ifdef __MQL4__
  #define SYMBOL_POINT        Point
  #define SYMBOL_ASK          Ask
  #define SYMBOL_BID          Bid
  #define PERIOD_CURRENT      0
  #define CHART_WINDOW_HANDLE 0
  #define ENUM_STORAGESIZE    int
#endif

// Core includes
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayObj.mqh>

// Compatibility
#include "Include/Core/CompatMQL4.mqh"

// Custom includes
#include "Include/BrowserAgent/BrowserAgent.mqh"
#include "Include/Environments/MonteCarloEnv.mqh"
#include "Include/Core/NeuralMemoryController.mqh"
#include "Include/Core/Structures.mqh"
#include "Include/Core/DeepSeekVerification.mqh"
#include "Include/Environments/MarketExecutionEnv.mqh"
#include "Include/Environments/PatternDetectionEnv.mqh"
#include "Include/Environments/StrategyEnv.mqh"
#include "Include/Environments/RiskManagementEnv.mqh"
#include "Include/Environments/StatisticsEnv.mqh"
#include "Include/Orchestrator/AgentOrchestrator.mqh"
#include "Include/MarketContext/MarketContextAnalyzer.mqh"
#include "Include/Calendar/EconomicCalendar.mqh"
#include "Include/Environments/MultiAccountManagerEnv.mqh"

// Helper libs
#include "Include/Reports/BacktestAnalyzer.mqh"
#include "Include/Optimization/ParameterOptimizer.mqh"
#include "Include/Trade/TradeManager.mqh"
#include "Include/Core/LicenseManager.mqh"
#include "Include/UI/Dashboard.mqh"

// New Indicators
#include "Include/Indicators/AndeanOscillator.mqh"
#include "Include/Indicators/VWAP.mqh"
#include "Include/Indicators/Fibonacci.mqh"
#include "Include/ICT/ICTFramework.mqh"
#include "Include/Patterns/CRTTheory.mqh"

input group "=== MONTE CARLO RISK MANAGEMENT ==="
input int    InpMonteCarloSimulations  = 1000;   // Number of Monte Carlo simulations
input int    InpMonteCarloObservations = 1000;   // Observations per simulation
input double InpDailyRiskLimit        = 0.0019;  // Daily risk limit (0.19%)
input bool   InpEnableNeuralRisk       = true;   // Enable neural risk management

// Input parameters
input group "=== CORE ORCHESTRATOR SETTINGS ==="
input bool   InpEnableSelfVerification = true;   // Enable DeepSeek V3.2 Self-Verification
input int    InpMetaLearningDepth      = 4;      // Meta-Learning depth levels
input double InpConfidenceThreshold    = 0.75;   // Minimum confidence for trade execution
input bool   InpEnableContinualLearning = true;  // Enable Continual Learning

input group "=== RISK MANAGEMENT ==="
input double InpMaxDailyLossPercent    = 0.19;   // Max daily loss percentage (0.19%)
input double InpRiskPerTradePercent    = 0.5;    // Risk per trade percentage
input bool   InpEnableAdaptiveRisk     = true;   // Enable adaptive risk management

input group "=== EXECUTION SETTINGS ==="
input bool   InpEnableHFTRouting        = true;   // Enable HFT Order Routing
input int    InpOrderAggression        = 2;      // Order aggression level (1-5)
input int    InpUpdateFrequencyMs      = 100;    // Update frequency in milliseconds

// Global objects
CAgentOrchestrator    *g_Orchestrator;
CEconomicCalendar     *g_Calendar;
CMarketExecutionEnv   *g_ExecutionEnv;
CPatternDetectionEnv  *g_PatternEnv;
CStrategyEnv          *g_StrategyEnv;
CRiskManagementEnv    *g_RiskEnv;
CStatisticsEnv        *g_StatsEnv;
CMultiAccountManager  *g_MAM;
CDashboard            *g_Dashboard;
CBacktestAnalyzer     *g_BacktestAnalyzer;
CMonteCarloRiskEnvironment *g_MonteCarloEnv;

// Indicators
CAndeanOscillator     *g_Andean;
CVWAP                 *g_VWAP;

double                g_ActiveRiskPercent;
CFibonacci            *g_Fibo;
ICTFramework          *g_ICT;
CCRTTheory            *g_CRT;
CMarketContextAnalyzer *g_ContextAnalyzer;

double                 g_MarketFeatures[256];

CBrowserAgent          *g_Browser_Agent;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

    g_Browser_Agent = new CBrowserAgent();
    g_Browser_Agent->StartBrowser(false);
    // Initialize global objects
    g_Orchestrator = new CAgentOrchestrator();
    g_Calendar = new CEconomicCalendar();
    g_ExecutionEnv = new CMarketExecutionEnv(InpMaxDailyLossPercent);
    g_PatternEnv = new CPatternDetectionEnv();
    g_StrategyEnv = new CStrategyEnv();
    g_RiskEnv = new CRiskManagementEnv(InpRiskPerTradePercent, InpEnableAdaptiveRisk);
    g_StatsEnv = new CStatisticsEnv();
    g_MAM = new CMultiAccountManager();
    g_Dashboard = new CDashboard("EFFATA ORCHESTRATOR V4.02");
    g_BacktestAnalyzer = new CBacktestAnalyzer("EFFATA_Report.txt");
    g_MonteCarloEnv = new CMonteCarloRiskEnvironment();

    // Initialize Indicators
    g_Andean = new CAndeanOscillator(_Symbol, PERIOD_CURRENT);
    g_VWAP = new CVWAP(_Symbol, PERIOD_CURRENT);
    g_Fibo = new CFibonacci(_Symbol, PERIOD_CURRENT);
    g_ICT = new ICTFramework();
    g_CRT = new CCRTTheory(_Symbol);
    g_ContextAnalyzer = new CMarketContextAnalyzer(_Symbol, PERIOD_CURRENT);

    // Wire up environments
    g_RiskEnv->SetStatisticsEnv(g_StatsEnv);
    g_ActiveRiskPercent = InpRiskPerTradePercent;
    // g_StrategyEnv->SetStatisticsEnv(g_StatsEnv); // If StrategyEnv supports it

    // Configure DeepSeek V3.2 Self-Verification
    CDeepSeekVerification::Configure(InpEnableSelfVerification, InpConfidenceThreshold);

    // Initialize environments
    if(!g_PatternEnv->Initialize() ||
       !g_StrategyEnv->Initialize() ||
       !g_RiskEnv->Initialize() ||
       !g_ExecutionEnv->Initialize() ||
       !g_StatsEnv->Initialize() ||
       !g_MonteCarloEnv->Initialize())
    {
        Print("❌ Failed to initialize one or more environments");
        return(INIT_FAILED);
    }

    // Configure orchestrator
    if(!g_Orchestrator->Configure(g_PatternEnv, g_StrategyEnv, g_RiskEnv, g_ExecutionEnv, g_StatsEnv))
    {
        Print("❌ Failed to configure Agent Orchestrator");
        return(INIT_FAILED);
    }

    // Initialize UI
    g_Dashboard->Create();

    // Set up timer for HFT updates
    if(InpEnableHFTRouting) {
        EventSetMillisecondTimer(InpUpdateFrequencyMs);
    } else {
        EventSetTimer(1);
    }

    Print("🚀 EFFATA Orchestrator initialized successfully with DeepSeek V3.2 Self-Verification & Muon Optimization");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();

    if(CheckPointer(g_Dashboard) == POINTER_DYNAMIC) {
       g_Dashboard->Delete();
       delete g_Dashboard;
    }

    // Cleanup
    if(CheckPointer(g_Orchestrator) == POINTER_DYNAMIC) delete g_Orchestrator;
    if(CheckPointer(g_Calendar) == POINTER_DYNAMIC) delete g_Calendar;
    if(CheckPointer(g_ExecutionEnv) == POINTER_DYNAMIC) delete g_ExecutionEnv;
    if(CheckPointer(g_PatternEnv) == POINTER_DYNAMIC) delete g_PatternEnv;
    if(CheckPointer(g_StrategyEnv) == POINTER_DYNAMIC) delete g_StrategyEnv;
    if(CheckPointer(g_RiskEnv) == POINTER_DYNAMIC) delete g_RiskEnv;
    if(CheckPointer(g_StatsEnv) == POINTER_DYNAMIC) delete g_StatsEnv;
    if(CheckPointer(g_MAM) == POINTER_DYNAMIC) delete g_MAM;
    if(CheckPointer(g_BacktestAnalyzer) == POINTER_DYNAMIC) delete g_BacktestAnalyzer;
    if(CheckPointer(g_MonteCarloEnv) == POINTER_DYNAMIC) delete g_MonteCarloEnv;

    // Cleanup Indicators
    if(CheckPointer(g_Andean) == POINTER_DYNAMIC) delete g_Andean;
    if(CheckPointer(g_VWAP) == POINTER_DYNAMIC) delete g_VWAP;
    if(CheckPointer(g_Fibo) == POINTER_DYNAMIC) delete g_Fibo;
    if(CheckPointer(g_ICT) == POINTER_DYNAMIC) delete g_ICT;
    if(CheckPointer(g_CRT) == POINTER_DYNAMIC) delete g_CRT;
    if(CheckPointer(g_ContextAnalyzer) == POINTER_DYNAMIC) delete g_ContextAnalyzer;

    if(CheckPointer(g_Browser_Agent) == POINTER_DYNAMIC) delete g_Browser_Agent;

    Print("🛑 EFFATA Orchestrator deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsMarketOpen()) return;

    // Extract Features
    ExtractMarketFeatures(g_MarketFeatures);

    // Update Dashboard
    UpdateDashboardInfo();

    // Continual Learning Update
    if(InpEnableContinualLearning) {
        g_PatternEnv->UpdateFromTick(g_MarketFeatures);
        g_StrategyEnv->UpdateFromTick(g_MarketFeatures);
        g_RiskEnv->UpdateFromTick(g_MarketFeatures);
        g_ExecutionEnv->UpdateFromTick(g_MarketFeatures);
    }

    // Self-Verification
    if(InpEnableSelfVerification) {
        g_PatternEnv->SelfVerify(g_MarketFeatures);
        g_StrategyEnv->SelfVerify(g_MarketFeatures);
        g_RiskEnv->SelfVerify(g_MarketFeatures);
        g_ExecutionEnv->SelfVerify(g_MarketFeatures);
    }

    // Economic Calendar Monitoring
    g_Calendar->UpdateCalendar();
    g_Calendar->NotifyImportantEvents();
    if(g_Calendar->IsRiskReductionRequired(30)) {
        // Automatically reduce position sizes or avoid new trades
        g_ActiveRiskPercent = InpRiskPerTradePercent * 0.5;
    } else {
        g_ActiveRiskPercent = InpRiskPerTradePercent;
    }

    // Risk Monitor
    if(!g_ExecutionEnv->MonitorRiskAndEquity()) {
        return;
    }

    // Monte Carlo Risk Verification
    RiskAssessment mc_risk = g_MonteCarloEnv->GetRiskAssessment();
    if(!mc_risk.allowTrading) {
        Print("⚠️ Trading blocked by Monte Carlo simulation: ", mc_risk.reason);
        return;
    }

    // Get Decision from Orchestrator (which uses RL Agent)
    TradeDecision decision = g_Orchestrator->GetTradingDecision(g_MarketFeatures);

    // Optional AI Analysis from Browser Agent
    static datetime lastBrowserUpdate = 0;
    if(TimeCurrent() - lastBrowserUpdate > 3600) { // Once per hour
        SAnalysisResponse browser_resp;
        if(g_Browser_Agent->RequestAnalysis(AI_DEEPSEEK, _Symbol, PERIOD_CURRENT, browser_resp)) {
            Print("🤖 AI Analysis: ", browser_resp.result.reasoning);
            lastBrowserUpdate = TimeCurrent();
        }
    }

    // Execution Logic
    if(decision.action != NO_SIGNAL && decision.confidence >= InpConfidenceThreshold) {
        STradeAction mam_action;
        mam_action.symbol = _Symbol;
        mam_action.action_type = (decision.action == BUY_SIGNAL) ? 1 : 2;
        mam_action.lot_size = decision.positionSize;
        mam_action.sl_price = decision.stopLoss;
        mam_action.tp_price = decision.takeProfit;
        mam_action.comment = decision.reasoning;

        if(g_MAM.GetAccountCount() > 0) {
            g_MAM.ExecuteMasterTrade(mam_action);
        } else {
            g_ExecutionEnv->ExecuteDecision(decision);
        }

        if(decision.action != NO_SIGNAL) {
            g_StatsEnv->RecordTradeDecision(decision);
        }
    }

    // Periodic Memory Consolidation
    static int memoryCounter = 0;
    if(++memoryCounter >= 100) {
        g_PatternEnv->ConsolidateMemory();
        g_StrategyEnv->ConsolidateMemory();
        g_RiskEnv->ConsolidateMemory();
        g_ExecutionEnv->ConsolidateMemory();
        memoryCounter = 0;
    }
}

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer() {


    g_StatsEnv->UpdatePerformanceMetrics();

    static string lastSession = "";
    string currentSession = GetMarketSession();
    if(lastSession != currentSession) {
        lastSession = currentSession;
        MarketContext context;
        context.sessionType = currentSession;
        g_PatternEnv->OnSessionChange(context);
        g_StrategyEnv->OnSessionChange(context);
        g_RiskEnv->OnSessionChange(context);
        g_ExecutionEnv->OnSessionChange(context);
    }
}

//+------------------------------------------------------------------+
//| Trade Transaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    if(g_ExecutionEnv) g_ExecutionEnv->OnTradeTransaction(trans, request, result);
    if(g_StatsEnv) g_StatsEnv->OnTradeTransaction(trans, request, result);
    if(g_BacktestAnalyzer) g_BacktestAnalyzer->OnTradeTransaction(trans);
}

//+------------------------------------------------------------------+
//| Helper: Update Dashboard                                         |
//+------------------------------------------------------------------+
void UpdateDashboardInfo() {
    if(!g_Dashboard) return;

    RiskAssessment risk = g_RiskEnv->AssessCurrentRisk();
    PerformanceMetrics metrics = g_StatsEnv->GetMetrics();

    g_Dashboard->Update(
        "N/A", // Daily Bias (need source)
        "N/A", // H4 Bias
        "N/A", // PO3 Phase
        risk.allowTrading,
        (int)(metrics.winRate * 100),
        (int)metrics.totalTrades
    );
}

//+------------------------------------------------------------------+
//| Helper: Extract Features                                         |
//+------------------------------------------------------------------+
void ExtractMarketFeatures(double &features[]) {
    // Basic extraction with normalization
    ArrayInitialize(features, 0.0);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double multiplier = MathPow(10, digits);

    features[0] = iClose(_Symbol, PERIOD_CURRENT, 0) * multiplier;
    features[1] = iOpen(_Symbol, PERIOD_CURRENT, 0) * multiplier;
    features[2] = iHigh(_Symbol, PERIOD_CURRENT, 0) * multiplier;
    features[3] = iLow(_Symbol, PERIOD_CURRENT, 0) * multiplier;
    features[4] = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);

    // Add indicators
    features[5] = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, 0) / 100.0;
    features[6] = iATR(_Symbol, PERIOD_CURRENT, 14, 0) / iClose(_Symbol, PERIOD_CURRENT, 0); // Normalized ATR
    features[8] = (iHigh(_Symbol, PERIOD_D1, 0) - iLow(_Symbol, PERIOD_D1, 0)) / iClose(_Symbol, PERIOD_CURRENT, 0); // Daily Volatility

    // Patterns
    PatternResult pattern = g_PatternEnv->DetectPatterns();
    features[11] = pattern.patternStrength;
    features[12] = pattern.confidence;

    // Risk
    RiskAssessment risk = g_RiskEnv->AssessCurrentRisk();
    features[16] = risk.riskScore;

    // Liquidity
    features[18] = g_ExecutionEnv->GetLiquidityScore();

    // NEW FEATURES FROM LIBRARIES
    // Andean Oscillator
    double bull, bear;
    int andeanSignal = g_Andean->Calculate(bull, bear);
    features[40] = bull;
    features[41] = bear;
    features[42] = (double)andeanSignal;

    // Integrated Context
    UnifiedMarketState state = g_ContextAnalyzer->Analyze();
    features[45] = state.vwap_deviation;
    features[70] = state.hvn_distance;
    features[71] = state.delta;
    features[72] = state.cumulative_delta;
    features[73] = state.delta_divergence ? 1.0 : 0.0;
    features[74] = (double)state.stacked_imbalances;
    features[75] = state.sentiment_score;

    // Fibonacci
    features[46] = g_Fibo->GetNearestGoldenLevelDist();

    // ICT Features
    g_ICT->Update(_Symbol);
    bool inFVG = g_ICT->IsPriceInFVG(features[0]);
    features[50] = inFVG ? 1.0 : 0.0;

    // CRT Theory
    g_CRT->Calculate(0);
    features[60] = g_CRT->isLarge ? 1.0 : 0.0;
    features[61] = g_CRT->isOutside ? 1.0 : 0.0;

    // Statistics Features
    PerformanceMetrics pm = g_StatsEnv->GetMetrics();
    features[30] = pm.winRate;
    features[31] = pm.profitFactor;
    features[32] = pm.drawdownPercent;
}

//+------------------------------------------------------------------+
//| Helper: Get Session                                              |
//+------------------------------------------------------------------+
string GetMarketSession() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int h = dt.hour;
    if(h < 8) return "ASIA";
    if(h < 16) return "LONDON";
    return "NEW_YORK";
}

//+------------------------------------------------------------------+
//| Helper: Is Market Open                                           |
//+------------------------------------------------------------------+
bool IsMarketOpen() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return (dt.day_of_week != 0 && dt.day_of_week != 6);
}
