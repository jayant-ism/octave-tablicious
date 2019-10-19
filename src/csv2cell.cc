// Copyright (C) 2004-2019 Laurent Mazet <mazet@crm.mot.com>
// Copyright (C) 2014-2019 Philip Nienhuis <prnienhuis@users.sf.net>
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

%% Check EOF w/o preceding EOL & text fields in 1st column disguised as numeric str
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "\"1\"");
%! fclose (fid);
%! s = csv2cell (f){1};
%! unlink (f);
%! assert (s, "1");

%!test
%! f = tempname ();
%! csvwrite(f, "\"1\",2", "DELIMITER", "");
%! s = csv2cell(f);
%! unlink (f);
%! assert (s{1}, "1");
%! assert (s{2}, 2);

%!test
%! f = tempname ();
%! csvwrite(f, "3,\"1\"", "DELIMITER", "");
%! s = csv2cell(f);
%! unlink (f);
%! assert (s{1}, 3);

%! assert (s{2}, "1");

%% Check proper string protection
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! str = ['01/03/2012,"H (Mar, 12)",26.750000,2584' "\n"];
%! str = [str '"01/04/2012",H (Mar, 12),2330' "\n"];
%! str = [str '"01/05/2012","H (Mar 12)",26.000000,3198' "\n"];
%! str = [str '01/06/2012,H (Mar 12),25.500000,3045' "\n"];
%! fprintf (fid, str);
%! fclose (fid);
%! s = csv2cell (f);
%! unlink (f);
%! assert (isnumeric ([s{1:4, 4}]), true);
%! ddd = datenum (s{2,1}, "dd/mm/yyyy") - datenum (s{1,1}, "dd/mm/yyyy");
%! assert (ddd, 31.0, 1e-5);
%! assert (iscellstr (s(1:4, 2)), true);
%! assert (isnumeric ([s{1, 3} s{3:4, 3}]), true);
%! assert (ischar (s{2, 3}), true);

%% Check separator and string protection arguments
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! str = ['01/03/2012;$H (Mar; 12)$;26.750000;2584' "\n"];
%! str = [str '$01/04/2012$;H (Mar; 12);2330' "\n"];
%! str = [str '$01/05/2012$;$H (Mar 12)$;26.000000;3198' "\n"];
%! str = [str '01/06/2012;H (Mar 12);25.500000;3045' "\n"];
%! fprintf (fid, str);
%! fclose (fid);
%! s = csv2cell (f, ";", "$");
%! unlink (f);
%! assert (isnumeric ([s{1:4, 4}]), true);
%! ddd = datenum (s{2,1}, "dd/mm/yyyy") - datenum (s{1,1}, "dd/mm/yyyy");
%! assert (ddd, 31.0, 1e-5);
%! assert (iscellstr (s(1:4, 2)), true);
%! assert (isnumeric ([s{1, 3} s{3:4, 3}]), true);
%! assert (ischar (s{2, 3}), true);

%% Check headerlines,
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "A, B\n 1, 2\n 3, 4\n 5, 6\n");
%! fclose (fid);
%! s = csv2cell (f);
%! assert (iscellstr (s(1, :)), true);
%! assert (cell2mat (s(2:end, :)), [1 2; 3 4; 5 6], 1e-10);
%! s = csv2cell (f, 1);
%! assert (cell2mat (s), [1 2; 3 4; 5 6], 1e-10);
%! s = csv2cell (f, 3);
%! assert (cell2mat (s), [5 6], 1e-10);
%! s = csv2cell (f, -3);
%! assert (iscellstr (s(1, :)), true);
%! assert (cell2mat (s(2:end, :)), [1 2; 3 4; 5 6], 1e-10);
%! s = csv2cell (f, 5);
%! assert (iscell (s) && isempty (s));
%! unlink (f);

%% Check surplus headerlines w EOF before final EOL
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "A, B\n 1, 2\n 3, 4\n 5, 6");
%! fclose (fid);
%! s = csv2cell (f, 10);
%! unlink (f);
%! assert (iscell (s) && isempty (s));

%% Check if csv2cell ignores trailing CR's in cells
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "a\r\n1\r\nc\n4\n");
%! fclose (fid);
%! s = csv2cell (f);
%! unlink (f);
%! assert (uint16 ([s{1} s{3}]), uint16([97 99]));
%! assert ([s{2} s{4}], [1 4]);

