## Copyright (C) 2009-2019 Philip Nienhuis
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
## @deftypefn {Function File} @var{xls} = xlsopen (@var{filename})
## @deftypefnx {Function File} @var{xls} = xlsopen (@var{filename}, @var{readwrite})
## @deftypefnx {Function File} @var{xls} = xlsopen (@var{filename}, @var{readwrite}, @var{reqintf})
## Get a pointer to an Excel spreadsheet in the form of return argument
## (file pointer struct) @var{xls}. After processing the spreadsheet,
## the file pointer must be explicitly closed by calling xlsclose().
##
## Calling xlsopen without specifying a return argument is fairly useless!
##
## xlsopen works with interfaces, which are links to external software.
## For I/O from/to OOXML (Excel 2007 and up), ODS 1.2 and Gnumeric, no
## additional software is required when the OCT interface is used (see below).
## For all other spreadsheet formats, you need one or more of MS-Excel
## (95 - 2013), or a Java JRE plus Apache POI >= 3.5 and/or JExcelAPI
## and/or OpenXLS and/or OpenOffice.org (or clones) installed on your computer
## + proper javaclasspath set. These interfaces are referred to as COM, POI,
## JXL, OXS, and UNO, resp., and are preferred in that order by default
## (depending on their presence). Currently the OCT interface has the lowest
## priority as it is still experimental.
## For OOXML read/write support in principle no additional SW is needed.
## However, the COM, POI and UNO interfaces may provide better OOXML write
## performance and/or more flexibility.
## Excel'95 spreadsheets (BIFF5) can only be read using the COM (Excel-ActiveX),
## JXL (JExcelAPI), and UNO (Open-/LibreOffice) interfaces.
##
## @var{filename} should be a valid .xls or .xlsx Excel file name (including
## extension). But if you use the COM interface you can specify any extension
## that your installed Excel version can read AND write; the same goes for UNO
## (OpenOffice.org). Using the other Java interfaces, only .xls or .xlsx are
## allowed. If @var{filename} does not contain any directory path, the file
## is saved in the current directory.  Reading/writing .xlsm and .xlsb files
## may be possible using the COM and UNO interfaces only, but is untested.
##
## If @var{readwrite} is set to 0 (default value) or omitted, the spreadsheet
## file is opened for reading. If @var{readwrite} is set to true or 1, a
## spreadsheet file is opened (or created) for reading & writing.
##
## Optional input argument @var{reqintf} can be used to override the Excel
## interface that otherwise is automatically selected by xlsopen. Currently
## implemented interfaces (in order of preference) are 'COM' (Excel/COM),
## 'POI' (Java/Apache POI), 'JXL' (Java/JExcelAPI), 'OXS' (Java/OpenXLS),
## 'UNO' (Java/OpenOffice.org - EXPERIMENTAL!), or 'OCT' (native Octave).
## In most situations this parameter is unneeded as xlsopen automatically
## selects the most useful interface present.
##
## Beware: Excel invocations may be left running invisibly in case of COM
## errors or forgetting to close the file pointer. Similarly for OpenOffice.org
## which may even prevent Octave from being closed.
##
## Examples:
##
## @example
##   xls = xlsopen ('test1.xls');
##   (get a pointer for reading from spreadsheet test1.xls)
##
##   xls = xlsopen ('test2.xls', 1, 'POI');
##   (as above, indicate test2.xls will be written to; in this case using Java
##    and the Apache POI interface are requested)
## @end example
##
## @seealso {xlsclose, xlsread, xlswrite, xls2oct, oct2xls, xlsfinfo}
##
## @end deftypefn

## Author: Philip Nienhuis <prnienhuis at users.sf.net>
## Created: 2009-11-29

