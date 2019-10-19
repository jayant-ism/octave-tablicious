// Copyright (C) 2004-2019 Laurent Mazet <mazet@crm.mot.com>
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

#include <octave/oct.h>
#include <octave/Cell.h>

DEFUN_DLD (csvconcat, args, nargout,
           "-*- texinfo -*-\n"
           "@deftypefn {Loadable Function} {@var{str} = } csvconcat (@var{c})\n"
	   "@deftypefnx {Loadable Function} {@var{str} = } csvconcat (@var{c}, @var{sep})\n"
	   "@deftypefnx {Loadable Function} {@var{str} = } csvconcat (@var{c}, @var{sep}, @var{prot})\n"
	   "\n"
	   "Concatenate a cell into a CSV string or array of strings. "
	   "@var{sep} (character value) changes the character used to separate two fields. "
	   "The default value is a comma "
	   "(@code{,}). @var{prot} (character value) changes the character used to protect a string. "
	   "The default is a double quote (@code{\"}).\n"
           "@end deftypefn") {

  /* Check argument */
  if ((args.length() < 1) || (args.length() > 3)) {
    print_usage ();
    return octave_value();
  }

  /* Get arguments */
  Cell c = args(0).cell_value();

  std::string sep = (args.length() > 1) ? args(1).string_value() : ",";
  if (sep.length() != 1) {
    error("csvconcat: separator can only be one character\n");
    return octave_value();
  }

  std::string prot = (args.length() > 2) ? args(2).string_value() : "\"";
  if (prot.length() != 1) {
    error("csvconcat: protector can only be one character\n");
    return octave_value();
  }
  
  /* Concat a cell into a string */
  string_vector vec(c.rows());
  std::string word;

  /* For each element */
  for (int i=0, il=c.rows(); i<il; i++) {
    word = "";
    for (int j=0, jl=c.columns(); j<jl; j++) {
      
      /* Add separator */
      if (j != 0)
	word += sep;

      if (c(i, j).is_real_scalar()) {

	/* Output real value */
	char tmp[20];
	sprintf(tmp, "%g", c(i, j).double_value());
	word += tmp;
      }

      else if (c(i, j).is_string()) {
	/* Output string value */
	std::string str = c(i, j).string_value();
	if (str.find(sep) != str.npos) {
	  unsigned int pos = 0;
	  while ((pos=str.find(prot, pos)) != str.npos) {
	    str.replace(pos, 1, prot+prot);
	    pos += 2;
	  }
	  str = prot + str + prot;
	}
	word += str;
      }

      else {
	/* Output NaN value */
	warning ("csvconcat: empty cell or not a real or string value - converted to 'NaN'\n");
	word += "NaN";
      }
    }
    vec(i) = word;
  }
  
  return octave_value(vec);
}