%% Check spreadsheet style range arg
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, '1,2,3\n11,12,13,"14",15,16\n,22\n31,32,"33",34\n41,"42",,44,45\n51,52,53');
%! fclose (fid);
%! s = csv2cell (f, "b2:e5");
%! unlink (f);
%! assert (cell2mat(s([1; 2; 3; 5; 11; 13])), [12; 22; 32; 13; 34; 15], eps);
%! assert (s([7; 9]), {"33"; "14"});
%! assert (all (cellfun (@isempty, s([6, 8, 10, 14:15]))));

%% Check files with uneven line length w/o range arg
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, 'a,b,c,d,e,f\n11,12,13,"14",15,16\n,22\n31,32,"33",34\n41,"42",,44,45\n51,52,53');
%! fclose (fid);
%! s = csv2cell (f);
%! unlink (f);
%! assert (size (s), [6 6]);
%! assert (cell2mat(s([2, 4:6, 8:10, 12, 14, 18, 22:23, 26, 29, 32])), ...
%!         [11, 31, 41, 51, 12, 22, 32, 52, 13, 53, 34, 44, 15, 45, 16], eps);
%! assert ([s(1,:), s(11), s(16), s(20)], {"a", "b", "c", "d", "e", "f", ...
%!                                         "42", "33", "14"});
%! assert (all (cellfun (@isempty, s([3, 15, 17, 21, 24, 27:28, 30, 33:36]))));

%% Check ":" separator
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "1:2\n3:4\n5:6");
%! fclose (fid);
%! s = csv2cell (f, ":");
%! unlink (f);
%! assert (cell2mat(s), [1, 2; 3, 4; 5, 6], eps);

%% Check ":" separator and spreadsheet style range combi
%!test
%! f = tempname ();
%! fid = fopen (f, 'w+');
%! fprintf (fid, "1:2:3\n4:5:6\n7:8:9\n");
%! fclose (fid);
%! s = csv2cell (f, "b2:c3", ":");
%! unlink (f);
%! assert (cell2mat(s), [5, 6; 8,9], eps);

%% Errors
%!error <not enough input> csv2cell ();
%!error <cannot open file ___.csv> csv2cell ("___.csv");
%!error <illegal character> csv2cell ("file.csv", "a&:f3");
%!error <illegal cell range> csv2cell ("file.csv", "b2:a1");
%!error <separator value can only be> csv2cell ("f.csv", ",,");
%!error <protector value can be only> csv2cell ("f.csv", ",", "[]");

*/

#include <fstream>
#include <iostream>
#include <stdint.h>

#include <octave/oct.h>
#include <octave/Cell.h>
#include <octave/ov.h>
#include <octave/file-ops.h>

#include "config.h"

#define MAXSTRINGLENGTH 4096

