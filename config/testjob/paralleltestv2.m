function [ dataout ] = paralleltestv2( )
%Tests the control loop for different amplitudes, frequencies, and phase
%offsets in parallel
row = 25;
col = 25;
plane = 25;
parfor it = 1: row*col*plane
    dataout{it} = parsim( row, col, plane, it )
end
end
