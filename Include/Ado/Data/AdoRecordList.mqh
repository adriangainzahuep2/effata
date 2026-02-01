//+------------------------------------------------------------------+
//|                                                AdoRecordList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Arrays\List.mqh>
#include "AdoRecord.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xe7\xe0\xef\xe8\xf1\xe5\xe9
///         \~english Represents row list
class CAdoRecordList : public CList
  {
public:
   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xee\xe1\xfa\xe5\xea\xf2 \xf2\xe8\xef\xe0 CAdoRecord. \xc2\xe8\xf0\xf2\xf3\xe0\xeb\xfc\xed\xfb\xe9 \xec\xe5\xf2\xee\xe4
   ///         \~english Creates new row. Virtual
   virtual CObject *CreateElement() { return new CAdoRecord(); }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf2\xe8\xef \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xe8
   ///         \~english Gets collection type
   virtual int Type() { return ADOTYPE_RECORDLIST; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xe7\xe0\xef\xe8\xf1\xfc \xef\xee \xe8\xed\xe4\xe5\xea\xf1\xf3
   ///         \~english Gets row by index
   CAdoRecord       *GetRecord(const int index);
  };
//--------------------------------------------------------------------
CAdoRecord *CAdoRecordList::GetRecord(const int index)
  {
   return GetNodeAtIndex(index);
  }
//+------------------------------------------------------------------+
