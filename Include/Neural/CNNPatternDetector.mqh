//+------------------------------------------------------------------+
//| Include/Neural/CNNPatternDetector.mqh                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Advanced AI Trading Systems"
#property strict

#ifndef CNN_PATTERN_DETECTOR_MQH
#define CNN_PATTERN_DETECTOR_MQH

#include "../Core/Structures.mqh"
#include "../Core/CompatMQL4.mqh"
#include "../Core/NeuralMemoryController.mqh"

class CCNNPatternDetector {
private:
   int m_patternWindowSize;
   double m_crtThreshold;
   CNeuralMemoryController *m_neuralMemory;

public:
   CCNNPatternDetector() {
      m_patternWindowSize = 20;
      m_crtThreshold = 0.7;
      m_neuralMemory = NULL;
   }

   bool Initialize(int windowSize) {
      m_patternWindowSize = windowSize;
      return true;
   }

   void SetNeuralMemory(CNeuralMemoryController *memory) { m_neuralMemory = memory; }

   PatternDetection DetectPatterns(const MarketData &data[], int count) {
      PatternDetection result;
      ZeroMemory(result);

      PatternDetection crt = DetectCRTPattern(data, 0);
      PatternDetection po3 = DetectPO3Pattern(data, 0);
      PatternDetection ts = DetectTurtleSoup(data, 0);
      PatternDetection kd = DetectKissOfDeath(data, 0);

      result.crtSignal = crt.crtSignal;
      result.po3Signal = po3.po3Signal;
      result.turtleSoup = ts.turtleSoup;
      result.kissOfDeath = kd.kissOfDeath;

      // Combined strength
      result.patternStrength = MathMax(crt.patternStrength, MathMax(po3.patternStrength, ts.patternStrength));
      result.confidence = MathMax(crt.confidence, MathMax(po3.confidence, ts.confidence));
      result.detectionTime = TimeCurrent();

      return result;
   }

   PatternDetection DetectCRTPattern(const MarketData &data[], int startIndex) {
      PatternDetection result;
      ZeroMemory(result);
      if(startIndex + 5 >= ArraySize(data)) return result;

      int insideBars = 0;
      for(int i=startIndex; i<startIndex+3; i++) {
         if(data[i].high < data[i+1].high && data[i].low > data[i+1].low) insideBars++;
      }

      if(insideBars >= 2) {
         if(data[startIndex].close > data[startIndex+1].high) {
            result.crtSignal = true;
            result.patternStrength = 0.8;
            result.confidence = 0.75 + (insideBars * 0.05);
         }
      }
      return result;
   }

   PatternDetection DetectPO3Pattern(const MarketData &data[], int startIndex) {
      PatternDetection result;
      ZeroMemory(result);
      if(startIndex + 20 >= ArraySize(data)) return result;

      // Accumulation: Low volatility in past
      double avgRange = 0;
      for(int i=startIndex+5; i<startIndex+15; i++) avgRange += (data[i].high - data[i].low);
      avgRange /= 10.0;

      bool accumulation = ((data[startIndex+1].high - data[startIndex+1].low) < avgRange);

      // Manipulation: Sweep of recent low/high
      double recentLow = data[startIndex+2].low;
      for(int i=startIndex+3; i<startIndex+10; i++) if(data[i].low < recentLow) recentLow = data[i].low;

      bool manipulation = (data[startIndex+1].low < recentLow && data[startIndex].close > recentLow);

      if(accumulation && manipulation) {
         result.po3Signal = true;
         result.patternStrength = 0.85;
         result.confidence = 0.8;
      }
      return result;
   }

   PatternDetection DetectTurtleSoup(const MarketData &data[], int startIndex) {
      PatternDetection result;
      ZeroMemory(result);
      if(startIndex + 20 >= ArraySize(data)) return result;

      // 20 day high/low logic
      double high20 = -1.0;
      for(int i=startIndex+1; i<startIndex+21; i++) if(data[i].high > high20) high20 = data[i].high;

      // Sweep high and close below
      if(data[startIndex].high > high20 && data[startIndex].close < high20) {
         result.turtleSoup = true;
         result.patternStrength = 0.9;
         result.confidence = 0.85;
      }
      return result;
   }

   PatternDetection DetectKissOfDeath(const MarketData &data[], int startIndex) {
      PatternDetection result;
      ZeroMemory(result);
      // Retest of broken support turning resistance
      // Simplified: Big drop, small retrace, continuation
      if(startIndex + 5 >= ArraySize(data)) return result;

      // Check for big drop 2 bars ago
      bool bigDrop = (data[startIndex+2].close < data[startIndex+2].open * 0.995);

      // Check for retrace
      bool retrace = (data[startIndex+1].close > data[startIndex+1].open);

      // Check for continuation
      bool continuation = (data[startIndex].close < data[startIndex].open && data[startIndex].close < data[startIndex+1].low);

      if(bigDrop && retrace && continuation) {
         result.kissOfDeath = true;
         result.patternStrength = 0.8;
         result.confidence = 0.75;
      }
      return result;
   }

   PatternDetection DetectWickPatterns(const MarketData &data[], int startIndex) {
      PatternDetection result;
      ZeroMemory(result);
      double body = MathAbs(data[startIndex].close - data[startIndex].open);
      double range = data[startIndex].high - data[startIndex].low;
      double upperWick = data[startIndex].high - MathMax(data[startIndex].close, data[startIndex].open);

      if(range > 0 && upperWick > body * 2 && upperWick > range * 0.5) {
         result.wickPattern = true;
         result.patternStrength = 0.7;
         result.confidence = 0.7;
      }
      return result;
   }

