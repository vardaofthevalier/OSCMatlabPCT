function [ exit_code ] = configureJob(jobName, walltime, logs, mail, filespace)

% Non-GUI version of configureJob

exit_code = -1;

% First, make sure that the correct number of arguments was supplied

if nargin > 5
    err = 'Too many input arguments... configuration tool will now exit.';
    disp(err)
    return;
elseif nargin < 1
    err ='Not enough input arguments... configuration tool will now exit.';
    disp(err)
    return;
end

% Set some global variables for the config tools (if they haven't been
% created yet) and create all directories needed for the new job

configRoot = fullfile(pwd, 'config');

if ~exist(fullfile(configRoot, 'global_environment.mat'), 'file')
    
    pctConfigRoot = pwd;
    scriptRoot = fullfile(pwd, 'scripts');
    logRoot = fullfile(pwd, 'logs');
    jobRoot = fullfile(pwd, 'jobs');
    cpRoot = fullfile(pwd, 'clusterProfiles');

else
    load(fullfile(configRoot, 'global_environment.mat'));

end

% Create variables for the absolute pathnames of job-specific
% directories.  These will later be saved in a job-specific environment
% file for later use.  

absConfigDir = fullfile(configRoot, jobName);
absScriptDir = fullfile(scriptRoot, jobName);
absLogDir = fullfile(logRoot, jobName);
absJobDir = fullfile(jobRoot, jobName);

% Make sure this job hasn't already been configured
% Note to self: add option to overwrite/modify the existing configuration

if exist(fullfile(absJobDir), 'dir')
    msg = 'A job by this name has already been configured. Would you like to configure a new job (C), or modify the existing configuration (M)?';
    exitLoop = false;
    
    while ~exitLoop
        answer = input(msg);
        waitfor(answer);
        
        if strcmp(answer, 'C') | strcmp(answer, 'c')
            msg = 'Enter a unique name for your new job: ';
            jobName = input(msg);
            waitfor(jobName);
    
            while size(jobName) == 0
                msg = 'No job name provided... Please choose a unique job name.';
                jobName = input(msg);
                waitfor(jobName);
            end
    
            jobName = jobName{1};
            exitLoop = true;
        
        elseif strcmp(answer, 'M') | strcmp(answer, 'm')
            if exist(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)), 'file')
                load(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)));
                exitLoop = true;
            else
                msg = 'Oops, it looks like your previous configuration was corrupted.  Try cleaning up and then reconfiguring your job.';
                disp(msg)
                return;
            end    
        else
            msg = 'Are you sure you want to cancel?  (Y/N) All progress so far will be lost.';
            answer = input(msg);
            
            if strcmp(answer, 'Y') | strcmp(answer, 'y')
                return;
            else
                msg = 'Would you like to configure a new job, or modify the existing configuration?';
            end
        end
    end
else
    % Create the needed job directories
    mkdir(absConfigDir);
    mkdir(absScriptDir);
    mkdir(absLogDir);
    mkdir(absJobDir);
end

% Copy template configuration files into the job-specific configuration
% directory

allMatlabScripts = sprintf('%s/*.m', configRoot);
allShellScripts = sprintf('%s/*.sh', configRoot);

copyfile(allMatlabScripts, absConfigDir);
copyfile(allShellScripts, absConfigDir);

% Check whether the appropriate cluster profile has been imported.
% If not, import it.  

if ~exist('clusterProfile', 'var')

    allProfiles = parallel.clusterProfiles;
    [~, totalProfiles] = size(allProfiles);

    foundProfile = false;

    for index = 1:totalProfiles
        if strcmp(allProfiles{index}, 'genericNonSharedOakleyIntel')
            foundProfile = true;
            break;
        end
    end

    if ~foundProfile
        disp('Importing generic cluster profile for Oakley...')
        clusterProfile = parallel.importProfile(fullfile(cpRoot, 'genericNonSharedOakleyIntel.settings'));
    else
        clusterProfile = 'genericNonSharedOakleyIntel';
    end
