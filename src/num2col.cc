// Copyright (C) 2014-2019 Philip Nienhuis
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

%% Simple case
assert (num2col (1), "A");

%% More complicated case
assert (num2col (17010), "YDF");

*/

#include <octave/oct.h>

DEFUN_DLD (num2col, args, nargout, 
          "-*- texinfo -*-\n"
          "@deftypefn {Loadable Function} {@var{CIDX} = } num2col (@var{N})\n"
       "\n"
       "Convert a numerical column number into a spreadsheet column Id. "
       "@end deftypefn") {

  /* Get arguments */
  const int nargin = args.length ();
  octave_value_list retval;
  std::string val = "";

  // Input check
  if (nargin != 1)
    {
      error ("num2col: exactly one input argument expected");
      return retval;
    }

  int nn = args (0).int_value ();
  int rmd;

  while (nn > 0)
    {
      rmd = nn % 26;
      if (rmd == 0)
        {
          rmd = 26;
        }
      val = std::string (1, rmd+64).append (val);
      nn = nn - rmd;
      nn = nn / 26;
    }

    return octave_value (val, '\'');
  }