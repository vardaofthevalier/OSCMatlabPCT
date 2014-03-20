clc
clear
matlabpool open local 2
%Tests the control loop for different amplitudes, frequencies, and phase
%offsets in parallel
row = 2;
col = 2;
plane = 2;
parfor it = 1: row*col*plane
    dataout{it} = parsim( row, col, plane, it )
end
matlabpool close