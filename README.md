# FIMAS
Fluorescent Imaging Analysis Software

Perform basic and specific analysis procedures on fluorescent microscopy and fluorescent lifetime imaging microscopy (FLIM) data.  It requires MATLAB with image processing and statistical toolboxes.  MATLAB version 2015 and above under windows environment is preferred.  Other versions and under OSX or Linux may have some bugs with regard to jvm display.

It can import fluorescent data from Olympus (.oib), Biorad (.pic), Femtonics (.mes), TIFF (.tiff,.tif), Excel (.xls,.xlsx), ASCII files.  Most metadata information should be retain but maybe under appended field names.  Use F1 hotkey to open metadata window for selected data item.

FLIM data from Becker & Hickl (.spc and .sdt), Picoquant (.ptu) can be imported both as single photon counting format or FLIM decay trace format.  Certain operations cannot be performed on single photon counting format.

All operations on data can be found in the ./usr/ops/ location either named as data_*.m or op_*.m.  Prefix data_ operates on the data itself and will not create a new data item if the process is reversible (e.g. data_flipdim.m, data_shift.m, data_rearrangedim.m).  data_ operators that perform irreversible operations will create new data item (e.g. data_auto_align.m, data_bin.m).  Prefix op_ operators always involves transform existing data to another set of parameters, hence new data items will always be created.  Some operations have not been completed, please use with care.
