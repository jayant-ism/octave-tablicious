
function value =  csv2table(file_location) 
    [header , data , data_type] = csv_matrix([file_location]) ;
    value =  array2table(data);
endfunction  