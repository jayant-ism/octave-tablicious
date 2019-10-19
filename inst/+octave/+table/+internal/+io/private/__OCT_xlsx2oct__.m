## Copyright (C) 2013-2019 Markus Bergholz
## Parts Copyright (C) 2013-2019 Philip Nienhuis
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, see
## <http://www.gnu.org/licenses/>.

## -*- texinfo -*- 
## @deftypefn {Function File} [ @var{raw}, @var{xls}, @var rstatus} ] = __OCT_xlsx2oct__ (@var{xlsx}, @var{wsh}, @var{range}, @spsh_opts)
## Internal function for reading data from an xlsx worksheet
##
## @seealso{}
## @end deftypefn

## Author: Markus Bergholz <markuman+xlsread@gmail.com>
## Created: 2013-10-04

function [ raw, xls, rstatus ] = __OCT_xlsx2oct__ (xls, wsh, crange="", spsh_opts)

  rstatus = 0;
  ## spsh_opts is guaranteed to be filled by caller

  ## If a worksheet if given, check if it's given by a name (string) or a number
  if (ischar (wsh))
    ## Search for requested sheet name
    id = find (strcmp (xls.sheets.sh_names, wsh));
    if (isempty (id))
      error ("xls2oct: cannot find sheet '%s' in file %s\n", wsh, xls.filename);
    else
      wsh = id;
    endif
  elseif (wsh > numel (xls.sheets.sh_names))
    error ("xls2oct: worksheet number %d > number of worksheets in file (%d)\n", wsh, numel (xls.sheets.sh_names));
  elseif (wsh < 1)
    error ("xls2oct: illegal worksheet number (%d)\n", wsh);
  endif
  ## Check if it's a worksheet and translate wsh to shId
  if (xls.sheets.type(wsh) != 1)
    warning ("xls2oct: sheet %d is not a worksheet\n", wsh);
    raw = {};
    return
  else
    wsh = xls.sheets.shId(wsh);
  endif

  ## Prepare to open requested worksheet file in subdir xl/ . 
  ## Note: Windows accepts forward slashes
  rawsheet = fopen (sprintf ('%s/xl/worksheets/sheet%d.xml', xls.workbook, wsh));
  if (rawsheet <= 0)
    # Try to open sheet from r:id in worksheets.rels.xml
    wsh       = xls.sheets.rels(xls.sheets.rels(:, 1) == id, 2);
    rawsheet  = fopen (sprintf ('%s/xl/worksheets/sheet%d.xml', xls.workbook, wsh));
    if (rawsheet <= 0)
      error ("Couldn't open worksheet xml file sheet%d.xml\n", wsh);
    endif
  else
    ## Get data
    rawdata = fread (rawsheet, "char=>char").';
    fclose (rawsheet);
    ## Strings
    try
      fid = fopen (sprintf ("%s/xl/sharedStrings.xml", xls.workbook));
      strings = fread (fid, "char=>char").';
      fclose (fid);
    catch
      ## No sharedStrings.xml; implies no "fixed" strings (computed strings can
      ## still be present)
      strings = "";
    end_try_catch
  endif

  ## General note for tuning: '"([^"]*)"' (w/o single quotes) could be faster
  ## than '"(.*?)"'
  ## (http://stackoverflow.com/questions/2503413/regular-expression-to-stop-at-first-match comment #7)

  ## As to requested subranges: it's complicated to extract just part of a sheet;
  ## either way the entire sheet would need to be scanned for cell addresses
  ## before one can know what part of the sheet XML the requested range lives.
  ## In addition the endpoint cells of that range may not exist in the sheet XML
  ## (e.g., if they're empty).
  ## So we read *all* data and in the end just return the requested rectangle.

  ## In below regexps, we ignore "cm"  and "ph" tags immediately after <c and
  ## a "vm" tag immediately after <t> tag. As soon as we hit them in the wild
  ## these can be added (at the cost of speed performance).

  ## Get cell addresses and contents of t=".." tags, "<f>", "<v>" and "<is>"
  ## nodes, optionally just placeholders 
  val = regexp (rawdata, '<c r="(\w+)"(?:[^t>]*(>)|(?:[^t>]*t="(\w+)")>)(?:<f.+?(?:</f>|/>))?(?:<v(?:[^>]*)>([^<]*)</v>|<is><t>([^<]*)</t></is>|<v/>([^<]*))', "tokens");
  ## <inlineStr>: <is><t>(.*?)</t></is>  ## formula: <f>..</f>
  if (any (cellfun (@length, val) != 3))
    warning ("Error reading data from sheet %d", wsh);
    val = cell (0, 3);
  elseif (! isempty (val))
    val = cat (1, val{:});

    warning ("off", "legacy-function", "local");
    ## Booleans