end

% Here the user will import job dependencies into their scripts directory,
% and a cell array of filenames of job dependencies will be created for saving in the job's
% environment file.

disp('You will now be asked to select job dependencies to attach to your job.')

attachedFiles = {};

absPath = input('Enter the absolute path to your job''s entry function/script on your local host: ');
[entryFunctionFilePath, entryFunctionName, ext] = fileparts(absPath);

% Check to see if the user's input was valid

isValid = true;

if isempty(entryFunctionFilePath) | isempty(entryFunctionName) | ~strcmp(ext, '.m')
    isValid = false;


while ~isValid
    disp('You must select a valid entry function for your job')
    absPath = input('Enter the absolute path to your job''s entry function/script on your local host: ');
    [entryFunctionFilePath, entryFunctionName, ext] = fileparts(absPath);

    % Check to see if the user's input was valid

    isValid = true;

    if isempty(entryFunctionFilePath) | isempty(entryFunctionName) | ~strcmp(ext, '.m')
        isValid = false;
end


% Combine variables to get full absolute path to script, then copy it to
% the script directory

copyfile(entryFunctionFilePath, absConfigDir);

% Reset the location of the entry function to the new location in the
% config directory.

entryFunctionFilePath = fullfile(absConfigDir, entryFunctionName);

% Determine if the entry point is a function or a script

isFunction = true;

try
    nargin(entryFunctionFilePath);
catch err
    isFunction = false;
end

if isFunction
    functionInputs = nargin(entryFunctionFilePath);
    functionOutputs = nargout(entryFunctionFilePath);

% Continue attaching job dependencies.  Job dependent files other than the
% entry function will be copied to the job script directory.  

answer = input('Would you like to add another dependency to your job? (Y/N)');

array_index = 1;

while strcmp(answer, 'Y') | strcmp(answer, 'y')
    % Note to self: start here 
    absPath = input('Enter the absolute path to a job dependency on your local host: ');
    [filePath, fileToAttach, ext] = fileparts(absPath);
    
    % Combine variables to get full absolute path to script, then copy it to
    % the script directory
    filePath = fullfile(filePath, fileToAttach);
    copyfile(filePath, absScriptDir);
    
    % Add files located in the script directory to attachedFiles
    attachedFiles{array_index} = fullfile(absScriptDir, fileToAttach);
    array_index = array_index + 1;
    
    answer = input('Would you like to add another dependency to your job? (Y/N)');
    
end   

% Get the local and remote job storage locations for this particular job's
% output log files, which will be generated by MATLAB at execution time.  

disp('Your job needs both a local storage location and a remote storage location on the remote host (Oakley).  If you need to create a new directory on OSC systems for this purpose, please log in and create it before continuing.');

localJobStoragePath = input('Enter the absolute path to a local directory for job log output: ');
remoteJobStoragePath = input('Enter the absolute path to a remote directory for job log output: ');

% Extract remoteJobStoragePath from the cell array

remoteJobStoragePath = remoteJobStoragePath{1};

% Organize strings for inserting into configuration files

jobNameCopy = jobName;
jobName = cellstr(jobName);
nameFlag = cellstr('-N');

C = cell(1, 2);
C = [ nameFlag jobName ];

nameArg = strjoin(C);

switch nargin
    case 2
        walltime = '-l walltime=01:00:00';
        logArg = '-j oe';
    case 3
        walltime = strcat('-l walltime=', walltime);
        logArg = '-j oe';
    case 4
        walltime = strcat('-l walltime=', walltime);
        
        logs = cellstr(logs);
        logFlag = cellstr('-j');
        
        C = cell(1, 2);
        C = [ logFlag logs ];
        logArg = strjoin(C);
        
    case 5
        walltime = strcat('-l walltime=', walltime);
        
        logs = cellstr(logs);
        logFlag = cellstr('-j');
        
        C = cell(1, 2);
        C = [ logFlag logs ];
        logArg = strjoin(C);
        
        mail = cellstr(mail);
        mailFlag = '-m';
        
        C = [ mailFlag mail ];
        mailArg = strjoin(C);
        mailArg = cellstr(mailArg);
        
    case 6
        walltime = strcat('-l walltime=', walltime);
        
        logs = cellstr(logs);
        logFlag = cellstr('-j');
        
        C = cell(1, 2);
        C = [ logFlag logs ];
        logArg = strjoin(C);
        
        mail = cellstr(mail);
        mailFlag = '-M';
        
        C = [ mailFlag mail ];
        mailArg = strjoin(C);
        
        filespace = strcat('-l filespace=', filespace);
        filespace = cellstr(filespace);
        
