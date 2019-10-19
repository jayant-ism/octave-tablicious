MKOCTFILE ?= mkoctfile

.PHONY: all
all: __oct_time_binsearch__.oct csvexplode.oct csv2cell.oct csvconcat.oct cell2csv.oct col2num.oct num2col.oct

%.oct: %.cc
	$(MKOCTFILE) $<

.PHONY: clean
clean:
	$(RM) -rf *.o core octave-core *.oct *.mex *~

.PHONY: distclean
distclean: clean