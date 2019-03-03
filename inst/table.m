classdef table
  %TABLE Tabular data array
  %
  % A tabular data structure that collects multiple parallel named variables.
  % Each variable is treated like a column (possibly a multi-column column).
  % The types of variables may be heterogeneous.
  %
  % A table object is like an SQL table or resultset, or a relation, or a 
  % DataFrame in R or Pandas.
  
  % Developer's notes:
  % - Wherever you see the abbreviation "pk", that means "proxy keys", not
  %   "primary keys".

  properties
    % The names of the variables (columns), as cellstr
    VariableNames = {}
    % The values of the variables, as a cell vector of arbitrary types
    VariableValues = {}
    % Optional row names, as cellstr
    RowNames = []
  end
  
  methods
    function this = table (varargin)
      %TABLE Construct a new table
      %
      % t = table (var1, var2, ... varN)
      % t = table ('Size', sz, 'VariableTypes', varTypes)
      % t = table (..., 'VariableNames', varNames)
      % t = table (..., 'RowNames', rowNames)
      % t = table
      
      % Peel off trailing options
      [opts, args] = peelOffNameValueOptions (varargin, {'VariableNames', 'RowNames'});
      
      % Calling form handling
      nargs = numel (args);
      if nargs == 3 && isequal (args{1}, 'Backdoor')
        % Undocumented form for internal use
        [varNames, varVals] = args{2:3};
      elseif nargs == 4 && isequal (args{1}, 'Size') && isequal (args{3}, 'VariableTypes')
        error('table: This constructor form is unimplemented');
      else
        varVals = args;
        if isfield (opts, 'VariableNames')
          varNames = opts.VariableNames;
        else
          varNames = cell (size (args));
          for i = 1:numel (args)
            varNames{i} = inputname (i);
            if isempty (varNames{i})
              varNames{i} = sprintf('Var%d', i);
            end
          end
        end
      end
      
      % Input validation
      if ~iscell (varVals) || (~isvector (varVals) && ~isempty (varVals))
        error('table: VariableValues must be a cell vector');
      end
      if ~iscellstr (varNames) || (~isvector (varNames) && ~isempty (varNames))
        error('table: VariableNames must be a cellstr vector');
      end
      varNames = varNames(:)';
      varVals = varVals(:)';
      if numel (varNames) ~= numel (varVals)
        error ('table: Inconsistent number of VariableNames (%d) and VariableValues (%d)', ...
         numel (varNames), numel (varVals));
      end
      for i = 1:numel (varNames)
        if ~isvarname (varNames{i})
          error ('table: Invalid VariableName: ''%s''', varNames{i});
        end
      end
      if ~isempty (varVals)
        nrows = size (varVals{1}, 1);
        for i = 2:numel (varVals)
          nrows2 = size (varVals{i}, 1);
          if nrows ~= nrows2
            error ('table: Inconsistent sizes: var 1 (%s) is %d rows; var %d (%s) is %d rows', ...
              varNames{1}, nrows, i, varNames{i}, nrows2);
          end
        end
      end
      [uqNames, ix] = unique (varNames);
      if numel (uqNames) < numel (varNames)
        ixBad = 1:numel (varNames);
        ixBad(ix) = [];
        error ('table: Duplicate VariableNames: %s', strjoin (varNames(ixBad), ', '));
      end

      % Construction
      this.VariableNames = varNames;
      this.VariableValues = varVals;
      if isfield (opts, 'RowNames')
        this.RowNames = opts.RowNames;
      end
    end
    
    % Display
    
    function display (this)
      %DISPLAY Custom display.
      in_name = inputname (1);
      if ~isempty (in_name)
        fprintf ('%s =\n', in_name);
      end
      disp (this);
    end

    function disp (this)
      %DISP Custom display.
      if isempty (this)
        fprintf ('Empty %s %s\n', size2str (size (this)), class (this));
      else
        fprintf ('table: %d rows x %d variables\n', height (this), width (this));
        fprintf ('  VariableNames: %s\n', strjoin (this.VariableNames, ', '));
      end
    end
    
    function out = summary (this)
      %SUMMARY Summary of table
      %
      % summary (this)
      % s = summary (this)
      %
      % Prints or returns a summary of the data in this table.
      %
      % Currently, only the `s = summary (this)` capturing form is implemented.
      % This is a work in progress.
      
      % Common summary things:
      % Size, Type, Description, Units, CustomProperties
      % Size and Type can be computed from variable data itself;
      % Description, Units and CustomProperties are drawn from the table-managed metadata.
      
      out = struct;
      for iVar = 1:width (this)
        varVal = this.VariableValues{iVar};
        s = octave.table.internal.mx_summary (varVal);
        %TODO: Decorate with table-managed metadata: Description, Units, CustomProperties
        out.(this.VariableNames{iVar}) = s;
      endfor
      
      if nargout == 0
        %TODO: Include obj-level Description etc
        prettyprint_summary_data (out);
        clear out
      endif
    endfunction
    
    function prettyprint (this)
      %PRETTYPRINT Display table values, formatted as a table
      if isempty (this)
        fprintf ('Empty %s %s\n', size2str (size (this)), class (this));
        return;
      end
      nVars = width (this);
      varNames = this.VariableNames;
      % Here, "cols" means output columns, not data columns. Each data variable
      % will be displayed in a single output column.
      %FIXME: This display logic might be broken for multi-column variables.
      colNames = varNames;
      colStrs = cell (1, nVars);
      colWidths = NaN (1, nVars);
      for iVar = 1:numel (this.VariableValues)
        vals = this.VariableValues{iVar};
        strs = dispstrs (vals);
        lines = cell (height(this), 1);
        for iRow = 1:size (strs, 1)
          lines{iRow} = strjoin (strs(iRow,:), '   ');
        end
        colStrs{iVar} = lines;
        colWidths(iVar) = max (cellfun ('numel', lines));
      end
      colWidths;
      nameWidths = cellfun ('numel', varNames);
      colWidths = max ([nameWidths; colWidths]);
      totalWidth = sum (colWidths) + 4 + (3 * (nVars - 1));
      elementStrs = cat (2, colStrs{:});
      
      rowFmts = cell (1, nVars);
      for i = 1:nVars
        rowFmts{i} = ['%-' num2str(colWidths(i)) 's'];
      end
      rowFmt = ['| ' strjoin(rowFmts, ' | ')  ' |' sprintf('\n')];
      fprintf ('%s\n', repmat ('-', [1 totalWidth]));
      fprintf (rowFmt, varNames{:});
      fprintf ('%s\n', repmat ('-', [1 totalWidth]));
      for i = 1:height (this)
        fprintf (rowFmt, elementStrs{i,:});
      end
      fprintf ('%s\n', repmat ('-', [1 totalWidth]));
    end
    
    % Type conversion
    
    function out = table2cell (this)
      %TABLE2CELL Convert table to cell
      %
      % out = table2cell (this)
      %
      % Each variable in this becomes a column in the output.
      %
      % Returns a cell array the same size as this.
      out = cell (size (this));
      for i = 1:width (this)
        varVal = this.VariableValues{i};
        if iscell (varVal)
          if size (varVal, 2) == 1
            out(:,i) = varVal;
          else
            out(:,i) = mat2cell (varVal, ones (1, size (varVal, 2)));
          endif
        else
          out(:,i) = num2cell (varVal, 2);
        endif
      endfor
    endfunction
    
    function out = table2struct (this, varargin)
      %TABLE2STRUCT Convert table to structure array
      %
      % Converts this to a scalar structure or structure array.
      %
      % Row names are not included in the output struct. To include them, you
      % must add them manually:
      %   s = table2struct (tbl, 'ToScalar', true);
      %   s.RowNames = tbl.Properties.RowNames;
      %
      % Returns a scalar struct or struct array, depending on the value of the
      % ToScalar option.
      [opts, args] = peelOffNameValueOptions (varargin, {'ToScalar'});
      toScalar = false;
      if isfield (opts, 'ToScalar')
        mustBeA (opts.ToScalar, 'logical');
        mustBeScalar (opts.ToScalar);
        toScalar = opts.ToScalar;
      endif
      
      if toScalar
        out = struct;
        for i = 1:width (this)
          out.(this.VariableNames{i}) = this.VariableValues{i};
        endfor
      else
        %TODO: Figure out how to implement this efficiently using cell2struct
        s0 = struct;
        for i = 1:width (this)
          s0.(this.VariableNames{i}) = [];
        endfor
        out = repmat (s0, [height(this) 1]);
        for iVar = 1:width (this)
          varVal = this.VariableValues{iVar};
          for iRow = 1:height (this)
            if iscell (varVal) && size (varVal, 2) == 1
              elVal = varVal{iRow};
            else
              elVal = varVal(iRow,:);
            endif
            out(iRow).(this.VariableNames{iVar}) = elVal;
          endfor
        endfor
      endif
    endfunction
    
    function out = table2array (this)
      %TABLE2ARRAY Convert table to homogeneous array
      if isempty (this)
        out = [];
        return
      endif
      % Wow, this is an easy implementation
      % TODO: Doesn't work for mixed cell and non-cell variable values, because of the
      % implicit conversion of numerics to single cells. Dunno if we want to add
      % more graceful support for that or not.
      out = cat (2, this.VariableValues{:});
    endfunction

    % Structural stuff
    
    function out = varnames (this)
      %VARNAMES Variable names in table
      %
      % Gets the list of variable names in this.
      %
      % Returns cellstr.
      %
      % This is an Octave extension.
      out = this.VariableNames;
    endfunction

    function out = istable (this)
      out = true;
    endfunction

    function out = size (this)
      out = [height(this), width(this)];
    end
    
    function out = ndims (this)
      out = 2;
    end
    
    function out = squeeze (this)
      %SQUEEZE Remove singleton dimensions from this.
      %
      % This is always a no-op that returns the input unmodified, because tables
      % always have exactly 2 dimensions.
      out = this;
    endfunction
    
    function out = size_equal
      %SIZE_EQUAL True if the dimensions of all arguments agree.
      error ('table.size_equal: size_equal is not yet implemented for tables');
    endfunction
  
    function out = sizeof (this)
      %SIZEOF Size of this in bytes.
      %
      % TODO: Calculate this as the sum of bytes in all variables and in all
      % properties/metadata arrays.
      error ('table.sizeof: sizeof is not yet implemented for tables');
    endfunction

    function out = height (this)
      if isempty (this.VariableValues)
        out = 0;
      else
        out = size (this.VariableValues{1}, 1);
      end
    end
    
    function out = rows (this)
      out = height (this);
    endfunction
    
    function out = width (this)
      out = numel (this.VariableNames);
    end
    
    function out = columns (this)
      out = width (this);
    endfunction
    
    function out = numel (this)
      n = 0;
      for i = 1:numel (this.VariableValues)
        n = n + numel (this.VariableValues{i});
      end
      out = n;
    end
    
    function out = isempty (this)
      out = isempty (this.VariableNames);
    end
    
    function out = ismatrix (this)
      out = true;
    end
    
    function out = isrow (this)
      out = height (this) == 1;
    end
    
    function out = iscol (this)
      out = width (this) == 1;
    end
    
    function out = isvector (this)
      out = isrow (this) || iscol (this);
    end
    
    function out = isscalar (this)
      out = height (this) == 1 && width (this) == 1;
    end
    
    function out = hasrownames (this)
      out = ~isempty (this.RowNames);
    endfunction
    
    function out = vertcat (varargin)
      args = varargin;
      for i = 1:numel (args)
        if ~isa (args{i}, 'table')
          args{i} = table (args{i});
        end
      end
      mustBeAllSameVars (args{:});
      out = args{1};
      for i = 2:numel (args)
        if isempty (out.RowNames)
          if ~isempty (args{i}.RowNames)
            error ('table.vertcat: Cannot cat tables with mixed empty and non-empty RowNames');
          end
        else
          out.RowNames = [out.RowNames; args{i}.RowNames];
        end
        for iVar = 1:width (out)
          out.VariableValues{iVar} = [out.VariableValues{iVar}; args{i}.VariableValues{iVar}];
        end
      end
    end
    
    function out = horzcat (varargin)
      %HORZCAT Horizontal concatenation
      %
      % Inputs must have all distinct variable names.
      %
      % Output has the same RowNames as varargin{1}. The variable names and values
      % are the result of the concatenation of the variable names and values lists
      % from the inputs.
      args = varargin;
      seen_names = args{1}.VariableNames;
      for i = 2:numel (args)
        dup_names = intersect (seen_names, args{i}.VariableNames);
        if ~isempty (dup_names)
          error ('table.horzcat: Inputs have duplicate VariableNames: %s', strjoin (dup_names, ', '));
        end
        seen_names = [seen_names args{i}.VariableNames];
      end
      % Okay, all var names are distinct. We can just concatenate.
      varNameses = cell (size (args));
      varValses = cell (size (args));
      for i = 1:numel (args)
        varNameses{i} = args{i}.VariableNames;
        varValses{i} = args{i}.VariableValues;
      endfor
      out = varargin{1};
      out.VariableNames = cat (2, varNameses{:});
      out.VariableValues = cat (2, varValses{:});
    end
    
    function out = subsref (this, s)
      chain_s = s(2:end);
      s = s(1);
      switch s(1).type
        case '()'
          if numel (s.subs) ~= 2
            error ('table.subsref: ()-indexing of table requires exactly two arguments');
          end
          [ixRow, ixVar] = resolveRowVarRefs (this, s.subs{1}, s.subs{2});
          out = this;
          out = subsetRows (out, ixRow);
          out = subsetvars (out, ixVar);
        case '{}'
          if numel (s.subs) ~= 2
            error ('table.subsref: {}-indexing of table requires exactly two arguments');
          end
          [ixRow, ixVar] = resolveRowVarRefs (this, s.subs{1}, s.subs{2});
          if numel (ixRow) ~= 1 && numel (ixVar) ~= 1
            error('table.subsref: {}-indexing of table requires one of the inputs to be scalar');
          end
          %FIXME: I'm not sure how to handle the signature here yet
          if numel (ixVar) > 1
            error ('table.subsref: {}-indexing across multiple variables is currently unimplemented');
          end
          if numel (ixRow) > 1
            error ('table.subsref: {}-indexing across multiple rows is currently unimplemented');
          end
          varData = this.VariableValues{ixVar};
          out = varData(ixRow);
        case '.'
          name = s.subs;
          if ~ischar (name)
            error ('table.subsref: .-reference arguments must be char');
          end
          out = getVar (this, name);
      end
      % Chained references
      if ~isempty (chain_s)
        out = subsref (out, chain_s);
      end
    end
    
    function out = subsasgn (this, s, val)
      %SUBSASGN Subscripted assignment

      % Chained subscripts
      chain_s = s(2:end);
      s = s(1);
      if ~isempty (chain_s)
          rhs_in = subsref (this, s);
          rhs = subsasgn (rhs_in, chain_s, val);
      else
          rhs = val;
      end

      out = this;
      switch s(1).type
        case '()'
          error ('table.subsasgn: Assignment using ()-indexing is not supported for table');
        case '{}'
          if numel (s.subs) ~= 2
            error('table.subsasgn: {}-indexing of table requires exactly two arguments');
          end
          [ixRow, ixVar] = resolveRowVarRefs (this, s.subs{1}, s.subs{2});
          if ~isscalar (ixVar)
            error ('table.subsasgn: {}-indexing must reference a single variable; got %d', ...
              numel (ixVar));
          end
          varData = this.VariableValues{ixVar};
          varData(ixRow) = rhs;
          out.VariableValues{ixVar} = varData;
        case '.'
          out = setCol (this, s.subs, rhs);
      end
    end
    
    function ixVar = resolveVarRef (this, varRef)
      %RESOLVEVARREF Resolve a reference to variables
      %
      % A varRef is a numeric or char/cellstr indicator of which variables within
      % this table are being referenced.
      if isnumeric (varRef) || islogical (varRef)
        ixVar = varRef;
      elseif isequal (varRef, ':')
        ixVar = 1:width (this);
      elseif ischar (varRef) || iscellstr (varRef)
        varRef = cellstr (varRef);
        [tf, ixVar] = ismember (varRef, this.VariableNames);
        if ~all (tf)
          error ('table.resolveVarRef: No such variable in table: %s', strjoin (varRef(~tf), ', '));
        end
      else
        error ('table.resolveVarRef: Unsupported variable indexing operand type: %s', class (varRef));
      end
    end

    function [ixRow, ixVar] = resolveRowVarRefs (this, rowRef, varRef)
      if isnumeric (rowRef) || islogical (rowRef)
        ixRow = rowRef;
      elseif iscellstr (rowRef)
        if isempty (this.RowNames)
          error ('table.resolveRowVarRefs: this table has no RowNames');
        end
        [tf, ixRow] = ismember (rowRef, this.RowNames);
        if ~all (tf)
          error ('table.resolveRowVarRefs: No such named row in table: %s', strjoin (rowRef(~tf), ', '));
        end
      elseif isequal (rowRef, ':')
        ixRow = 1:height (this);
      else
        error ('table.resolveRowVarRefs: Unsupported row indexing operand type: %s', class (rowRef));
      end
      
      ixVar = resolveVarRef (this, varRef);
    end
    
    function out = subsetRows (this, ixRows)
      out = this;
      if ~isnumeric (ixRows) && ~islogical (ixRows)
        % TODO: Hmm. Maybe we ought not to do this check, but just defer to the
        % individual variable values' indexing logic, so SUBSREF/SUBSINDX overrides
        % are respected. Would produce worse error messages, but be more "right"
        % type-wise.
        error ('table.subsetRows: ixRows must be numeric or logical; got a %s', ...
          class (ixRows));
      endif
      for i = 1:width (this)
        out.VariableValues{i} = out.VariableValues{i}(ixRows,:);
      end
      if ~isempty (this.RowNames)
        out.RowNames = out.RowNames(ixRows);
      end
    end
    
    function out = subsetvars (this, ixVars)
      %SUBSETVARS Subset this along its variables

      if ischar (ixVars)
        if ~isequal (ixVars, ':')
          ixVars = cellstr (ixVars);
        endif
      endif
      if iscellstr (ixVars)
        [tf,ix] = ismember (ixVars, this.VariableNames);
        if ~all (tf)
          error ('table.subsetvars: no such variables in this table: %s', ...
            strjoin (ixVars(~tf), ', '));
        endif
        ixVars = ix;
      endif
      out = this;
      out.VariableNames = this.VariableNames(ixVars);
      out.VariableValues = this.VariableValues(ixVars);
    end
    
    function out = removevars (this, vars)
      %REMOVEVARS Remove variables
      %
      % out = removevars (this, vars)
      %
      % Deletes the variables specified by vars.
      %
      % vars may be a char, cellstr, numeric index vector, or logical index vector.
      %
      % Returns table.
      ixVar = resolveVarRef (this, vars);
      out = this;
      out.VariableNames(ixVar) = [];
      out.VariableValues(ixVar) = [];
    endfunction
    
    function out = movevars (this, vars, relLocation, location)
      %MOVEVARS Move variables
      %
      % out = movevars (this, vars, relLocation, location)
      %
      % Moves around variables in a table.
      %
      % vars is a list of variables to move, specified by name or index.
      %
      % relLocation is 'Before' or 'After'.
      %
      % location indicates a single variable to use as the target location, 
      % specified by name or index. If it is specified by index, it is the index
      % into the list of *unmoved* variables from this, not the original full
      % list of variables in this.
      %
      % Returns table with the same variables as this, but in a different order.
      if ~ischar (relLocation)
        error ('table.movevars: relLocation must be char; got %s', class (relLocation));
      endif
      if ~ismember (relLocation, {'Before', 'After'})
        error ('table.movevars: relLocation must be ''Before'' or ''After''; got ''%s''', ...
          relLocation);
      endif
      ixVar = resolveVarRef (this, vars);
      ixOtherVars = 1:width (this);
      ixOtherVars(ixVar) = [];
      tmp = subsetvars (this, ixOtherVars);
      moved = subsetvars (this, ixVar);
      ixLoc = resolveVarRef (tmp, location);
      if ~isscalar (ixLoc)
        error ('table.movevars: location must specify a single existing variable');
      endif
      if isequal(relLocation, 'Before')
        insertionIx = ixLoc;
      else
        insertionIx = ixLoc = 1;
      endif
      left = subsetvars (tmp, 1:insertionIx-1);
      right = subsetvars (tmp, insertionIx:width (tmp));
      out = [left moved right];
    endfunction
    
    function out = setvar (this, varRef, value)
      %SETVAR Set value for a variable
      %
      % This sets (replaces) the value for a variable that already exists in this.
      % It cannot be used to add a new variable.
      ixVar = resolveVarRef (this, varRef);
      out = this;
      if size (value, 1) ~= height (this)
        error ('table.setvar: Inconsistent dimensions: table is height %d, input is height %d', ...
          height (this), size (value, 1));
      end
      out.VariableValues{ixVar} = value;
    end
    
    function out = convertvars (this, vars, dataType)
      %CONVERTVARS Convert variables to specified data type
      %
      % out = convertvars (this, vars, dataType)
      %
      % Converts the variables specified by vars to the specified data type.
      %
      % vars is a cellstr or numeric vector specifying which variables to convert.
      %
      % dataType specifies the data type to convert those variables to. It is either
      % a char holding the name of the data type, or a function handle which will
      % perform the conversion. If it is the name of the data type, there must
      % either be a one-arg constructor of that type which accepts the specified
      % variables' current types as input, or a conversion method of that name
      % defined on the specified variables' current type.
      %
      % Returns a table with the same variable names as this, but with converted
      % types.
      if ~ischar (dataType) && isa (dataType, 'function_handle')
        error ('table.convertvars: dataType must be char or function_handle; got a %s', ...
          class (dataType));
      endif
      ixVars = resolveVarRef (this, vars);
      out = this;
      for i = 1:numel (ixVars)
        ixVar = ixVars(i);
        out.VariableValues{ixVar} = feval (dataType, this.VariableValues{ixVar});
      endfor
    endfunction
    
    function out = head (this, k)
      %HEAD Get first K rows of table
      %
      % out = head (this, k)
      %
      % Returns the first k rows of this. K defaults to 8.
      %
      % If there are less than k rows in this, returns all rows.
      if nargin < 2 || isempty (k)
        k = 8;
      endif
      nRows = height (this);
      if nRows < k
        out = this;
        return;
      endif
      out = subsetRows (this, 1:k);
    endfunction
    
    function out = tail (this, k)
      %TAIL Get last K rows of table
      %
      % out = tail (this, k)
      %
      % Returns the last k rows of this. K defaults to 8.
      %
      % If there are less than k rows in this, returns all rows.
      if nargin < 2 || isempty (k)
        k = 8;
      endif
      nRows = height (this);
      if nRows < k
        out = this;
        return;
      endif
      out = subsetRows (this, [(nRows - (k - 1)):nRows]);
    endfunction
    
    % Relational operations
    
    function [out, index] = sortrows (this, varargin)
      %SORTROWS Sort rows of table
      
      % Parse input signature
      % This is tricky because the sortrows() signature is complicated and ambiguous
      args = varargin;
      doRowNames = false;
      direction = 'ascend';
      varRef = ':';
      knownOptions = {'MissingPlacement', 'ComparisonMethod'};
      [opts, ~, optArgs] = peelOffNameValueOptions (args, knownOptions);
      if ~isempty (args) && (ischar (args{end}) || iscellstr (args{end})) ...
        && all (ismember (args{end}, {'ascend','descend'}))
        direction = args{end};
        args(end) = [];
      end
      if numel (args) > 1
        error ('table.sortrows: Unrecognized options or arguments');
      endif
      if !isempty (args)
        %FIXME: Determine how to identify the "rowDimName" argument
        if ischar (args{1}) && isequal (args{1}, 'RowNames')
          doRowNames = true;
        else
          varRef = args{1};
        endif
        args(end) = [];
      endif
      
      % Interpret inputs
      
      % Do sorting
      if doRowNames
        % Special case: sort by row names
        if isempty (this.rowNames)
          error ('table.sortrows: this table does not have row names');
        endif
        [sortedRowNames, index] = sortrows (this.RowNames, direction, optArgs{:});
        out = subsetRows (this, index);
      else
        % General case
        ixVars = resolveVarRef (this, varRef);
        if ischar (direction)
          direction = cellstr (direction);
        endif
        if isscalar (direction)
          directions = repmat (direction, size (ixVars));
        else
          directions = direction;
        endif
        if ~isequal (size (directions), size (ixVars))
          error ('table.sortrows: inconsistent size between direction and vars specifier');
        endif
        % Perform a radix sort on the referenced variables
        index = 1:height (this);
        tmp = this;
        for iStep = 1:numel(ixVars)
          iVar = numel(ixVars) - iStep + 1;
          ixVar = ixVars(iVar);
          varVal = tmp.VariableValues{ixVar};
          %Convert Matlab-style 'descend' arg to Octave-style negative column index
          %TODO: Add support for Octave-style negative column indexes in table.sortrows input.
          %TODO: Wrap this arg munging logic in a sortrows_matlabby() function
          %TODO: Better error message when optArgs are is present.
          if isequal (directions{iVar}, 'descend')
            [~, ix] = sortrows (varVal, -1 * (1:size (varVal, 2)), optArgs{:});
          else
            [~, ix] = sortrows (varVal, optArgs{:});
          endif
          index = index(ix);
          tmp = subsetRows (tmp, ix);
        endfor
        out = subsetRows (this, index);
      endif
    endfunction
    
    function out = issortedrows (this, varargin)
      %ISSORTEDROWS Determine if table rows are sorted
      %
      % TODO: Document my signature.
      [~, ix] = sortrows (this, varargin{:});
      out = isequal (ix, 1:height (this));
    endfunction
    
    function [out, ia] = topkrows (this, k, varargin)
      %TOPKROWS Top rows in sorted order
      %
      % TODO: Document my signature.
      [sorted, ix] = sortrows (this, varargin);
      if k > height (sorted)
        out = sorted;
        ia = ix;
      else
        out = sorted(1:k,:);
        ia = ix(1:k);
      end
    endfunction

    function [out, ia, ic] = unique (this, varargin)
      %UNIQUE Unique row values
      %
      % [out, ia, ic] = unique (this)
      % [out, ia, ic] = unique (..., 'first'/'last')
      % [out, ia, ic] = unique (..., 'legacy')
      % [out, ia, ic] = unique (..., 'stable'/'sorted')
      %
      % The 'legacy', 'stable', and 'sorted' flags are currently unsupported 
      % because Octave's core unique() function does not support them. If you use
      % them, you will get an error with a possibly-obsure error message.
      %
      % You can also pass a 'rows' flag, but it is effectively ignored, because
      % row-wise operation is the only mode supported for unique() on tables. 
      validFlags = {'rows', 'legacy', 'stable', 'sorted', 'first', 'last'};
      redundantFlags = {'rows'};
      if ~iscellstr (varargin)
        error ('table.unique: Invalid inputs: args 2 and later must be char flags');
      endif
      flags = varargin;
      invalidFlags = setdiff (varargin, validFlags);
      if ~isempty (invalidFlags)
        error ('table.unique: Invalid flags: %s', strjoin(invalidFlags, ', '));
      endif
      tfRedundant = ismember (flags, redundantFlags);
      flags(tfRedundant) = [];

      pk = proxykeysForMatrixes (this);
      [uPk, ia, ic] = unique (pk, 'rows', flags{:});
      out = subsetRows (this, ia);
    endfunction
    
    function [C, ib] = join (A, B, varargin)
      %JOIN Combine two tables by rows using key variables
      %
      % This is not a full relational join operation. It has the restrictions
      % that:
      %  1) The key values in B must be unique. 
      %  2) Every key value in A must map to a key value in B.
      % These are restrictions inherited from the Matlab definition of table.join.
      
      % Input munging
      optNames = {'Keys', 'KeepOneCopy', 'LeftKeys', 'RightKeys', ...
        'LeftVariables', 'RightVariables'};
      opts = peelOffNameValueOptions (varargin, optNames);
      unimplementedOptions = optNames;
      for i = 1:numel (unimplementedOptions)
        if isfield (opts, unimplementedOptions{i})
          error ('table.join: Option %s is unimplemented. Sorry.', ...
            unimplementedOptions{i});
        endif
      endfor
      if !isa (A, 'table')
        A = table (A);
      endif
      if !isa (B, 'table')
        B = table (B);
      endif
      
      % Join logic
      keyVarNames = intersect_stable (A.VariableNames, B.VariableNames);
      nonKeyVarsB = setdiff_stable (B.VariableNames, keyVarNames);
      if isempty (keyVarNames)
        error ('table.join: Cannot join: inputs have no variable names in common');
      endif
      keysA = subsetvars (A, keyVarNames);
      keysB = subsetvars (B, keyVarNames);
      uKeysB = unique (keysB);
      if height (uKeysB) < height (keysB)
        error ('table.join: Non-unique keys in B');
      endif
      [pkA, pkB] = proxykeysForMatrixes (keysA, keysB);
      [tf, ib] = ismember (pkA, pkB, 'rows');
      if ~all (tf)
        error ('table.join: Some rows in A had no corresponding key values in B');
      endif
      outA = A;
      nonKeysB = subsetvars (B, nonKeyVarsB);
      outB = subsetRows (nonKeysB, ib);
      C = [outA outB];
    endfunction

    function [out, ixs] = realjoin(A, B)
      %REALJOIN "Real" relational inner join, without key restrictions
      %
      % [out, ixs] = realjoin(A, B)
      %
      % Performs a "real" relational natural inner join between two tables, 
      % without the key restrictions that JOIN imposes.
      %
      % Returns:
      %   out - a table containing the result of joining A and B, with RowNames
      %         removed.
      %   ixs - an n-by-2 double matrix where ixs(i,:) is [ixA ixB], which are
      %         the indexes from A and B containing the input rows that resulted
      %         in this output row.
      %
      % RowNames on the output may be added in a future revision.
      %
      % This is an Octave extension.
      
      % Input handling
      if !isa (A, 'table')
        A = table (A);
      endif
      if !isa (B, 'table')
        B = table (B);
      endif
      if hasrownames (A)
        error ('table.realjoin: Input A may not have row names');
      endif
      if hasrownames (B)
        error ('table.realjoin: Input B may not have row names');
      endif
      
      % Join logic
      keyVarNames = intersect_stable (A.VariableNames, B.VariableNames);
      nonKeyVarsB = setdiff_stable (B.VariableNames, keyVarNames);
      if isempty (keyVarNames)
        % TODO: Should this degenerate to cartesian product instead of erroring?
        error ('table.realjoin: Cannot join: inputs have no variable names in common');
      endif
      keysA = subsetvars (A, keyVarNames);
      keysB = subsetvars (B, keyVarNames);
      [pkA, pkB] = proxykeysForMatrixes (keysA, keysB);
      ixs = matchrows (pkA, pkB);
      outA = subsetRows (A, ixs(:,1));
      nonKeysB = subsetvars (B, nonKeyVarsB);
      outB = subsetRows (nonKeysB, ixs(:,2));
      out = [outA outB];

    endfunction
  
    function [outA, ixA, outB, ixB] = semijoin (A, B)
      %SEMIJOIN Natural semijoin
      %
      % [outA, ixA, outB, ixB] = semijoin (A, B)
      %
      % Returns:
      % outA - all the rows in A with matching row(s) in B
      % ixA - the row indexes into A which produced outA
      % outB - all the rows in B with matching row(s) in A
      % ixB - the row indexes into B which produced outB
      
      % Developer note: This is almost exactly the same as antijoin, just with
      % inverted ismember() tests. See if the implementations can be refactored
      % together.
      
      % Input handling
      if !isa (A, 'table')
        A = table (A);
      endif
      if !isa (B, 'table')
        B = table (B);
      endif
      
      % Join logic
      keyVarNames = intersect_stable (A.VariableNames, B.VariableNames);
      nonKeyVarsB = setdiff_stable (B.VariableNames, keyVarNames);
      if isempty (keyVarNames)
        % TODO: There's probably a correct degenerate output for this, but I don't
        % know if it should be "all rows" or "no rows" - apjanke
        error ('table.semijoin: Cannot semijoin: inputs have no variable names in common');
      endif
      keysA = subsetvars (A, keyVarNames);
      keysB = subsetvars (B, keyVarNames);
      [pkA, pkB] = proxykeysForMatrixes (keysA, keysB);
      ixA = find (ismember (pkA, pkB, 'rows'));
      outA = subsetRows (A, ixA);
      if nargout > 2
        ixB = find (ismember (pkB, pkA, 'rows'));
        outB = subsetRows (B, ixB);
      endif
    endfunction
    
    function [outA, ixA, outB, ixB] = antijoin (A, B)
      %ANTIJOIN Natural antijoin (AKI semi-difference)
      %
      % [outA, ixA, outB, ixB] = antijoin (A, B)
      %
      % Computes the anti-join of A and B. The anti-join is defined as all the
      % rows from one input which do not have matching rows in the other input.
      %
      % Returns:
      % outA - all the rows in A with no matching row in B
      % ixA - the row indexes into A which produced outA
      % outB - all the rows in B with no matching row in A
      % ixB - the row indexes into B which produced outB
      
      % Input handling
      if !isa (A, 'table')
        A = table (A);
      endif
      if !isa (B, 'table')
        B = table (B);
      endif
      
      % Join logic
      keyVarNames = intersect_stable (A.VariableNames, B.VariableNames);
      nonKeyVarsB = setdiff_stable (B.VariableNames, keyVarNames);
      if isempty (keyVarNames)
        % TODO: There's probably a correct degenerate output for this, but I don't
        % know if it should be "all rows" or "no rows" - apjanke
        error ('table.antijoin: Cannot antijoin: inputs have no variable names in common');
      endif
      keysA = subsetvars (A, keyVarNames);
      keysB = subsetvars (B, keyVarNames);
      [pkA, pkB] = proxykeysForMatrixes (keysA, keysB);
      ixA = find (!ismember (pkA, pkB, 'rows'));
      outA = subsetRows (A, ixA);
      if nargout > 2
        ixB = find (!ismember (pkB, pkA, 'rows'));
        outB = subsetRows (B, ixB);
      endif
    endfunction
    
    function [out, ixs] = cartesian (A, B)
      %CARTESIAN Cartesian product of two tables
      %
      % out = cartesian (A, B)
      %
      % Computes the Cartesian product of two tables. The Cartesian product is
      % each row in A combined with each row in B.
      %
      % Due to the definition and structural constraints of table, the two inputs
      % must have no variable names in common. It is an error if they do.
      %
      % The Cartesian product is seldom used in practice. If you find yourself
      % calling this method, you should step back and re-evaluate what you are
      % doing, asking yourself if that is really what you want to happen. If nothing
      % else, writing a function that calls cartesian() is usually much less
      % efficient than alternate ways of arriving at the same result.
      %
      % This implementation does not remove duplicate values.
      % TODO: Determine whether this duplicate-removing behavior is correct.
      %
      % The ordering of the rows in the result is undefined, and may be implementation-
      % dependent. TODO: Determine if we can lock this behavior down to a fixed,
      % defined ordering, without killing performance.
      
      % Developer's note: The second argout, ixs, is for table's internal use,
      % and is thus undocumented.
      
      mustBeA (A, 'table');
      mustBeA (B, 'table');
      
      commonVars = intersect (A.VariableNames, B.VariableNames);
      if ~isempty (commonVars)
        error ('table.cartesian: Inputs have variable names in common: %s', ...
          strjoin (commonVars, ', '));
      endif
      
      nRowsA = height (A);
      nRowsB = height (B);
      ixA = (1:nRowsA)';
      ixB = (1:nRowsB)';
      ixAOut = repelem (ixA, nRowsB);
      ixBOut = repmat (ixB, [nRowsA 1]);
      ixs = [ixAOut ixBOut];
      outA = subsetRows (A, ixAOut);
      outB = subsetRows (B, ixBOut);
      out = [outA outB];
    endfunction

    function [outA, outB] = congruentize (A, B)
      %CONGRUENTIZE Make tables congruent
      %
      % out = congruentize (A, B)
      %
      % Makes tables congruent by ensuring they have the same variables of the
      % same types in the same order. Congruent tables may be safely unioned,
      % intersected, vertcatted, or have other set operations done to them.
      %
      % Variable names present in one input but not in the other produces an error.
      % Variables with the same name but different types in the inputs produces
      % an error.
      % Inputs must either both have row names or both not have row names; it is
      % an error if one has row names and the other doesn't.
      % Variables in different orders are reordered to be in the same order as A.
      
      if !isa (A, 'table')
        A = table (A);
      endif
      if !isa (B, 'table')
        B = table (B);
      endif
      if hasrownames (A) && !hasrownames (B)
        error ('table.congruentize: Input A has row names but input B does not');
      endif
      if !hasrownames (A) && hasrownames (B)
        error ('table.congruentize: Input B has row names but input A does not');
      endif
      varsOnlyInA = setdiff (A.VariableNames, B.VariableNames);
      if !isempty (varsOnlyInA)
        error ('table.congruentize: Input A has variables not present in B: %s', ...
          strjoin (varsOnlyInA, ', '));
      endif
      varsOnlyInB = setdiff (B.VariableNames, A.VariableNames);
      if !isempty (varsOnlyInB)
        error ('table.congruentize: Input B has variables not present in A: %s', ...
          strjoin (varsOnlyInB, ', '));
      endif

      outA = A;
      outB = B;
      [~,loc] = ismember (A.VariableNames, outB.VariableNames);
      outB = subsetvars (outB, loc);
      
      endfunction

    function [C, ia, ib] = union (A, B)
      %UNION Set union
      %
      % [C, ia, ib] = union (A, B)
      %
      % Computes the union of two tables. The union is defined to be the unique
      % values which are present in either of the the two input tables.
      %
      % Returns:
      % C - A table containing all the unique row values present in A or B.
      % ia - Row indexes into A of the rows from A included in C.
      % ib - Row indexes into B of the rows from B included in C.
      
      % Input handling
      [A, B] = congruentize (A, B);
            
      % Set logic
      [pkA, pkB] = proxykeysForMatrixes (A, B);
      [~, ia, ib] = union (pkA, pkB, 'rows');
      C = [subsetRows(A, ia); subsetRows(B, ib)];      
    endfunction
    
    function [C, ia, ib] = intersect (A, B)
      %INTERSECT Set intersection
      %
      % [C, ia, ib] = intersect (A, B)
      %
      % Computes the intersection of two tables. The intersection is defined to 
      % be the unique values which are present in both of the two input tables.
      %
      % Returns:
      % C - A table containing all the unique row values present in A and B.
      % ia - Row indexes into A of the rows from A included in C.
      % ib - Row indexes into B of the rows from B included in C.
      
      % Input handling
      [A, B] = congruentize (A, B);
            
      % Set logic
      [pkA, pkB] = proxykeysForMatrixes (A, B);
      [~, ia, ib] = intersect (pkA, pkB, 'rows');
      C = [subsetRows(A, ia); subsetRows(B, ib)];      
    endfunction
    
    function [C, ia, ib] = setxor (A, B)
      %SETXOR Set exclusive OR
      %
      % [C, ia, ib] = setxor (A, B)
      %
      % Computes the setwise exclusive OR of two tables. The set XOR is defined
      % as the set of rows that are present in one array or another, but not in
      % both.
      %
      % Returns:
      % C - A table containing the row values in the set XOR of A and B.
      % ia - Row indexes into A of the rows from A included in C.
      % ib - Row indexes into B of the rows from B included in C.
      
      % Input handling
      [A, B] = congruentize (A, B);
            
      % Set logic
      [pkA, pkB] = proxykeysForMatrixes (A, B);
      [~, ia, ib] = setxor (pkA, pkB, 'rows');
      C = [subsetRows(A, ia); subsetRows(B, ib)];      
    endfunction
    
    function [C, ia] = setdiff (A, B)
      %SETDIFF Set difference
      %
      % [C, ia] = setdiff (A, B)
      %
      % Computes the set difference of two tables. The set difference is defined 
      % as the set of rows in A that are not in B.
      %
      % Returns:
      % C - A table containing the rows in A that were not in B.
      % ia - Row indexes into A of the rows that are in C.
      
      % Input handling
      [A, B] = congruentize (A, B);
            
      % Set logic
      [pkA, pkB] = proxykeysForMatrixes (A, B);
      [~, ia] = setdiff (pkA, pkB, 'rows');
      C = subsetRows (A, ia);
    endfunction
    
    function [tf, loc] = ismember (A, B)
      %ISMEMBER Set membership (table rows that are members of another table)
      %
      % [tf, loc] = ismember (A, B)
      %
      % Finds rows in A that are members of B.
      %
      % Returns:
      % tf - A logical vector indicating whether each A(i,:) was present in B.
      % loc - Indexes into B of rows that were found.
      
      % Input handling
      [A, B] = congruentize (A, B);
            
      % Set logic
      [pkA, pkB] = proxykeysForMatrixes (A, B);
      [tf, loc] = ismember (pkA, pkB, 'rows');
    endfunction
    
    % Missing values
    
    function out = ismissing (this, indicator)
      %ISMISSING Find missing values
      %
      % Finds missing values in this' variables.
      %
      % All variables in this must be vectors. (This is due to the requirement
      % that size(out) == size(this).)
      %
      % Returns a logical array the same size as this.
      mustBeA (this, 'table');
      if nargin > 1
        %TODO: We need to support heterogeneous indicator inputs here
        %TODO: Probably rewrite this just to delegate indicator support to global
        % ismissing().
        error ('table.ismissing: indicator input is not implemented');
      endif
      mustBeAllColVectorVars (this);
      out = false (size (this));
      for i = 1:width (this)
        out(:,i) = ismissing (this.VariableValues{i});
      endfor
    endfunction
    
    function [out, tf] = rmmissing (this, varargin)
      %RMMISSING Remove rows with missing values
      %
      % [out, tf] = rmmissing (this)
      % [out, tf] = rmmissing (this, indicator)
      % [out, tf] = rmmissing (..., 'DataVariables',vars)
      %
      % Removes rows with missing values.
      %
      % If the 'DataVariables' option is given, only the data in the specified
      % variables is considered.
      %
      % Returns:
      % out - A table the same as this, but with rows with missing values removed.
      % tf - A logical index vector indicating which rows were removed.
      [opts, args] = peelOffNameValueOptions (varargin, {'DataVariables','MinNumMissing'});
      hasIndicator = false;
      if numel (args) > 1
        error ('table.rmmissing: Too many arguments.');
      elseif numel (args) == 1
        hasIndicator = true;
        indicator = args{1};
      endif
      if isfield (opts, 'MinNumMissing')
        error ('table.missing: The MinNumMissing option is not supported for tables.');
      endif
      
      if isfield (opts, 'DataVariables')
        dataVarsSelector = opts.DataVariables;
        if isa (dataVarsSelector, 'function_handle')
          error ('table.rmmissing: function handle DataVariables option is not implemented.');
        else
          ixDataVars = resolveVarRef (dataVarsSelector);
        endif
      else
        ixDataVars = 1:width (this);
      endif
      
      dataVals = subsetvars (this, ixDataVars);
      if hasIndicator
        tfMissing = ismissing (dataVals, indicator);
      else
        tfMissing = ismissing (dataVals);
      endif
      tfRowHasMissing = any (tfMissing, 2);
      out = subsetRows (this, ~tfRowHasMissing);
      tf = tfRowHasMissing;
    endfunction

    function out = standardizeMissing (this, indicator, varargin)
      %STANDARDIZEMISSING Insert standard missing values
      %
      % This method depends on the implementation of the global standardizeMissing()
      % function, which is not yet implemented in Octave, so any use of this method
      % is likely to error out.
      narginchk (2, 4);
      mustBeA (this, 'table');
      [opts, args] = peelOffNameValueOptions (varargin, {'DataVariables'});
      if ~isempty (args)
        error ('table.standardizeMissing: Too many input arguments');
      endif

      if isfield (opts, 'DataVariables')
        dataVarsSelector = opts.DataVariables;
        if isa (dataVarsSelector, 'function_handle')
          error ('table.standardizeMissing: function handle DataVariables option is not implemented.');
        else
          ixDataVars = resolveVarRef (dataVarsSelector);
        endif
      else
        ixDataVars = 1:width (this);
      endif
      
      out = this;
      for i = 1:numel (ixDataVars)
        ixDataVar = ixDataVars(i);
        val = this.VariableValues{ixDataVar};
        standardized = standardizeMissing (val, indicator);
        out.VariableValues{ixDataVar} = standardized;
      endfor
      
    endfunction

    % Function application
    
    function out = varfun (func, A, varargin)
      %VARFUN Apply function to table variables
      %
      % out = varfun (func, A)
      % out = varfun (..., 'OutputFormat', outputFormat)
      % out = varfun (..., 'InputVariables', vars)
      % out = varfun (..., 'ErrorHandler', errorFcn)
      mustBeA (A, 'table');
      validOptions = {'InputVariables', 'GroupingVariables', 'OutputFormat', 'ErrorHandler'};
      [opts, args] = peelOffNameValueOptions (varargin, validOptions);
      unimplementedOptions = {'GroupingVariables', 'ErrorHandler'};
      for i = 1:numel (unimplementedOptions)
        if isfield (opts, unimplementedOptions{i})
          error ('table.varfun: Option %s is not yet implemented.', unimplementedOptions{i});
        endif
      endfor
      if ~isa (func, 'function_handle')
        error ('table.varfun: func must be a function handle; got a %s', class (func));
      endif
      outputFormat = 'table';
      if isfield (opts, 'OutputFormat')
        outputFormat = opts.OutputFormat;
      endif
      validOutputFormats = {'table','uniform','cell'};
      if ~ismember (outputFormat, validOutputFormats);
        error ('table.varfun: Invalid OutputFormat: %s. Must be one of: %s', ...
          outputFormat, strjoin (validOutputFormats, ', '));
      endif
      errorHandler = [];
      if isfield (opts, 'ErrorHandler')
        if ~isa (opts.ErrorHandler, 'function_handle')
          error ('table.varfun: ErrorHandler must be a function handle; got a %s', ...
            class (opts.ErrorHandler));
        endif
        errorHandler = opts.ErrorHandler;
      endif
      
      tbl = A;
      if isfield (opts, 'InputVariables')
        ixInVars = resolveVarRef (tbl, opts.InputVariables);
      else
        ixInVars = 1:width (tbl);
      endif
      
      outVals = cell (1, numel (ixInVars));
      for i = 1:numel (ixInVars)
        ixInVar = ixInVars(i);
        varVal = tbl.VariableValues{ixInVar};
        if isempty (errorHandler)
          fcnOut = feval (func, varVal);
        else
          try
            fcnOut = feval (func, varVal);
          catch err
            fcnOut = feval (errorHandler, varVal);
          end_try_catch
        endif
        outVals{i} = fcnOut;
      endfor

      switch outputFormat
        case 'cell'
          out = outVals;
        case 'table'
          out = table (outVals{:}, 'VariableNames', tbl.VariableNames);
        case 'uniform'
          tfScalar = cellfun('isscalar', outVals);
          if ~all (tfScalar)
            ixFirstBad = find(~tfScalar, 1);
            error (['table.varfun: For OutputFormat ''uniform'', all function ' ...
              'outputs must be scalar; output %d was %d long'], ...
              ixFirstBad, numel (outVals{ixFirstBad}));
          endif
          outClasses = cellfun ('class', outVals, 'UniformOutput', false);
          uOutClasses = unique (outClasses);
          if numel (uOutClasses) > 1
            error (['table.varfun: For OutputFormat ''uniform'', all function ' ...
              'outputs must be the same type; got a mix of: %s'], ...
              strjoin (uOutClasses, ', '));
          endif
          out = cat (2, outVals{:});
      endswitch
    endfunction
    
    function out = rowfun (func, A, varargin)
      %ROWFUN Apply function to table rows
      %
      % out = rowfun (func, A)
      % out = rowfun (..., Name,Value, ...)
      %
      % TODO: Document all the Name/Value options; there's a bunch of them.
      
      % Input handling
      mustBeA (A, 'table');
      validOptions = {'InputVariables', 'GroupingVariables', 'OutputFormat', ...
        'SeparateInputs', 'ExtractCellContents', 'OutputVariableNames', ...
        'NumOutputs', 'ErrorHandler'};
      [opts, args] = peelOffNameValueOptions (varargin, validOptions);
      unimplementedOptions = {'InputVariables', 'GroupingVariables', ...
        'SeparateInputs', 'ExtractCellContents', 'OutputVariableNames', ...
        'NumOutputs'};
      for i = 1:numel (unimplementedOptions)
        if isfield (opts, unimplementedOptions{i})
          error ('table.rowfun: Option %s is not yet implemented.', unimplementedOptions{i});
        endif
      endfor
      if ~isa (func, 'function_handle')
        error ('table.rowfun: func must be a function handle; got a %s', class (func));
      endif
      outputFormat = 'table';
      if isfield (opts, 'OutputFormat')
        outputFormat = opts.OutputFormat;
      endif
      validOutputFormats = {'table','uniform','cell'};
      if ~ismember (outputFormat, validOutputFormats);
        error ('table.rowfun: Invalid OutputFormat: %s. Must be one of: %s', ...
          outputFormat, strjoin (validOutputFormats, ', '));
      endif
      errorHandler = [];
      if isfield (opts, 'ErrorHandler')
        if ~isa (opts.ErrorHandler, 'function_handle')
          error ('table.rowfun: ErrorHandler must be a function handle; got a %s', ...
            class (opts.ErrorHandler));
        endif
        errorHandler = opts.ErrorHandler;
      endif
      tbl = A;
      
      error('table.rowfun: This function is not yet implemented.');
      
      % Function application
      
      % Output packaging
      
    endfunction
    
    function [G, TID] = findgroups (this)
      %FINDGROUPS Find groups within a table's row values and get group numbers
      %
      % [G, TID] = findgroups (this)
      %
      % Returns:
      % G - A double column vector of group numbers created from this.
      % TID - A table containing the row values corresponding to the group numbers.
      [TID, ~, G] = unique (this);
    endfunction
    
    function out = evalWithVars (this, expr)
      %EVALWITHVARS Evaluate an expression with this' variables in a workspace
      %
      % out = evalWithVars (this, expr)
      %
      % Evaluates the M-code expression expr in a workspace where all of this'
      % variables have been assigned to workspace variables.
      %
      % As an implementation detail, the workspace will also contain some variables
      % that are prefixed and suffixed with "__". So try to avoid those in your
      % table variable names.
      %
      % Examples:
      % [s,p,sp] = table_examples.SpDb
      % tmp = join (sp, p);
      % shipment_weight = evalWithVars (tmp, "Qty .* Weight")
      if ~ischar (expr)
        error ('table.evalWithVars: expr must be char; got a %s', class (expr));
      endif
      out = __eval_expr_with_table_vars_in_workspace__ (this, expr);
    endfunction
    
    function out = restrict (this, arg)
      %RESTRICT Subset rows based on index or variable expression
      %
      % out = restrict (this, index)
      % out = restrict (this, expr)
      %
      % Subsets this table row-wise, using either an index vector or an expression
      % involving this' variables.
      %
      % If the argument is a numeric or logical vector, it is interpreted as an
      % index into the rows of this. (Just as with `subsetRows (this, index)`.)
      %
      % If the argument is a char, then it is evaulated as an M-code expression,
      % with all of this' variables available as workspace variables, as with
      % `evalWithVars`. The output of expr must be a numeric or logical index
      % vector (This form is a shorthand for 
      % `out = subsetRows (this, evalWithVars (this, expr))`.)
      %
      % TODO: Decide whether to name this to "where" to be more like SQL instead
      % of relational algebra.
      %
      % Examples:
      % [s,p,sp] = table_examples.SpDb;
      % prettyprint (restrict (p, 'Weight >= 14 & strcmp(Color, "Red")'))
      if ischar (arg)
        rowIx = evalWithVars (this, arg);
        out = subsetRows (this, rowIx);
      elseif isnumeric (arg) || islogical (arg)
        out = subsetRows (this, arg);
      endif
    endfunction

    % 
    % Prohibited operations
    
    % TODO: Some of these could probably actually be allowed in certain restricted
    % circumstances based on the type and shape of values in this. Consider
    % allowing them.

    function out = transpose (this, varargin)
      error ('Function transpose is not supported for tables');
    end

    function out = ctranspose (this, varargin)
      error ('Function ctranspose is not supported for tables');
    end

    function out = circshift (this, varargin)
      error ('Function circshift is not supported for tables');
    end

    function out = length (this, varargin)
      error ('Function length is not supported for tables');
    end

    function out = shiftdims (this, varargin)
      error ('Function shiftdims is not supported for tables');
    end

    function out = reshape (this, varargin)
      error ('Function reshape is not supported for tables');
    end

    function out = resize (this, varargin)
      error ('Function resize is not supported for tables');
    end

    function out = vec (this, varargin)
      error ('Function vec is not supported for tables');
    end
  end
  
  methods (Access = private)
    function out = getVar (this, name)
      [tf, loc] = ismember (name, this.VariableNames);
      if ~tf
        error ('table has no variable named ''%s''', name);
      endif
      out = this.VariableValues{loc};
    endfunction

    function mustBeAllSameVars (varargin)
      %MUSTBEALLSAMEVARS Require that all inputs have the same-named columns
      args = varargin;
      if isempty (args)
        return
      endif
      varNames = args{1}.VariableNames;
      for i = 2:numel (args)
        if ~isequal (varNames, args{i}.VariableNames)
          error ('Inconsistent VariableNames.\n  Input 1: %s\n  Input %d: %s', ...
            strjoin (varNames, ', '), i, strjoin (args{i}.VariableNames, ', '));
        endif
      endfor
    endfunction
    
    function mustBeAllColVectorVars (this)
      %MUSTBEALLCOLVECTORVARS Require that all vars in this are vectors, not matrixes
      for i = 1:width (this)
        val = this.VariableValues{i};
        if size (val, 2) ~= 1
          error ('All variables in input must be vectors, but variable %d (''%s'') has %d columns', ...
            i, this.VariableNames{i}, size (val, 2));
        endif
      endfor
    endfunction
  endmethods
  
  methods
    function [pkA, pkB] = proxykeysForMatrixes (A, B)
      %PROXYKEYSFORMATRIXES Compute row proxy keys for tables
      if nargin == 1
        mustBeA (A, 'table');
        pkA = proxykeysForOneTable (A);
      else  
        mustBeA (A, 'table');
        mustBeA (B, 'table');
        if !isequal (A.VariableNames, B.VariableNames)
          error ('table.proxykeysForMatrixes: Inconsistent variable names in inputs');
        endif
        [pkA, pkB] = proxykeysForTwoTables (A, B);
      endif
    endfunction
  endmethods

  methods (Access = private)
    function out = proxykeysForOneTable (this)
      varProxyKeys = cell (size (this.VariableNames));
      for iVar = 1:numel (this.VariableNames);
        varProxyKeys{iVar} = proxykeysForMatrixes (this.VariableValues{iVar});
      endfor
      out = cat (2, varProxyKeys{:});
    endfunction
    
    function [pkA, pkB] = proxykeysForTwoTables (A, B)
      varProxyKeysA = cell (size (A.VariableNames));
      varProxyKeysB = cell (size (B.VariableNames));
      for iVar = 1:numel (A.VariableNames)
        [varProxyKeysA{iVar}, varProxyKeysB{iVar}] = proxykeysForMatrixes (...
          A.VariableValues{iVar}, B.VariableValues{iVar});
      endfor
      pkA = cat (2, varProxyKeysA{:});
      pkB = cat (2, varProxyKeysB{:});
    endfunction
  endmethods
endclassdef

function out = prettyprint_summary_data (s)
  error ('table.prettyprint_summary_data: This is not yet implemented.');
endfunction
