//+------------------------------------------------------------------+
//|                                             OleDbDataAdapter.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbDataAdapter.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1 \xf1\xeb\xf3\xe6\xe8\xf2 \xe4\xeb\xff \xe7\xe0\xef\xee\xed\xe5\xed\xe8\xff AdoTable \xe4\xe0\xed\xed\xfb\xec\xe8 \xe8\xe7 \xe8\xf1\xf2\xee\xf7\xed\xe8\xea\xe0 OLE DB
///         \~english Used for filling AdoTable from an OLE DB data source
class COleDbDataAdapter : public CDbDataAdapter
  {
public:
   /// \brief  \~russian \xea\xee\xed\xf1\xf2\xf0\xf3\xea\xf2\xee\xf0 \xea\xeb\xe0\xf1\xf1\xe0
   ///         \~english constructor
                     COleDbDataAdapter();
  };
//--------------------------------------------------------------------
COleDbDataAdapter::COleDbDataAdapter()
  {
   MqlTypeName("COleDbDataAdapter");
  }
//+------------------------------------------------------------------+
