#include <iostream>
#include <octave/oct.h>
#include "csv_reader.h"
#include<vector>
#include "str-vec.h"



DEFUN_DLD (csv_matrix,  args, , "String Demo")
{

 // check if the data is provided or not 
 int nargin = args.length ();

  if (nargin != 1)
    print_usage ();

// convert the file location into the string 
  charMatrix ch = args(0).char_matrix_value ();
  std::string file_location  = ch.row_as_string(0) ;

//declare the data type  
csv_reader::csv_datatype table ;
table.read_record(file_location) ; 



octave_value_list  retval ; 
/*retur 

    header 
    data 
    data_type 
*/

octave_value_list  header_values , data , data_type;
long long int count = 0 ; 

for( auto headers : table.header_csv )
{
    //headers are an individual strings 
    header_values(count) = octave_value(headers , '\'') ; 
    count++ ; 

}

long long int number_rows = table.data.size() ,  number_columns = table.header_csv.size()   ;
for( long long int j = 0 ; j < number_columns ;j++) 
{
    octave_value_list  column ; 
    for(long long int  i =0 ; i< number_rows ;i++)
    {
        if(table.data[i][j].second == "std::string")
        column(i) =  octave_value(table.data[i][j].first , '\'' ) ;  // for string 
        else if(table.data[i][j].second == "std::float") 
        column(i) =  octave_value(table.data[i][j].first ) ; // for float 
        
    }
    data(j) = octave_value(column , false ) ;
}


for( long long int j = 0 ; j < number_columns ;j++) 
{
        data_type(j) =  octave_value(table.data[0][j].second , '\'' ) ; 
    
}

retval(0) =   octave_value(header_values , false ) ;
retval(1) =   octave_value(data , false ) ;
retval(2) =   octave_value(data_type , false ) ;
return retval ; 






}

