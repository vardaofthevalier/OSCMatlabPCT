function [ exit_code ] = cleanupJob( jobName )

exit_code = -1;

% Load environment.mat

if ~exist('pctConfigRoot', 'var')
    configDir = fullfile(pwd, 'config');
    load (fullfile(configDir, jobName, 'environment.mat'));
end

% Get confirmation from user that they want to permanently delete the job

prompt = sprintf('Are you sure you want to delete job "%s"?', jobName);
button = questdlg(prompt, '', 'Yes', 'No', 'No');

if button == 'Yes'

    if exist(absJobDir, 'dir') == 7
        rmdir(fullfile(absJobDir, jobName), 's');
        rmdir(fullfile(absLogDir, jobName), 's');
        rmdir(fullfile(absScriptDir, jobName), 's');
        
    else
        disp('No job by that name exists.')
        return;
    end
    
exit_code = 0;



end

