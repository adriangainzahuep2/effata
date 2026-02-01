//+------------------------------------------------------------------+
//| VolumeProfile.mqh                                                |
//| Volume Profile Indicator for Price and Volume Analysis           |
//| Copyright 2025, EFFATA Trading Systems                           |
//+------------------------------------------------------------------+
#property copyright "2025, EFFATA Trading Systems"
#property version   "1.00"
#property strict

#include <Arrays/ArrayDouble.mqh>

enum ENUM_PROFILE_SHAPE {
    SHAPE_D, // Balanced
    SHAPE_P, // Bullish / Trend High
    SHAPE_B, // Bearish / Trend Low
    SHAPE_I, // Thin / Strong Trend
    SHAPE_UNKNOWN
};

class CVolumeProfile {
private:
    string          m_symbol;
    ENUM_TIMEFRAMES m_period;
    double          m_step;           // Price step (bin size)
    int             m_bins;           // Number of bins
    double          m_min_price;
    double          m_max_price;
    double          m_volume_data[];  // Volume per price level
    double          m_total_volume;
    double          m_hvn_price;      // High Volume Node
    double          m_lvn_price;      // Low Volume Node

public:
    CVolumeProfile(string symbol, ENUM_TIMEFRAMES period, double step_points = 10) {
        m_symbol = symbol;
        m_period = period;
        m_step = step_points * SymbolInfoDouble(symbol, SYMBOL_POINT);
        m_bins = 0;
        m_total_volume = 0;
    }

    ~CVolumeProfile() {
        ArrayFree(m_volume_data);
    }

    // Calculate Volume Profile using real tick data
    bool Calculate(int bars = 1000) {
        if(bars <= 0) return false;

        m_min_price = 1e10;
        m_max_price = 0;

        // 1. Find price range
        for(int i = 0; i < bars; i++) {
            double h = iHigh(m_symbol, m_period, i);
            double l = iLow(m_symbol, m_period, i);
            if(h > m_max_price) m_max_price = h;
            if(l < m_min_price) m_min_price = l;
        }

        if(m_max_price <= m_min_price) return false;

        // 2. Initialize bins
        m_bins = (int)((m_max_price - m_min_price) / m_step) + 1;
        ArrayResize(m_volume_data, m_bins);
        ArrayInitialize(m_volume_data, 0.0);
        m_total_volume = 0;

        // 3. Use CopyTicksRange for real tick-based volume analysis
        datetime start_time = iTime(m_symbol, m_period, bars-1);
        datetime end_time = TimeCurrent();

        MqlTick ticks[];
        int copied = CopyTicksRange(m_symbol, ticks, COPY_TICKS_ALL, start_time * 1000, end_time * 1000);

        if(copied > 0) {
            for(int i = 0; i < copied; i++) {
                double price = ticks[i].last;
                if(price == 0) price = (ticks[i].bid + ticks[i].ask) / 2.0;

                int bin_idx = (int)((price - m_min_price) / m_step);
                if(bin_idx >= 0 && bin_idx < m_bins) {
                    double vol = (double)ticks[i].volume;
                    if(vol == 0) vol = 1; // Minimum volume if not provided
                    m_volume_data[bin_idx] += vol;
                    m_total_volume += vol;
                }
            }
        } else {
            // Fallback to bar volume distribution if no ticks available
            for(int i = 0; i < bars; i++) {
                double h = iHigh(m_symbol, m_period, i);
                double l = iLow(m_symbol, m_period, i);
                double vol = (double)iTickVolume(m_symbol, m_period, i);

                int bin_start = (int)((l - m_min_price) / m_step);
                int bin_end = (int)((h - m_min_price) / m_step);

                if(bin_start == bin_end) {
                    if(bin_start >= 0 && bin_start < m_bins) m_volume_data[bin_start] += vol;
                } else {
                    double vol_per_bin = vol / (bin_end - bin_start + 1);
                    for(int b = bin_start; b <= bin_end; b++) {
                        if(b >= 0 && b < m_bins) m_volume_data[b] += vol_per_bin;
                    }
                }
                m_total_volume += vol;
            }
        }

        // 4. Find HVN and LVN
        double max_vol = 0;
        double min_vol = 1e20;
        int hvn_idx = 0;
        int lvn_idx = 0;

        for(int i = 0; i < m_bins; i++) {
            if(m_volume_data[i] > max_vol) {
                max_vol = m_volume_data[i];
                hvn_idx = i;
            }
            if(m_volume_data[i] < min_vol && m_volume_data[i] > 0) {
                min_vol = m_volume_data[i];
                lvn_idx = i;
            }
        }

        m_hvn_price = m_min_price + hvn_idx * m_step;
        m_lvn_price = m_min_price + lvn_idx * m_step;

        return true;
    }

    double GetHVN() { return m_hvn_price; }
    double GetLVN() { return m_lvn_price; }

    ENUM_PROFILE_SHAPE DetectShape() {
        if(m_bins < 5) return SHAPE_UNKNOWN;

        int center = m_bins / 2;
        double upper_vol = 0;
        double lower_vol = 0;

        for(int i = 0; i < center; i++) lower_vol += m_volume_data[i];
        for(int i = center; i < m_bins; i++) upper_vol += m_volume_data[i];

        double ratio = (lower_vol > 0) ? upper_vol / lower_vol : 100.0;

        if(ratio > 1.5) return SHAPE_P; // Volume concentrated at the top
        if(ratio < 0.66) return SHAPE_B; // Volume concentrated at the bottom

        // Check for I shape (thin)
        double avg_vol = m_total_volume / m_bins;
        int standard_bins = 0;
        for(int i=0; i<m_bins; i++) {
            if(m_volume_data[i] > avg_vol * 0.5) standard_bins++;
        }

        if((double)standard_bins / m_bins < 0.3) return SHAPE_I;

        return SHAPE_D;
    }

    double GetVolumeAtPrice(double price) {
        int idx = (int)((price - m_min_price) / m_step);
        if(idx >= 0 && idx < m_bins) return m_volume_data[idx];
        return 0;
    }

    bool IsInHighVolumeArea(double price) {
        double vol = GetVolumeAtPrice(price);
        double avg_vol = m_total_volume / m_bins;
        return vol > avg_vol * 1.5;
    }
};