end

nameArg = cellstr(nameArg);
walltime = cellstr(walltime);
logArg = cellstr(logArg);

% Prepare to modify job-specific configuration files

cd(absConfigDir);

% Create a submit arguments string, and handle any additional submit
% arguments that may have been specified

C = cell(1, 3);
C = [ nameArg, walltime, logArg ];
submitArgs = strjoin(C);

additionalArgs = '';

if (exist('mail', 'var') == 1)
    additionalArgs = mailArg;
end

if (exist('filespace', 'var') == 1)
    additionalArgs = cellstr(additionalArgs);
    C = cell(1, 2);
    C = [ additionalArgs, filespace ];
    additionalArgs = strjoin(C);
end

submitArgs = cellstr(submitArgs);
additionalArgs = cellstr(additionalArgs);

C = cell(1, 2);
C = [ submitArgs additionalArgs ];
submitArgs = strjoin(C);

% Modify the configuration files according to the resource requests

insert = sprintf('additionalSubmitArgs = cellstr(additionalSubmitArgs); temp = cellstr(''%s''); C = cell(1, 2); C = [ additionalSubmitArgs temp ]; additionalSubmitArgs = strjoin(C);', submitArgs);

csf = fopen('communicatingSubmitFcnIntel.m');
newcsf = fopen('temp1.m', 'w');

while ~feof(csf)
    nextLine = fgets(csf);
    if strncmp(nextLine,'% INSERT MORE SUBMIT ARGS HERE %', 32) == 1
        fprintf(newcsf, '%s', insert);
    else
        fprintf(newcsf, '%s', nextLine);
    end
end

isf = fopen('independentSubmitFcn.m');
newisf = fopen('temp2.m', 'w');

insert = sprintf('    additionalSubmitArgs = ''%s'';', submitArgs);

while ~feof(isf)
    nextLine = fgets(isf);
    if strncmp(nextLine,'    % INSERT MORE SUBMIT ARGS HERE %', 36) == 1
        fprintf(newisf, '%s', insert);
    else
        fprintf(newisf, '%s', nextLine);
    end
end

fclose('all');


movefile('temp1.m', 'communicatingSubmitFcnIntel.m');
movefile('temp2.m', 'independentSubmitFcn.m');

% Return to the top level directory

cd(pctConfigRoot);

% Print a message stating that the modifications were successful

msg = sprintf('Job "%s" was successfully configured.', jobNameCopy);
disp(msg);

msg = sprintf('Would you like to launch your job now? (Y/N)');
launchOrSave = input(msg);

if strcmp(launchOrSave,'Y') | strcmp(launchOrSave,'y')
   workers = input('Choose a number of MATLAB workers for your job (Max: 32)');
   launchJob(jobName, workers);
end

% Save environment for later use
save(fullfile(configRoot, 'global_environment'), 'pctConfigRoot', 'jobRoot', 'scriptRoot', 'logRoot', 'configRoot', 'cpRoot', 'clusterProfile');
save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)), 'absConfigDir', 'absJobDir', 'absLogDir', 'absScriptDir','entryFunctionName', 'entryFunctionFilePath', 'attachedFiles', 'localJobStoragePath', 'remoteJobStoragePath', 'isFunction');

if isFunction
    save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)),'functionInputs', 'functionOutputs', '-append');
end

exit_code = 0;

end

        
  
