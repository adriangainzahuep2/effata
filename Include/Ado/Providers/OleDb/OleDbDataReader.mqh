//+------------------------------------------------------------------+
//|                                              OleDbDataReader.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbDataReader.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1 \xe4\xeb\xff \xf7\xf2\xe5\xed\xe8\xff \xe4\xe0\xed\xed\xfb\xf5 \xe8\xe7 \xe8\xf1\xf2\xee\xf7\xed\xe8\xea\xe0 OLE DB \xe2 \xef\xf0\xff\xec\xee\xec \xed\xe0\xef\xf0\xe0\xe2\xeb\xe5\xed\xe8\xe8
///         \~english Reads a forward-only stream of rows from an OLE DB data source
class COleDbDataReader : public CDbDataReader
  {
public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english constructor
                     COleDbDataReader();
  };
//--------------------------------------------------------------------
COleDbDataReader::COleDbDataReader()
  {
   MqlTypeName("COleDbDataReader");
  }
//+------------------------------------------------------------------+
