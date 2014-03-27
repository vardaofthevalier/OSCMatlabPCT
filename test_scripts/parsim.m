function [ dataout] = parsim( row, col, plane, it )
%Tests the control loop for different amplitudes, frequencies, and phase
%offsets in parallel
[r,s,u,] = ind2sub([row,col,plane],it);
ampin = linspace(5,5000,row);
freqin = linspace(10,10000,col);
phasein = linspace(10*(pi/180),360*(pi/10),plane);
amp = ampin(r);
freq = freqin(s);
phi = phasein(u);
model = 'controllooppar';
load_system(model);
mws = get_param(bdroot, 'modelworkspace');
mws.assignin('amp',amp)
mws.assignin('freq',freq)
mws.assignin('phi',phi)
%Start the simulation
simout = sim(model, 'SimulationMode','normal');
dataout = [simout.get('tout'),simout.get('yout'),];
dataout(1,3) = amp;
dataout(2,3) = freq;
dataout(3,3) = phi;
end

