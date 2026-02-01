//+------------------------------------------------------------------+
//| OrderFlow.mqh                                                    |
//| Order Flow Analysis based on Footprint, Delta and Imbalances     |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"
#property strict

struct FootprintCell {
    double price;
    double bid_vol;
    double ask_vol;
    double total_vol;
    double delta;
    bool   is_imbalance_buy;
    bool   is_imbalance_sell;
};

struct FootprintBar {
    datetime time;
    FootprintCell cells[];
    double delta;
    double cumulative_delta;
    double total_volume;
    double hvn_price;
    bool   unfinished_high;
    bool   unfinished_low;
};

class COrderFlowAnalyzer {
private:
    string          m_symbol;
    ENUM_TIMEFRAMES m_period;
    double          m_tick_size;
    FootprintBar    m_history[];
    int             m_history_size;
    double          m_running_cumulative_delta;

public:
    COrderFlowAnalyzer(string symbol, ENUM_TIMEFRAMES period) {
        m_symbol = symbol;
        m_period = period;
        m_tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        m_history_size = 0;
        m_running_cumulative_delta = 0;
    }

    // Process recent data to build footprints
    bool Update(int bars_to_process = 100) {
        ArrayResize(m_history, bars_to_process);
        m_running_cumulative_delta = 0;

        for(int i = bars_to_process - 1; i >= 0; i--) {
            if(!BuildFootprint(i, m_history[bars_to_process - 1 - i])) return false;
            m_running_cumulative_delta += m_history[bars_to_process - 1 - i].delta;
            m_history[bars_to_process - 1 - i].cumulative_delta = m_running_cumulative_delta;
        }

        m_history_size = bars_to_process;
        return true;
    }

    // Enhanced footprint builder using actual Tick data
    bool BuildFootprint(int shift, FootprintBar &bar) {
        bar.time = iTime(m_symbol, m_period, shift);
        datetime next_time = (shift > 0) ? iTime(m_symbol, m_period, shift - 1) : TimeCurrent();

        double high = iHigh(m_symbol, m_period, shift);
        double low = iLow(m_symbol, m_period, shift);

        int num_cells = (int)((high - low) / m_tick_size) + 1;
        if(num_cells <= 0) return false;
        if(num_cells > 2000) num_cells = 2000;

        ArrayResize(bar.cells, num_cells);
        for(int i=0; i<num_cells; i++) {
            bar.cells[i].price = low + i * m_tick_size;
            bar.cells[i].bid_vol = 0;
            bar.cells[i].ask_vol = 0;
            bar.cells[i].total_vol = 0;
        }

        MqlTick ticks[];
        int copied = CopyTicksRange(m_symbol, ticks, COPY_TICKS_ALL, bar.time * 1000, next_time * 1000);

        if(copied > 0) {
            for(int i = 0; i < copied; i++) {
                double price = ticks[i].last;
                if(price == 0) price = (ticks[i].bid + ticks[i].ask) / 2.0;

                int cell_idx = (int)((price - low) / m_tick_size);
                if(cell_idx >= 0 && cell_idx < num_cells) {
                    double vol = (double)ticks[i].volume;
                    if(vol == 0) vol = (double)ticks[i].volume_real;
                    if(vol == 0) vol = 1;

                    if(ticks[i].last >= ticks[i].ask || (ticks[i].flags & TICK_FLAG_ASK) > 0) { // Aggressive Buy
                        bar.cells[cell_idx].ask_vol += vol;
                    } else if(ticks[i].last <= ticks[i].bid || (ticks[i].flags & TICK_FLAG_BID) > 0) { // Aggressive Sell
                        bar.cells[cell_idx].bid_vol += vol;
                    } else {
                        // Distributed if in between
                        bar.cells[cell_idx].ask_vol += vol * 0.5;
                        bar.cells[cell_idx].bid_vol += vol * 0.5;
                    }
                }
            }
        } else {
            // Fallback to estimation based on bar close if no ticks available
            double close = iClose(m_symbol, m_period, shift);
            double open = iOpen(m_symbol, m_period, shift);
            double total_vol = (double)iTickVolume(m_symbol, m_period, shift);

            for(int i=0; i<num_cells; i++) {
                bar.cells[i].total_vol = total_vol / num_cells;
                if(close > open) { // Bullish bar
                    bar.cells[i].ask_vol = bar.cells[i].total_vol * 0.6;
                    bar.cells[i].bid_vol = bar.cells[i].total_vol * 0.4;
                } else {
                    bar.cells[i].ask_vol = bar.cells[i].total_vol * 0.4;
                    bar.cells[i].bid_vol = bar.cells[i].total_vol * 0.6;
                }
            }
        }

        bar.delta = 0;
        bar.total_volume = 0;
        double max_cell_vol = 0;

        for(int i = 0; i < num_cells; i++) {
            bar.cells[i].total_vol = bar.cells[i].bid_vol + bar.cells[i].ask_vol;
            bar.cells[i].delta = bar.cells[i].ask_vol - bar.cells[i].bid_vol;

            // Imbalance detection (300% rule)
            bar.cells[i].is_imbalance_buy = (bar.cells[i].ask_vol >= bar.cells[i].bid_vol * 3.0 && bar.cells[i].bid_vol > 0);
            bar.cells[i].is_imbalance_sell = (bar.cells[i].bid_vol >= bar.cells[i].ask_vol * 3.0 && bar.cells[i].ask_vol > 0);

            bar.delta += bar.cells[i].delta;
            bar.total_volume += bar.cells[i].total_vol;

            if(bar.cells[i].total_vol > max_cell_vol) {
                max_cell_vol = bar.cells[i].total_vol;
                bar.hvn_price = bar.cells[i].price;
            }
        }

        bar.unfinished_high = (bar.cells[num_cells-1].bid_vol > 0);
        bar.unfinished_low = (bar.cells[0].ask_vol > 0);

        return true;
    }

