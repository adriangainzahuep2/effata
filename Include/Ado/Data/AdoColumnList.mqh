//+------------------------------------------------------------------+
//|                                                AdoColumnList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Arrays\List.mqh>
#include "AdoColumn.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian \xca\xeb\xe0\xf1\xf1, \xef\xf0\xe5\xe4\xf1\xf2\xe0\xe2\xeb\xff\xfe\xf9\xe8\xe9 \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xfe \xf1\xf2\xee\xeb\xe1\xf6\xee\xe2
///         \~english Represents columns collection
class CAdoColumnList : public CList
  {
public:
   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xee\xe1\xfa\xe5\xea\xf2 \xf2\xe8\xef\xe0 CAdoColumn. \xc2\xe8\xf0\xf2\xf3\xe0\xeb\xfc\xed\xfb\xe9 \xec\xe5\xf2\xee\xe4
   ///         \~english Creates new column. Virtual
   virtual CObject *CreateElement() { return new CAdoColumn(); }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf2\xe8\xef \xee\xe1\xfa\xe5\xea\xf2\xe0
   ///         \~english Gets object type
   virtual int Type() { return ADOTYPE_COLUMNLIST; }

   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf1\xf2\xee\xeb\xe1\xe5\xf6 \xef\xee \xe8\xed\xe4\xe5\xea\xf1\xf3
   ///         \~english Gets column by index
   CAdoColumn       *GetColumn(const int index);
   /// \brief  \~russian \xc2\xee\xe7\xe2\xf0\xe0\xf9\xe0\xe5\xf2 \xf1\xf2\xee\xeb\xe1\xe5\xf6 \xef\xee \xe8\xec\xe5\xed\xe8
   ///         \~english Gets column by name
   CAdoColumn       *GetColumn(const string name);

   /// \brief  \~russian \xd1\xee\xe7\xe4\xe0\xe5\xf2 \xe8 \xe4\xee\xe1\xe0\xe2\xeb\xff\xe5\xf2 \xea\xee\xeb\xed\xea\xf3 \xea \xea\xee\xeb\xeb\xe5\xea\xf6\xe8\xe8
   ///         \~english Creates and adds new column to the collection
   /// \~russian \param name \xc8\xec\xff \xf1\xf2\xee\xeb\xe1\xf6\xe0
   /// \~english \param name Column name
   /// \~russian \param type \xd2\xe8\xef \xf1\xf2\xee\xeb\xe1\xf6\xe0
   /// \~english \param type Column type
   CAdoColumn       *AddColumn(const string name,const ENUM_ADOTYPES type);
  };
//--------------------------------------------------------------------
CAdoColumn *CAdoColumnList::GetColumn(const int index)
  {
   return GetNodeAtIndex(index);
  }
//--------------------------------------------------------------------
CAdoColumn *CAdoColumnList::GetColumn(const string name)
  {
   for(int i=0; i<Total(); i++)
     {
      CAdoColumn *col=GetColumn(i);
      if(col!=NULL)
         if(col.ColumnName()==name)
            return col;
     }

   return NULL;
  }
//--------------------------------------------------------------------
CAdoColumn *CAdoColumnList::AddColumn(const string name,const ENUM_ADOTYPES type)
  {
   CAdoColumn *newCol=CreateElement();
   newCol.ColumnName(name);
   newCol.ColumnType(type);
   Add(newCol);
   return newCol;
  }
//+------------------------------------------------------------------+