##    idx = strmatch ("b", val(:, 2));
    idx = find (strncmp ("b", val(:, 2), 1));
    if (! isempty (idx))
      id = find (str2double (val(idx, 3)));
      val(idx, 3) = false;
      val(idx(id), 3) = true;
    endif

    ## Numeric data
##    idx = strmatch (">", val(:, 2));
    idx = find (strncmp (">", val(:, 2), 1));
    idx = [ idx find(strncmp ("n", val(:, 2), 1)) ];
    if (! isempty (idx))
      val(idx, 3) = num2cell (str2double (val(idx, 3)));
    endif

    ## Date / time
##    idx = strmatch ("d", val(:, 2));
    idx = find (strncmp ("d", val(:, 2), 1));
    ## Process date nodes
    if (! isempty (idx))
      val(idx, 3) = num2cell (datenum(val(:, 3)), "yyyy-mm-ddTHH:MM");
    endif

    ## 2.A. Formula strings
    if (spsh_opts.formulas_as_text)
      ## Drop t="str" entries. The formula node contents will be catched later
##      idx = strmatch ("str", val(:, 2), "exact");
      idx = find (strcmp ("str", val(:, 2)));
      val(idx, :) = [];
    endif

    ## 2.B. Shared strings
    ## Don't mix with t="str" entries => "exact" option
