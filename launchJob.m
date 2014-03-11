function [ status ] = launchJob(jobName, totalWorkers)

status = -1;

% Check configuration and load environment if if exists

if ~exist('pctConfigRoot', 'var')
    configRoot = fullfile(pwd, 'config');
    
    if exist(fullfile(configRoot, 'global_environment.mat'), 'file')
        load (fullfile(configRoot, 'global_environment.mat'));
        
    else
        msg = 'It appears that no global environment exists yet.  Run the configuration script at least once to generate the global environment.';
        err = errordlg(msg);
        waitfor(err);
        return;
    end
    
    if exist(fullfile(configRoot, jobName, sprintf('%s_environment.mat', jobName)), 'file')
        load(fullfile(configRoot, jobName, sprintf('%s_environment.mat', jobName)));
    else
        msg = 'No configuration for this job exists.  Run the configuration script to configure your job.';
        err = errordlg(msg);
        waitfor(err);
        return;
    end
end
    
% Use the cluster profile specified in the configuration to create a new
% cluster object

newCluster = parcluster(clusterProfile);

% Update the cluster profile so that the job logs are saved in the right
% place on the local and remote hosts

newCluster.JobStorageLocation = localJobStoragePath;

if totalWorkers > 11
    newCluster.CommunicatingSubmitFcn{3} = remoteJobStoragePath;
    
else
    newCluster.IndependentSubmitFcn{3} = remoteJobStoragePath;
end

saveProfile(newCluster);


% Navigate to the job configuration directory

cd(absConfigDir);

% Create a blank workspace to pass to the workers, and determine if the
% entry file is a script or function

workspace = struct;

if exist(entryFunctionFilePath, 'file')
    if isFunction
        % Syntax for use if entryFunctionName is a function
        
        batchCmd = sprintf('%s', 'batch(newCluster, entryFunctionName, functionOutputs, functionInputs, ''matlabpool'', totalWorkers - 1, ''AdditionalPaths'', sprintf(''%s'', absScriptDir), ''AttachedFiles'', attachedFiles)');
    else
        % However, if entryFunctionName refers to a script, we need to change
        % the syntax of the batch command slightly
        
        batchCmd = sprintf('%s', 'batch(newCluster, entryFunctionName, ''matlabpool'', totalWorkers - 1, ''Workspace'', workspace, ''AdditionalPaths'', sprintf(''%s'', absScriptDir), ''AttachedFiles'', attachedFiles)');
    end
else
    disp('Entry function file not found... try reconfiguring your job.')
    return;
end 

newJob = eval(batchCmd);
jobData = getJobClusterData(newCluster, newJob);

msg = sprintf('Job %s has been submitted!', jobData.ClusterJobIDs{1});
disp(msg)

wait(newJob);

% Get the output, and save

msg = 'Gathering results...';
disp(msg)

results = fetchOutputs(newJob);

% Extract just the data from results, and then save them in the job
% directory

results = results{1};

outputFilename = strcat(jobName, '_Results');
outputDir = fullfile(absJobDir, outputFilename);

save(outputDir, 'results');

msg = sprintf('Results file "%s" was saved in %s.mat.', outputFilename, outputDir);
disp(msg)

status = 0;