DEFUN_DLD (csv2cell, args, nargout, 
          "-*- texinfo -*-\n\
@deftypefn {Loadable Function} {@var{c} = } csv2cell (@var{file})\n\
@deftypefnx {Loadable Function} {@var{c} = } csv2cell (@var{file}, @var{sep})\n\
@deftypefnx {Loadable Function} {@var{c} = } csv2cell (@var{file}, @var{sep}, @var{prot})\n\
@deftypefnx {Loadable Function} {@var{c} = } csv2cell (@var{file}, @var{hl}, ...)\n\
@deftypefnx {Loadable Function} {@var{c} = } csv2cell (@var{file}, @var{range}, ...)\n\
\n\
Read a CSV (Comma Separated Values) file and convert it into a cell \
array.\n\
\n\
@var{sep} (a character value) changes the character used to separate \
two fields. The default value is a comma (@code{,}).\n\
\n\
@var{prot} (a character value) changes the character used to protect \
a string. The default is a double quote (@code{\"}).\n\
\n\
Optional argument @var{hl} (a numeric value >= 0) is the number of \
headerlines to skip; negative values are ignored. If @var{hl} is \
equal to or larger than the total number of lines in the file, no \
data are read and an empty cell array is returned.\n\
\n\
Alternatively, optional argument @var{range} can be specified as a \
spreadsheet-style cell range to specify a block of fields to be \
returned in @var{c}.  If the specified column range reaches beyond \
the number of fields on a line, the output cell array is padded with \
empty string values.  If the specified row range exceeds the number \
of lines in the \
file, the range is silently truncated to match the number of lines \
per file.\n\
\n\
If no range argument is supplied, csv2cell assumes the first line \
contains column headers and the number of fields in the first line is \
supposed to be the number of columns in the output array.  A warning \
is emitted then if any data line contains more fields than the header \
line.\n\
\n\
Note: newline characters in fields (i.e., multi-line text fields) are not \
allowed.\n\
\n\
The maximum line width of the csv file is set to 4096 characters.\n\
(This is also the theoretical maximum number of columns in the data \n\
if all fields are empty, i.e., a line containing just 4096 consecutive \n\
separators.)\n\
@end deftypefn") {

  /* Get arguments */
  const int nargin = args.length ();
  octave_value_list retval;
  if (nargin == 0)
    {
      error ("csv2cell: not enough input arguments");
      return retval;
    }
    
  const std::string file = octave::sys::file_ops::tilde_expand (args (0).string_value ());

  /* Look if first arg after filename = numeric. If yes => headerlines */
  long hlines = (nargin > 1 && args(1).OV_ISNUMERIC () ? args(1).long_value() : 0);
  int arg_sh = (nargin > 1 && args(1).OV_ISNUMERIC () ? 1 : 0);

  bool lr = false;
  int lcol = 1;
  int rcol = 0;
  // int ipos = 1;
  int icol = 0;
  long irow = 0;
  long brow = 0;

  if (nargin > 1 && ! arg_sh)
    {
      std::string addr = args(1).string_value ();
      std::transform (addr.begin (), addr.end (), addr.begin (), ::toupper);
      size_t smcln = addr.find (":");
      if (addr.size () > 1 && smcln != std::string::npos)
        {
          // Seems to be an address
          arg_sh = 1;
          size_t addr_len = addr.size ();
          size_t ii = 0;
          int dc;
          long dr;
          while (ii < addr_len)
            {
              switch (addr[ii])
                {
                  case '0': case '1': case '2': case '3': case '4':
                  case '5': case '6': case '7': case '8': case '9':
                    {
                      irow = irow * 10;
                      dr = (long) (addr[ii] - 48);
                      irow = irow + dr;
                      break;
                    }
                  case 'A': case 'B': case 'C': case 'D': case 'E':
                  case 'F': case 'G': case 'H': case 'I': case 'J':
                  case 'K': case 'L': case 'M': case 'N': case 'O':
                  case 'P': case 'Q': case 'R': case 'S': case 'T':
                  case 'U': case 'V': case 'W': case 'X': case 'Y':
                  case 'Z':
                    {
                      icol = icol * 26;
                      dc = (int) (addr[ii] - 64);
                      icol = icol + dc;
                      break;
                    }
                  case ':':
                    {
                      lcol = icol;
                      icol = 0;
                      // ipos = 1;
                      hlines = irow - 1;
                      irow = 0;
                      lr = true;
                      break;
                    }
                  default:
                    {
                      // Assume it's a plain letter a-z
                      error ("csv2cell: illegal character in address argument");
                      break;
                    }
                }
              ++ii;
            }
        if (lcol < 1)
          lcol = 1;
        rcol = icol;
        brow = irow;
        if (rcol < lcol || brow < hlines + 1 || lcol < 1 || hlines < 0)
          error ("csv2cell: illegal cell range specified");
        if (rcol > MAXSTRINGLENGTH + 1)
          error ("csv2cell: nr. of columns too large for buffer size");
      }
    }

  const std::string _sep = (nargin > arg_sh + 1) ? args(arg_sh + 1).string_value () : ",";
  if (_sep.length() != 1)
    {
      error ("csv2cell: separator value can only be one character\n");
      return retval;
    }
  char sep = _sep[0];

  const std::string _prot = (nargin > arg_sh + 2) ? args(arg_sh + 2).string_value () : "\"";
  if (_prot.length() != 1)
    {
      error ("csv2cell: protector value can be only one character\n");
      return retval;
    }
  char prot = _prot[0];

  /* Open file */
  std::ifstream fd (file.c_str ());
  if (!fd.is_open ())
    {
      error ("csv2cell: cannot open file %s for reading\n", file.c_str());
      return retval;
    }
  fd.seekg (0, std::ios::end);
  long fdend = fd.tellg ();
  fd.seekg (0, std::ios::beg);

  if (fd.tellg () >= fdend)
    return octave_value (Cell (0, 0));

  /* Buffers */
  char line [MAXSTRINGLENGTH];
  std::string str, word;
  bool inside = false;

  /* Read headerlines */
  for (long ii=0; ii < hlines; ii++)
    {
      fd.getline (line, MAXSTRINGLENGTH);
      if (fd.tellg () >= fdend || fd.fail ())
        return octave_value (Cell (0, 0));
    }

  /* Read a first data line */
  str = "";
  fd.getline (line, MAXSTRINGLENGTH);
  while (fd.fail ())
    {
      fd.clear ();
      str += line;
      fd.getline (line, MAXSTRINGLENGTH);
    }
  str += line;

  /* Parse first line to get number of columns */
  int nbcolumns = 0;
  for (int i = 0, len = str.length (); i <= len; i++)
    if (i == len || ((str[i] == sep || str[i] == 10) && ! inside))
      nbcolumns++;
    else if ((inside) && (str[i] == prot) && ((i+1 < len) && (str[i+1] == prot)))
      ++i;
    else if (str[i] == prot)
      inside = !inside;

  /* Read all the file to get number of rows */
  long nbrows = 1;
  while (fd.tellg () <= fdend && fd.peek () != EOF)
    {
      fd.getline (line, MAXSTRINGLENGTH);
      while (fd.fail () && fd.peek() != EOF)
        {
          fd.clear ();
          fd.getline (line, MAXSTRINGLENGTH);
        }
      nbrows++;
    }
  fd.clear();

  /* In case of address range, fix up nbrows */
  if (lr && nbrows + hlines > brow)
      nbrows = brow - hlines;

  /* Rewind */
  fd.seekg (0, std::ios::beg);
  if (!fd.good ())
    {
      error ("csv2cell: cannot reread %s\n", file.c_str ());
      return retval;
    }

  /* Again, read headerlines */
  for (long ii = 0; ii < hlines; ii++)
    {
        fd.getline (line, MAXSTRINGLENGTH);
    }

  /* Read all the file until the end */
  int ncols;
  if (lr)
    ncols = rcol - lcol + 1;
  else
    {
      rcol = nbcolumns;
      ncols = nbcolumns;
    }

  Cell c (nbrows, ncols);
  // Initialize c to be able to cope with heterogeneous line length csv's
  for (long i = 0; i < ncols; i++)
    for (long j = 0; j < nbrows; j++)
      c(j, i) = "";
      // c(j, i) = octave::numeric_limits<double>::NaN ();

  bool line_too_long = false;
  for (long i = 0; i < nbrows; i++)
    {
      /* Read a line */
      str = "";
      fd.getline (line, MAXSTRINGLENGTH);
      while (fd.fail ())
        {
          fd.clear ();
          str += line;
          fd.getline (line, MAXSTRINGLENGTH);
        }
      str += line;

      /* Explode a line into a sub cell */
      word = "";
      // inside = (str[0] == prot);
      inside = false;
      int j = 0;
      // Keep track of when just read, but not yet copied field, was inside (text)
      bool oinside = false;
      int len = str.length ();
      for (int k = 0; k <= len; k++)
        {
          if (((k == len) || (str[k] == sep)) && (!inside))
            {

            /* Check number of columns */
            if (!lr && !line_too_long && j == nbcolumns)
              {
                line_too_long = true;
                warning ("csv2cell: line(s) found with more fields than in headerline");
                break;
              }
            /* Check for last char to be 13 (CR) and remove if found */
            if (word.length () && word[word.length ()-1] == char(13))
                word.resize (word.size () - 1);
            /* Check if scalar */
            const char *word_str = word.c_str ();
            char *err;
            double val = strtod (word_str, &err);
            /* Store into the cell; check if it is in address argument range*/
            if ((j+1 >= lcol && j < rcol))
              {
                c(i, j-lcol+1) = ((word == "") || oinside || (err != word_str+word.length())) ?
                         octave_value (word) : octave_value (val);
              }
            j++;
            word = "";
            oinside = false;
          }
          else if ((inside) && (str[k] == prot) && ((k+1 < len) && (str[k+1] == prot)))
            {
              /* Inside a string */
              word += prot;
              ++k;
            }
          else if (str[k] == prot)
            {
              /* Changing */
              oinside = inside;
              inside = !inside;
            }
          else
            word += str[k];
        }
    }

  /* Close file */
  fd.close ();

  retval (0) = c;
  return retval;
}
