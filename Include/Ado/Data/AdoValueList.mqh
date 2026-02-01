//+------------------------------------------------------------------+
//|                                                 AdoValueList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Arrays\List.mqh>
#include "AdoValue.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xf1\xef\xe8\xf1\xee\xea CAdoValue
///         \~english Represents CAdoValue collection
class CAdoValueList : public CList
  {
public:
   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xee\xe1\xfa\xe5\xea\xf2 \xf2\xe8\xef\xe0 CAdoValue. \xc2\xe8\xf0\xf2\xf3\xe0\xeb\xfc\xed\xfb\xe9 \xec\xe5\xf2\xee\xe4
   ///         \~english Creates new value. Virtual
   virtual CObject *CreateElement() { return new CAdoValue(); }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf2\xe8\xef \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xe8
   ///         \~english Gets collection type
   virtual int Type() { return ADOTYPE_VALUELIST; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xe7\xed\xe0\xf7\xe5\xed\xe8\xe5 \xef\xee \xe8\xed\xe4\xe5\xea\xf1\xf3
   ///         \~english Gets value by index
   CAdoValue        *GetValue(const int index);
  };
//--------------------------------------------------------------------
CAdoValue *CAdoValueList::GetValue(const int index)
  {
   return GetNodeAtIndex(index);
  }
//+------------------------------------------------------------------+