##    idx = strmatch ("s", val(:, 2), "exact");
    idx = find (strcmp ("s", val(:, 2)));
    if (! isempty (strings) && ! isempty (idx))
      ## Extract string values. May be much more than present in current sheet
      strings = regexp (strings, '<si[^>]*>.*?</si>', "match"); 
      ctext = cell (numel (strings), 1);
      if (! isempty (strings))
        for n = 1:numel (strings)
          ctext{n, 1} = cell2mat (cell2mat (regexp (strings{1, n}, '<t[^>]*>(.*?)</t>', "tokens")));
        end
        ## Get actual values. Watch out for empty strings
        val(idx, 3) = ctext(str2double (val(idx, 3)) + 1, 1);
        ids = cellfun (@isempty, val(idx, 3));
        if (any (ids))
          vals(idx(ids)) = {""};
        endif
      endif
    endif

    ## 2.C. Inline strings
    ## No need to process them, they're already catched as strings

    clear idx;
  endif

  ## 2. String / text formulas (cached results are in this sheet; fixed strings
  ## in <sharedStrings.xml>)
  ## 2.A Formulas
  if (spsh_opts.formulas_as_text)
    ## Get formulas themselves as text strings. Formulas can have a
    ## 't="str"' attribute. Keep starting '>' for next line
    ## FIXME: repeated formulas spanning several cells are not processed yet
    ##        (see bug #51512)
    valf = regexp (rawdata, '<c r="(\w+)"(?:[^t]*?(>)|(?:[^t>]*?t="(\w+)?")>)<f.*?(>.*?)</f>', "tokens");
    if (any (cellfun (@length, valf) != 3))
      warning ("Error reading formula data from sheet %d", wsh);
      valf = cell (0, 3);
    elseif (! isempty (valf))
      valf = cat (1, valf{:});
      ##  Formulas start with '=' so:
      valf(:, 3) = regexprep (valf(:, 3), "^>", "=");
      val = [val; valf];
    endif
    clear valf;
  endif

  ## If val is empty, sheet is empty
  if (isempty (val))
    xls.limits = [];
    raw = {};
    return
  endif

 ## 3. Prepare for assigning extracted values to output cell array
  ## Get the row numbers (currently supported from 1 to 999999)
  vi.row = str2double (cell2mat (regexp (val(:, 1), '(\d+|\d+\d+|\d+\d+\d+|\d+\d+\d+\d+|\d+\d+\d+\d+\+d|\d+\d+\d+\d+\d+\d+)?', "match"))')';

  ## Get the column characters (A to ZZZ) (that are more than 18k supported cols)
  vi.alph = cell2mat (regexp (val(:, 1), '([A-Za-z]+|[A-Za-z]+[A-Za-z]+|[A-Za-z]+[A-Za-z]+[A-Za-z]+)?', "match"));

  idx.all = val(:, 1);
  if (0 < numel (idx.all))
    idx.num = str2double (cell2mat (regexp (idx.all, '(\d+|\d+\d+|\d+\d+\d+|\d+\d+\d+\d+|\d+\d+\d+\d+\+d|\d+\d+\d+\d+\d+\d+)?', "match"))')';
    idx.alph = cell2mat (regexp (idx.all, '([A-Za-z]+|[A-Za-z]+[A-Za-z]+|[A-Za-z]+[A-Za-z]+[A-Za-z]+)?', "match"));
    idx.alph = double (cell2mat (cellfun (@col2num, vi.alph, "UniformOutput", 0)));
  else
    ## To prevent warnings or errors while calculating corresponding NaN matrix
    idx.num = [];
    idx.alph = [];
  end
  ## Transform column character to column number
  ## A -> 1; C -> 3, AB -> 28 ...
  vi.col = double (cell2mat (cellfun (@col2num, vi.alph, "UniformOutput", 0)));

  ## Find data rectangle limits
  idx.mincol = min ([idx.alph; vi.col]);
  idx.minrow = min ([idx.num;  vi.row]);
  idx.maxrow = max ([idx.num;  vi.row]);
  idx.maxcol = max ([idx.alph; vi.col]);

  ## Convey limits of data rectangle to xls2oct. Must be done here as first start
  xls.limits = [idx.mincol, idx.maxcol; idx.minrow, idx.maxrow];

  ## column adjustment when first number or formula doesn't begin in first column
  if (1 < idx.mincol)
        vi.col = vi.col - (idx.mincol - 1);
  endif
  ## row adjustment when first number or formula doesn't begin in first row
  if (1 < idx.minrow)
        vi.row = vi.row - (idx.minrow - 1);
  endif
  ## Initialize output cell array
  raw = cell (idx.maxrow - idx.minrow + 1, idx.maxcol - idx.mincol + 1);

  ## get logical indices for 'val' from 'valraw' positions in NaN matrix
  vi.idx = sub2ind (size (raw), (vi.row), (vi.col));
  ## set values to the corresponding indices in final cell matrix
  raw(vi.idx) = val(:, 3);

  ## Process requested cell range argument
  if (! isempty (crange))
    ## Extract only the requested cell rectangle (see comments higher up)
    [~, nr, nc, tr, lc] = parse_sp_range (crange);
    xls.limits = [max(idx.mincol, lc), min(idx.maxcol, lc+nc-1); ...
                  max(idx.minrow, tr), min(idx.maxrow, tr+nr-1)];
    ## Correct spreadsheet locations for lower right shift of raw
    rc = idx.minrow - 1;
    cc = idx.mincol - 1;
    raw = raw(xls.limits(2, 1)-rc : xls.limits(2, 2)-rc, ...
              xls.limits(1, 1)-cc : xls.limits(1, 2)-cc);
  endif

  if (! isempty (val))
    rstatus = 1;
  endif

endfunction
