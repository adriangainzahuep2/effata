//+------------------------------------------------------------------+
//| TradingJournal.mqh                                              |
//| Advanced Server-Based Trading Journal for EFFATA                |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"
#property strict

#include "../Core/Structures.mqh"

struct JournalEntry {
    string    ticket;
    string    symbol;
    int       action;        // 1: Buy, 2: Sell
    double    lots;
    double    entry_price;
    double    exit_price;
    double    profit;
    datetime  entry_time;
    datetime  exit_time;
    string    reasoning;     // AI reasoning
    double    confidence;
    string    market_state;  // P-Shaped, D-Shaped, etc.
    double    vwap_dist;
    double    delta;
};

class CTradingJournal {
private:
    string    m_account_id;
    string    m_bridge_url;

public:
    CTradingJournal(string account_id, string bridge_url = "http://localhost:8000/journal") {
        m_account_id = account_id;
        m_bridge_url = bridge_url;
    }

    void LogTrade(const JournalEntry &entry) {
        string json = Serialize(entry);
        SendToBridge(json);
        Print("Trade logged to journal: ", entry.ticket);
    }

private:
    string Serialize(const JournalEntry &entry) {
        string json = "{";
        json += "\"account_id\":\"" + m_account_id + "\",";
        json += "\"ticket\":\"" + entry.ticket + "\",";
        json += "\"symbol\":\"" + entry.symbol + "\",";
        json += "\"action\":" + IntegerToString(entry.action) + ",";
        json += "\"lots\":" + DoubleToString(entry.lots, 2) + ",";
        json += "\"entry_price\":" + DoubleToString(entry.entry_price, 5) + ",";
        json += "\"profit\":" + DoubleToString(entry.profit, 2) + ",";
        json += "\"reasoning\":\"" + entry.reasoning + "\",";
        json += "\"market_state\":\"" + entry.market_state + "\"";
        json += "}";
        return json;
    }

    void SendToBridge(string json_data) {
        char data[], result[];
        string headers = "Content-Type: application/json\r\n";
        StringToCharArray(json_data, data);

        int res = WebRequest("POST", m_bridge_url, headers, 5000, data, result, headers);
        if(res != 200) {
            Print("Failed to send journal entry to bridge: ", res);
        }
    }
};