function [ xls ] = xlsopen (filename, xwrite=0, reqinterface=[])

  persistent xlsinterfaces; persistent chkintf; persistent lastintf;
  ## xlsinterfaces.<intf> = [] (not yet checked), 0 (found to be unsupported) or 1 (OK)
  if (isempty (chkintf));
      chkintf = 1;
      xlsinterfaces = struct ("COM", [], "POI", [], "JXL", [], "OXS", [], "UNO", [], "OCT", 1);
  endif
  if (isempty (lastintf))
    lastintf = "---";
  endif
  xlsintf_cnt = 1;

  xlssupport = 0;

  if (nargout < 1)
      error ("xlsopen: no return argument specified!\n usage:  XLS = xlsopen (Xlfile [, Rw] [, reqintf])\n"); 
  endif

  if (! (islogical (xwrite) || isnumeric (xwrite)))
      error ("xlsopen: numerical or logical value expected for arg ## 2 (readwrite)\n")
  endif

  if (ischar (filename))
    [pth, fnam, ext] = fileparts (filename);
    if (isempty (fnam))
      error ("xlsopen: no filename or empty filename specified");
    endif
    if (xwrite && ! isempty (pth))
      apth = make_absolute_filename (pth);
      if (exist (apth) != 7)
        error ("xlsopen: cannot write into non-existent directory:\n'%s'\n", ...
               apth);
      endif
    endif
  else
    error ("xlsopen: filename expected for argument #1");
  endif

  if (! isempty (reqinterface))
    intfmsg = "requested";
    if (! (ischar (reqinterface) || iscell (reqinterface)))
      error ("xlsopen: arg ## 3 (interface) not recognized - character value required\n"); 
    endif
    ## Turn arg3 into cell array if needed
    if (! iscell (reqinterface))
      reqinterface = {reqinterface}; 
    endif
    ## Check if previously used interface matches a requested interface
    if (isempty (regexpi (reqinterface, lastintf, "once"){1}) ||
        ! xlsinterfaces.(upper (reqinterface{1})))
      ## New interface requested
      xlsinterfaces.COM = 0; xlsinterfaces.POI = 0; xlsinterfaces.JXL = 0;
      xlsinterfaces.OXS = 0; xlsinterfaces.UNO = 0; xlsinterfaces.OCT = 0;
      for ii=1:numel (reqinterface)
        reqintf = toupper (reqinterface {ii});
        ## Try to invoke requested interface(s) for this call. Check if it
        ## is supported anyway by emptying the corresponding var.
        if     (strcmpi (reqintf, "COM"))
          xlsinterfaces.COM = [];
        elseif (strcmpi (reqintf, "POI"))
          xlsinterfaces.POI = [];
        elseif (strcmpi (reqintf, "JXL"))
          xlsinterfaces.JXL = [];
        elseif (strcmpi (reqintf, "OXS"))
          xlsinterfaces.OXS = [];
        elseif (strcmpi (reqintf, "UNO"))
          xlsinterfaces.UNO = [];
        elseif (strcmpi (reqintf, "OCT"))
          xlsinterfaces.OCT = [];
        else 
          error (sprintf (["xlsopen: unknown .xls interface \"%s\" requested.\n" 
                 "Only COM, POI, JXL, OXS, UNO, or OCT) supported\n"], reqinterface{}));
        endif
      endfor
      printf ("Checking requested interface(s):\n");
      xlsinterfaces = getxlsinterfaces (xlsinterfaces);
      ## Well, is/are the requested interface(s) supported on the system?
      xlsintf_cnt = 0;
      for ii=1:numel (reqinterface)
        if (! xlsinterfaces.(toupper (reqinterface{ii})))
          ## No it aint
          printf ("%s is not supported.\n", upper (reqinterface{ii}));
        else
          ++xlsintf_cnt;
        endif
      endfor
      ## Reset interface check indicator if no requested support found
      if (! xlsintf_cnt)
        chkintf = [];
        xls = [];
        return
      endif
    endif
  else
    intfmsg = "available";
  endif

  ## Check if Excel file exists. First check for (supported) file name suffix:
  ftype = 0;
  [~, ~, ext] = fileparts (filename);
  has_suffix = ! isempty (ext);
  ## Regular extensions / file formats recognized by most interfaces
  if (has_suffix)
    switch ext
      case ".xls"                               ## Regular (binary) BIFF
        ftype = 1;
      case {".xlsx", ".xlsm", ".xlsb"}          ## Zipped XML / OOXML. Catches xlsx, xlsb, xlsm
        ftype = 2;
      case ".ods"                               ## ODS 1.2 (Excel 2007+ & OOo/LO can read ODS)
        ftype = 3;
      case ".gnumeric"                          ## Zipped XML / gnumeric
        ftype = 5;
      case ".csv"                               ## csv. Detected for xlsread afficionados
        ftype = 6;
      otherwise
        if (xlsinterfaces.COM)
          if (ismember (lower (ext), {".csv", ".txt", ".wk1", ".dif", ...
                                      ".dbf", ".wq1", ".pdf", ".prn", ...
                                      ".htm", ".html", ".mhtm", ".mhtml", ...
                                      ".xml", ".wks"}))
            ftype = 7;
          endif
        endif
    endswitch
  endif

  ## Var readwrite is really used to avoid creating files when wanting to read,
  ## or not finding not-yet-existing files when wanting to write a new one.
  
  ## Adapt file open mode for readwrite argument. Substitute suffix depending
  ## on read or write, in the former case adapt for .xsl .xlsx .xlsb .xlsm
  if (xwrite)
    fmode = "r+b";
    if (! has_suffix)
      ## No extension - just assume .xlsx
      filename = [filename ".xlsx"];
      ext = ".xlsx";
      ftype = 2;
    endif
  else
    fmode = "rb";
    if (! has_suffix)
      ## Try to find find existing file name. We ignore .gnumeric
        filnm = dir ([filename ".xls*"]);
        if (! isempty (filnm))
          ## Simply choose the first one
          if (isstruct (filnm))
            filename = filnm(1).name;
          else
            filename = filnm;
          endif
        ## else - no .xls* file found, will be catched below
        endif
    endif
  endif
  fid = fopen (filename, fmode);
  if (fid < 0)                      ## File doesn't exist...
    if (! xwrite)                   ## ...which obviously is fatal for reading...
      ## FIXME process open apps (Excel, LibreOffice, etc) before hard crash
      error ( sprintf ("xlsopen: file %s not found\n", filename));
    else                            ## ...but for writing, we need more info:
      fid = fopen (filename, "rb"); ## Check if it exists at all...
      if (fid < 0)                  ## File didn't exist yet. Simply create it
        xwrite = 3;
      else                          ## File exists, but isn't writable => Error
        fclose (fid);  ## Do not forget to close the handle neatly
        error (sprintf ("xlsopen: write mode requested but file %s is not writable\n", filename))
      endif
    endif
  else
    ## Close file anyway to avoid COM or Java errors
    fclose (fid);
  endif
  
  ## Check for the various Excel interfaces. No problem if they've already
  ## been checked, getxlsinterfaces (far below) just returns immediately then.
  xlsinterfaces = getxlsinterfaces (xlsinterfaces);

  ## If no external interface was detected and no suffix was given, use .xlsx
  if (! has_suffix && ! (xlsinterfaces.COM + xlsinterfaces.POI + ...
                         xlsinterfaces.JXL + xlsinterfaces.OXS + ...
                         xlsinterfaces.UNO))
    ftype = 2;
  endif
  
  ## Initialize file ptr struct
  xls = struct ("xtype",    "NONE", 
                "app",      [], 
                "filename", [], 
                "workbook", [], 
                "changed",  0, 
                "limits",   []);

  ## Keep track of which interface is selected
  xlssupport = 0;

  ## Interface preference order is defined below: currently COM -> POI -> JXL -> OXS -> UNO -> OCT
  ## ftype (file type) is conveyed depending on interface capabilities

  if ((! xlssupport) && xlsinterfaces.COM && (ftype != 5))
    ## Excel functioning has been tested above & file exists, so we just invoke it.
    [ xls, xlssupport, lastintf ] = __COM_spsh_open__ (xls, xwrite, filename, xlssupport);
  endif

  if ((! xlssupport) && xlsinterfaces.POI && (ftype == 1))
    [ xls, xlssupport, lastintf ] = __POI_spsh_open__ (xls, xwrite, filename, xlssupport, ftype, xlsinterfaces);
  endif

  if ((! xlssupport) && xlsinterfaces.POI == 2 && (ftype == 2))
    [ xls, xlssupport, lastintf ] = __POI_spsh_open__ (xls, xwrite, filename, xlssupport, ftype, xlsinterfaces);
  endif

  if ((! xlssupport) && xlsinterfaces.JXL && ftype == 1)
    [ xls, xlssupport, lastintf ] = __JXL_spsh_open__ (xls, xwrite, filename, xlssupport, ftype, xlsinterfaces);
  endif

  if ((! xlssupport) && xlsinterfaces.OXS && ftype == 1)
    [ xls, xlssupport, lastintf ] = __OXS_spsh_open__ (xls, xwrite, filename, xlssupport, ftype);
  endif

  if ((! xlssupport) && xlsinterfaces.UNO && (ftype != 5))
    ## Warn for LO / OOo stubbornness
    if (ftype == 0 || ftype == 5 || ftype == 6)
      warning ("xlsopen: UNO interface will write ODS format for unsupported file extensions\n")
    endif
    [ xls, xlssupport, lastintf ] = __UNO_spsh_open__ (xls, xwrite, filename, xlssupport);
  endif

  if ((! xlssupport) && xlsinterfaces.OCT && ...
      (ftype == 2 || ftype == 3 || ftype == 5))
    [ xls, xlssupport, lastintf ] = __OCT_spsh_open__ (xls, xwrite, filename, xlssupport, ftype);
  endif

  ## if 
  ##  ---- other interfaces
  ## endif

  ## Rounding up. If none of the xlsinterfaces is supported we're out of luck.
  if (! xlssupport)
    if (isempty (reqinterface))
      ## If no suitable interface was detected (COM or UNO can read .csv), handle
      ## .csv in xlsread (as that's where Matlab n00bs would expect .csv support)
      if (ftype != 6)
        ## This message is appended after message from getxlsinterfaces()
        printf ("None.\n");
        warning ("xlsopen: no '%s' spreadsheet I/O support with %s interfaces.\n", ...
                 ext, intfmsg);
      endif
    else
      ## No match between file type & interface found
      warning ("xlsopen: file type not supported by %s %s %s %s %s %s\n", reqinterface{:});
    endif
    xls = [];
    ## Reset found interfaces for re-testing in the next call. Add interfaces if needed.
    chkintf = [];
  else
    ## From here on xwrite is tracked via xls.changed in the various lower
    ## level r/w routines
    xls.changed = xwrite;

    ## xls.changed = 0 (existing/only read from), 1 (existing/data added), 2 (new,
    ## data added) or 3 (pristine, no data added).
    ## Until something was written to existing files we keep status "unchanged".
    if (xls.changed == 1)
      xls.changed = 0; 
    endif
  endif

endfunction