    double GetDelta(int shift = 0) {
        if(shift < m_history_size) return m_history[m_history_size - 1 - shift].delta;
        return 0;
    }

    double GetCumulativeDelta(int shift = 0) {
        if(shift < m_history_size) return m_history[m_history_size - 1 - shift].cumulative_delta;
        return 0;
    }

    bool DetectDeltaDivergence(int shift = 0) {
        if(shift + 1 >= m_history_size) return false;

        double price_curr = iClose(m_symbol, m_period, shift);
        double price_prev = iClose(m_symbol, m_period, shift + 1);
        double delta_curr = GetDelta(shift);

        // Price rising but Delta negative OR Price falling but Delta positive
        if(price_curr > price_prev && delta_curr < 0) return true;
        if(price_curr < price_prev && delta_curr > 0) return true;

        return false;
    }

    int DetectStackedImbalances(int shift = 0) {
        if(shift >= m_history_size) return 0;
        FootprintBar bar = m_history[m_history_size - 1 - shift];

        int max_stacked_buy = 0;
        int max_stacked_sell = 0;
        int current_buy = 0;
        int current_sell = 0;

        for(int i = 0; i < ArraySize(bar.cells); i++) {
            if(bar.cells[i].is_imbalance_buy) {
                current_buy++;
                if(current_buy > max_stacked_buy) max_stacked_buy = current_buy;
            } else {
                current_buy = 0;
            }

            if(bar.cells[i].is_imbalance_sell) {
                current_sell++;
                if(current_sell > max_stacked_sell) max_stacked_sell = current_sell;
            } else {
                current_sell = 0;
            }
        }

        if(max_stacked_buy >= 3) return 1;  // Bullish Stacked Imbalance
        if(max_stacked_sell >= 3) return -1; // Bearish Stacked Imbalance

        return 0;
    }

    bool HasUnfinishedBusiness(int shift = 0) {
        if(shift < m_history_size) {
             return m_history[m_history_size - 1 - shift].unfinished_high ||
                    m_history[m_history_size - 1 - shift].unfinished_low;
        }
        return false;
    }
};
