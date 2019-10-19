## Copyright (C) 2016-2019 Carnë Draug <carandraug@octave.org>
## Copyright (C) 2011-2019 Philip Nienhuis
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License as
## published by the Free Software Foundation; either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
## General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, see
## <http:##www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn {} {} __exit_io__ ()
## Undocumented internal function of io package.
##
## Remove io java jars loaded by io package functions from javaclasspath.
##
## @end deftypefn

## PKG_DEL: octave.table.internal.io.__exit_io__ ()

function __exit_io__ ()
  ## All we need to do is try to remove all Java spreadsheet class libs loaded
  ## by chk_spreadsheet_support.m from the javaclasspath
  try
    octave.table.internal.io.chk_spreadsheet_support ("", -1);
  catch
    warning ("io: couldn't remove spreadsheet I/O javaclasspath entries while unloading io pkg\n");
  end_try_catch
endfunction
