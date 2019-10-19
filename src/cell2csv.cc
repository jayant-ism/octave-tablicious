// Copyright (C) 2004-2019 Laurent Mazet <mazet@crm.mot.com>
// Copyright (C) 2016-2019 Philip Nienhuis <prnienhuis@users.sf.net>  
//
// This program is free software; you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program; if not, see <http://www.gnu.org/licenses/>.

/*

%% Straightforward performance
%!test
%! arr = arr1 = num2cell (randn (3, 3));
%! for ii=1:size (arr, 1)
%!   arr1(ii, ii) = sprintf ("\"Val = %f\"", arr{ii, ii});
%! endfor
%! f = tempname();
%! cell2csv (f, arr1);
%! arr2 = csv2cell (f);
%! unlink (f);
%! idx = find (cellfun ("ischar", arr2));
%! arr2(idx) = cellfun (@(x) str2double(strrep(x, "Val = ", "")), arr2(idx), "Uni", false);
%! assert (arr, arr2, 1e-5);

%% Test with SEP and PROT args
%!test
%! arr = arr1 = num2cell (randn (3, 3));
%! for ii=1:size (arr, 1)
%!   arr1(ii, ii) = sprintf ("Val = %f", arr{ii, ii});
%! endfor
%! arr1(2, 2) = [arr1{2, 2} ";"];
%! f = tempname();
%! cell2csv (f, arr1, ";", "&");
%! arr2 = csv2cell (f, ";", "&");
%! unlink (f);
%! assert (arr2{2, 2}(end), ";");
%! arr2(2, 2) = strrep (arr2{2, 2}, ";", "");
%! idx = find (cellfun ("ischar", arr2));
%! arr2(idx) = cellfun (@(x) str2double(strrep(x, "Val = ", "")), arr2(idx), "Uni", false);
%! assert (arr, arr2, 1e-5);

*/

#include <fstream>
#include <stdint.h>

#include <octave/oct.h>
#include <octave/Cell.h>

#include "config.h"

DEFUN_DLD (cell2csv, args, nargout,
          "-*- texinfo -*-\n"
          "@deftypefn {Loadable Function} {} cell2csv (@var{file}, @var{c})\n"
          "@deftypefnx {Loadable Function} {} cell2csv (@var{file}, @var{c}, @var{sep})\n"
          "@deftypefnx {Loadable Function} {} cell2csv (@var{file}, @var{c}, @var{sep}, @var{prot})\n"
          "\n"
          "Create a CSV file from a cell array. "
          "@var{sep} (character value) changes the character used to separate two fields. "
          "The default value is a comma "
          "(@code{,}). @var{prot} (character value) changes the character used to protect a string. "
          "Default value is a double quote (@code{\"}).\n"
          "@end deftypefn") {

  /* Check argument */
  if ((args.length() < 2) || (args.length() > 4)) {
    print_usage ();
    return octave_value();
  }

  /* Get arguments */
  std::string file = args(0).string_value();

  Cell c = args(1).cell_value();

  std::string sep = (args.length() > 2) ? args(2).string_value() : ",";
  if (sep.length() != 1) {
    error("cell2csv: separator can only be one character\n");
    return octave_value();
  }

  std::string prot = (args.length() > 3) ? args(3).string_value() : "\"";
  if (prot.length() != 1) {
    error("cell2csv: protector can only be one character\n");
    return octave_value();
  }

  /* Open file */
  std::ofstream fd(file.c_str());
  if (!fd.is_open()) {
    error("cell2csv: cannot open file %s for writing\n", file.c_str());
    return octave_value();
  }

  /* Concat a cell into a string */
  std::string word;

  /* For each element */
  for (int i=0, il=c.rows(); i<il; i++) {
   
    for (int j=0, jl=c.columns(); j<jl; j++) {
      word = "";
      
      /* Add separator */
      if (j != 0)
        word += sep;

      if (c(i, j).is_real_scalar()) {

        /* Output real value */
        char tmp[30];
        sprintf(tmp, "%.15g", c(i, j).double_value());
        word += tmp;
      }

      else if (c(i, j).is_string()) {
        /* Output string value */
        std::string str = c(i, j).string_value();
        if (str.find(sep) != str.npos) {
          size_t pos = 0;
          while ((pos=str.find(prot, pos)) != str.npos) {
            str.replace(pos, 1, prot+prot);
            pos += 2;
          }
          str = prot + str + prot;
        }
        word += str;
      }

      else if (!c(i, j).OV_ISEMPTY ()) {
        /* Output NaN value */
        warning ("cell2csv: empty cell or not a real or a string value - converted to 'NaN'\n");
        word += "NaN";
      }

      fd << word;
    }

    /* Add end of line */
    fd << std::endl;
  }

  /* Close file */
  fd.close();

  return octave_value();
}
