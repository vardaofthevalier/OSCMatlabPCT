clc
clear
%Non-GUI Test Script
cd 'C:/Users/cmiller/Documents/GitHub/OSCMatlabPCT'
ecode = OSCMatlabPCT.configureJob('testjob','00:30:00','oe','cmiller@osc.edu','8gb');
% OSCMatlabPCT.cleanupJob('all')