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

%% Test simple case
%! assert (col2num ("a"), 1, 1e-16);

%% Test case insensitivity
%! assert (col2num ("A"), 1, 1e-16);

%% Test more complicated string
assert (col2num ("ydf"), 17010, 1e-16);

%% Again, test case insensitivity
assert (col2num ("Ydf"), 17010, 1e-16);
assert (col2num ("yDf"), 17010, 1e-16);
assert (col2num ("ydF"), 17010, 1e-16);
assert (col2num ("YDf"), 17010, 1e-16);
assert (col2num ("yDF"), 17010, 1e-16);
assert (col2num ("YdF"), 17010, 1e-16);
assert (col2num ("YDF"), 17010, 1e-16);

*/

#include <octave/oct.h>

DEFUN_DLD (col2num, args, nargout, 
          "-*- texinfo -*-\n"
          "@deftypefn {Loadable Function} {@var{N} = } col2num (@var{CIDX})\n"
       "\n"
       "Convert a spreadsheet column Id into a numerical column number. "
       "@end deftypefn") {

  /* Get arguments */
  const int nargin = args.length ();
  octave_value retval = -1;

  // Input check
  if (nargin != 1)
    {
      error ("col2num: exactly one input argument expected");
      return retval;
    }

  std::string cidx = args (0).string_value ();
  std::transform (cidx.begin (), cidx.end (), cidx.begin (), ::toupper);
  retval = 0;
  int dd;
  for (int ii=0, len = cidx.length (); ii < len; ii++)
    {
      dd = (int) (cidx[ii] - 64);
      retval = retval*26 + dd;
    }

  return retval;
  }