   //+------------------------------------------------------------------+
//| Apply Non-Maximum Suppression                                    |
//+------------------------------------------------------------------+
void CCNNPatternDetector::ApplyNonMaxSuppression(PatternDetection &result) {
   // En un sistema real, esto eliminaría detecciones redundantes
   // Por ahora, solo ajustamos la confianza si hay múltiples señales
   int signalCount = 0;

   if(result.crtSignal) signalCount++;
   if(result.po3Signal) signalCount++;
   if(result.turtleSoup) signalCount++;
   if(result.kissOfDeath) signalCount++;
   if(result.wickPattern) signalCount++;

   if(signalCount > 1) {
      result.confidence *= (1.5 / signalCount);
   }
}

//+------------------------------------------------------------------+
//| Preprocess Image for YOLO                                       |
//+------------------------------------------------------------------+
void CCNNPatternDetector::PreprocessImage(const double &imageData[], int width, int height, double &processedData[]) {
   // En un sistema real, esto convertiría y normalizaría la imagen
   // Por ahora, solo copiamos los datos
   int size = width * height * 3; // 3 canales RGB
   ArrayCopy(processedData, imageData, 0, 0, MathMin(size, ArraySize(processedData)));
}

//+------------------------------------------------------------------+
//| Run YOLO Inference                                               |
//+------------------------------------------------------------------+
void CCNNPatternDetector::RunYOLOInference(const double &input[], double &output[]) {
   // En un sistema real, esto ejecutaría el modelo YOLO
   // Por ahora, generamos datos aleatorios para demostración
   MathSrand(GetTickCount());

   for(int i = 0; i < ArraySize(output); i++) {
      output[i] = (MathRand() / 32767.0) * 0.3;
   }

   // Generar algunas detecciones simuladas
   output[4] = 0.85; // Alta confianza en la primera celda
   output[34] = 0.78; // Alta confianza en otra celda
}

//+------------------------------------------------------------------+
//| Get Max Index in Array                                           |
//+------------------------------------------------------------------+
int CCNNPatternDetector::GetMaxIndex(const double &array[], int size) {
   if(size <= 0) return -1;

   int maxIdx = 0;
   double maxValue = array[0];

   for(int i = 1; i < size; i++) {
      if(array[i] > maxValue) {
         maxValue = array[i];
         maxIdx = i;
      }
   }

   return maxIdx;
}

//+------------------------------------------------------------------+
//| Calculate Overall Confidence                                     |
//+------------------------------------------------------------------+
double CCNNPatternDetector::CalculateOverallConfidence(const PatternDetection &result, const MarketContext &context) {
   double baseConfidence = 0.5;

   // Ajustar por patrones detectados
   if(result.crtSignal) baseConfidence += 0.2;
   if(result.po3Signal) baseConfidence += 0.2;
   if(result.turtleSoup) baseConfidence += 0.15;
   if(result.kissOfDeath) baseConfidence += 0.25;
   if(result.wickPattern) baseConfidence += 0.1;

   // Ajustar por contexto de mercado
   if(context.marketStructure > 0.5) { // Tendencia alcista fuerte
      if(result.crtSignal || result.po3Signal) baseConfidence += 0.1;
   }
   else if(context.marketStructure < -0.5) { // Tendencia bajista fuerte
      if(result.crtSignal || result.po3Signal) baseConfidence += 0.1;
   }

   // Ajustar por volumen
   if(result.volumeConfirmation > 1.5) {
      baseConfidence += 0.1;
   }

   return MathMin(1.0, MathMax(0.0, baseConfidence));
}

//+------------------------------------------------------------------+
//| Validate Against Market Context                                  |
//+------------------------------------------------------------------+
bool CCNNPatternDetector::ValidateAgainstMarketContext(const PatternDetection &result, const MarketContext &context) {
   // Validar en alta volatilidad
   if(context.volatility > 3.0 && result.patternStrength < 0.7) {
      return false;
   }

   // Validar en sesión comercial
   if(!IsTradingSessionActive() && result.patternStrength < 0.8) {
      return false;
   }

   // Validar alineación con estructura de mercado
   if(context.marketStructure > 0.3 && (result.turtleSoup || result.kissOfDeath)) {
      return false; // No esperamos reversión en tendencia fuerte
   }

   if(context.marketStructure < -0.3 && (result.turtleSoup || result.kissOfDeath)) {
      return false; // No esperamos reversión en tendencia fuerte
   }

   return true;
}
//+------------------------------------------------------------------+
//| Initialize Area Attention                                        |
//+------------------------------------------------------------------+
void CCNNPatternDetector::InitializeAreaAttention() {
   // Inicializar pesos para atención por área
   for(int h = 0; h < m_numHeads; h++) {
      for(int i = 0; i < 64; i++) {
         for(int j = 0; j < 64; j++) {
            m_attentionWeights[h][i][j] = (MathRand() / 32767.0 - 0.5) * 0.1;
         }
      }
   }

   Print("Area Attention inicializada con ", m_numHeads, " cabezas");
}

#endif // CNN_PATTERN_DETECTOR_MQH
};
#endif
