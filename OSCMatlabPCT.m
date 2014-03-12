classdef OSCMatlabPCT
    
    methods (Static)
        
        function [ exit_code ] = configureJob(jobName, walltime, logs, mail, filespace)
            if nargin == 0
                exit_code = OSCMatlabPCT.configureDisplayOn()
            else
                exit_code = OSCMatlabPCT.configureDisplayOff(jobName, walltime, logs, mail, filespace)
            end
        end
           
        
        function [ exit_code ] = configureDisplayOff(jobName, walltime, logs, mail, filespace)

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
                archiveRoot = fullfile(pwd, 'archive');
                scriptRoot = fullfile(pwd, 'scripts');
                logRoot = fullfile(pwd, 'logs');
                jobRoot = fullfile(pwd, 'jobs');
                cpRoot = fullfile(pwd, 'clusterProfiles');
                jobsToDate = {};

            else
                % If a global environment file exists, we need check to make sure that absolute paths in the global
                % environment are correct before loading it, just in case the
                % config tools parent directory has been moved.

                tempVar = load(fullfile(configRoot, 'global_environment.mat'), 'configRoot');

                if ~strcmp(tempVar, configRoot)
                    % Reset the values in the global environment file to
                    % reflect where you actually are
                    load(fullfile(configRoot, 'global_environment.mat'));

                    pctConfigRoot = pwd;
                    archiveRoot = fullfile(pwd, 'archive');
                    scriptRoot = fullfile(pwd, 'scripts');
                    logRoot = fullfile(pwd, 'logs');
                    jobRoot = fullfile(pwd, 'jobs');
                    cpRoot = fullfile(pwd, 'clusterProfiles');
                    
                end

            end

            % Create variables for the absolute pathnames of job-specific
            % directories.  These will later be saved in a job-specific environment
            % file for later use.  
            
            today = datestr(date, 'mmddyy');

            absConfigDir = fullfile(configRoot, jobName);
            absScriptDir = fullfile(scriptRoot, jobName);
            absLogDir = fullfile(logRoot, jobName);
            absJobDir = fullfile(jobRoot, sprintf('%s_%s', jobName, today));

            % Make sure this job hasn't already been configured

            if exist(fullfile(absConfigDir), 'dir')
                msg = 'A job by this name has already been configured. Would you like to configure a new job (C), or modify the existing configuration (M)?';
                exitLoop = false;

                while ~exitLoop
                    answer = input(msg);
                    waitfor(answer);

                    if strcmp(answer, 'C') || strcmp(answer, 'c')
                        msg = 'Enter a unique name for your new job: ';
                        jobName = input(msg);
                        waitfor(jobName);

                        while size(jobName) == 0
                            msg = 'No job name provided... Please choose a unique job name.';
                            jobName = input(msg);
                            waitfor(jobName);
                        end

                        jobName = jobName{1};
                        
                        absConfigDir = fullfile(configRoot, jobName);
                        absScriptDir = fullfile(scriptRoot, jobName);
                        absLogDir = fullfile(logRoot, jobName);
                        absJobDir = fullfile(jobRoot, sprintf('%s_%s', jobName, today));
                        
                        % Create the needed job directories
                        mkdir(absConfigDir);
                        mkdir(absScriptDir);
                        mkdir(absLogDir);
                        mkdir(absJobDir);
                        
                        exitLoop = true;

                    elseif strcmp(answer, 'M') || strcmp(answer, 'm')
                        if exist(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)), 'file')
                            load(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)));
                            exitLoop = true;
                        else
                            msg = 'Oops, it looks like your previous configuration was corrupted.  Try cleaning up and then reconfiguring your job.';
                            disp(msg)
                            return;
                        end    
                    else
                        msg = 'Are you sure you want to cancel?  (Y/N) Your configuration progress will be saved for later.';
                        answer = input(msg);

                        if strcmp(answer, 'Y') || strcmp(answer, 'y')
                            save(fullfile(configRoot, 'global_environment'), 'pctConfigRoot', 'jobRoot', 'scriptRoot', 'logRoot', 'configRoot', 'cpRoot', 'logoData', 'logoMap', 'defaultJobNum');
                            save(fullfile(absConfigDir, sprintf('%s_environment', jobName)), 'absConfigDir', 'absJobDir', 'absLogDir', 'absScriptDir');
                            exit_code = 0;
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

            if isempty(entryFunctionFilePath) || isempty(entryFunctionName) || ~strcmp(ext, '.m')
                isValid = false;
            end


            while ~isValid
                disp('You must select a valid entry function for your job')
                absPath = input('Enter the absolute path to your job''s entry function/script on your local host: ');
                [entryFunctionFilePath, entryFunctionName, ext] = fileparts(absPath);

                % Check to see if the user's input was valid

                isValid = true;

                if isempty(entryFunctionFilePath) || isempty(entryFunctionName) || ~strcmp(ext, '.m')
                    isValid = false;
                end
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
            end

            % Continue attaching job dependencies.  Job dependent files other than the
            % entry function will be copied to the job script directory.  

            answer = input('Would you like to add another dependency to your job? (Y/N)');

            array_index = 1;

            while strcmp(answer, 'Y') || strcmp(answer, 'y')
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

            if strcmp(launchOrSave,'Y') || strcmp(launchOrSave,'y')
               workers = input('Choose a number of MATLAB workers for your job (Max: 32)');
               launchJob(jobName, workers);
            end

            % Save environment for later use
            jobsToDate(length(jobsToDate) + 1) = cellstr(jobNameCopy);
            save(fullfile(configRoot, 'global_environment'), 'pctConfigRoot', 'archiveRoot', 'jobRoot', 'scriptRoot', 'logRoot', 'configRoot', 'cpRoot', 'clusterProfile', 'jobsToDate');
            save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)), 'absConfigDir', 'absJobDir', 'absLogDir', 'absScriptDir','entryFunctionName', 'entryFunctionFilePath', 'attachedFiles', 'localJobStoragePath', 'remoteJobStoragePath', 'isFunction');

            if isFunction
                save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)),'functionInputs', 'functionOutputs', '-append');
            end

            exit_code = 0;

        end
        
        
        function [ exit_code ] = configureDisplayOn()
            
            % GUI Version of configureJob

            exit_code = -1;

            % Set some global variables for the config tools if they haven't been
            % created yet

            configRoot = fullfile(pwd, 'config');

            if ~exist(fullfile(configRoot, 'global_environment.mat'), 'file')

                pctConfigRoot = pwd;
                archiveRoot = fullfile(pwd, 'archive');
                scriptRoot = fullfile(pwd, 'scripts');
                logRoot = fullfile(pwd, 'logs');
                jobRoot = fullfile(pwd, 'jobs');
                cpRoot = fullfile(pwd, 'clusterProfiles');
                logo = fullfile(configRoot, 'OSC_logo.png');
                jobsToDate = {};
                
                [logoData, logoMap] = imread(logo, 'png', 'BackgroundColor', [0.7 0.7 0.7]);
                defaultJobNum = 1;

            else
                % If a global environment file exists, we need check to make sure that absolute paths in the global
                % environment are correct before loading it, just in case the
                % config tools parent directory has been moved.

                tempVar = load(fullfile(configRoot, 'global_environment.mat'), 'configRoot');

                if ~strcmp(tempVar, configRoot)
                    % Reset the values in the global environment file to
                    % reflect where you actually are
                    load(fullfile(configRoot, 'global_environment.mat'));

                    pctConfigRoot = pwd;
                    archiveRoot = fullfile(pwd, 'archive');
                    scriptRoot = fullfile(pwd, 'scripts');
                    logRoot = fullfile(pwd, 'logs');
                    jobRoot = fullfile(pwd, 'jobs');
                    cpRoot = fullfile(pwd, 'clusterProfiles');
                    logo = fullfile(configRoot, 'OSC_logo.png');

                    [logoData, logoMap] = imread(logo, 'png', 'BackgroundColor', [0.7 0.7 0.7]);
                end

            end

            % Welcome message (First GUI Window)

            msg = sprintf('Welcome to the OSC MATLAB Parallel Computing Toolbox Configuration Tool!\n\nYou will now be guided through a set of questions in order to configure your job.');
            gui = msgbox(msg, 'OSC MATLAB PCT Configuration Tool', 'custom', logoData, logoMap);

            waitfor(gui);

            % Get the needed variables from the user

            title = 'Enter the following information for your job';
            msg = {sprintf('Enter a unique job name: \n(Hint: Try to use only numbers, characters, -, and _.)'), ...
                sprintf('Enter a walltime: \n(Format: "hh:mm:ss")') ...
                sprintf('Enter a PBS log option: \n(See "qsub" documentation ("-j" option) for all available options')...
                sprintf('(Optional) Enter an email address in order to receive notifications about your job: ') ...
                sprintf('(Optional): Enter a filespace allocation amount: ')}
            defAns = {sprintf('Job%d', defaultJobNum), '01:00:00', 'oe', '', ''};

            jobInfo = inputdlg(msg, title, 1, defAns);

            jobName = jobInfo{1};
            walltime = jobInfo{2};
            logs = jobInfo{3};
            mail = jobInfo{4};
            filespace = jobInfo{5};

            % Create variables for the absolute pathnames of job-specific
            % directories.  These will later be saved in a job-specific environment
            % file for later use.

            today = datestr(date, 'mmddyy');
            absConfigDir = fullfile(configRoot, jobName);
            absScriptDir = fullfile(scriptRoot, jobName);
            absLogDir = fullfile(logRoot, jobName);
            absJobDir = fullfile(jobRoot, sprintf('%s_%s', jobName, today));

            % Make sure this job hasn't already been configured.  If so, offer
            % the option to overwrite the previous configuration.

            if exist(fullfile(configRoot, jobName), 'dir')
                msg = 'A job by this name has already been configured. Would you like to configure a new job, or modify the existing configuration?';
                exitLoop = false;

                while ~exitLoop
                    button = questdlg(msg, '', 'Configure New Job', 'Modify Existing', 'Cancel', 'Configure New Job');
                    waitfor(button);

                    if strcmp(button, 'Configure New Job')
                        msg = 'Choose a unique name for your new job: ';
                        jobName = inputdlg(msg);

                        while size(jobName) == 0
                            msg = msgbox('No job name provided... Please choose a unique job name.');
                            jobName = inputdlg(msg);
                            waitfor(jobName);
                        end

                        jobName = jobName{1};

                        % Reset the path values of subdirectories, with the new
                        % jobname

                        absConfigDir = fullfile(configRoot, jobName);
                        absScriptDir = fullfile(scriptRoot, jobName);
                        absLogDir = fullfile(logRoot, jobName);
                        absJobDir = fullfile(jobRoot, jobName);
                        
                        mkdir(absConfigDir);
                        mkdir(absScriptDir);
                        mkdir(absLogDir);
                        mkdir(absJobDir);

                        exitLoop = true;

                    elseif strcmp(button, 'Modify Existing')
                        if exist(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)), 'file')
                            load(fullfile(absConfigDir, sprintf('%s_environment.mat', jobName)));
                            exitLoop = true;
                        else
                            msg = 'Oops, it looks like your previous configuration was corrupted.  Try cleaning up and then reconfiguring your job.';
                            ok = errordlg(msg);
                            waitfor(ok);
                            return;
                        end    
                    else
                        msg = 'Are you sure you want to cancel?  Your configuration progress will be saved for later.';
                        button = questdlg(msg, '', 'Yes, Cancel', 'Nevermind', 'Nevermind');

                        if strcmp(button, 'Yes, Cancel')
                            save(fullfile(configRoot, 'global_environment'), 'pctConfigRoot', 'jobRoot', 'scriptRoot', 'logRoot', 'configRoot', 'cpRoot', 'logoData', 'logoMap', 'defaultJobNum');
                            save(fullfile(absConfigDir, sprintf('%s_environment', jobName)), 'absConfigDir', 'absJobDir', 'absLogDir', 'absScriptDir');
                            exit_code = 0;
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
                    msg = sprintf('Importing generic cluster profile for Oakley...');
                    message = msgbox(msg, '', 'warn');
                    waitfor(message);

                    clusterProfile = parallel.importProfile(fullfile(cpRoot, 'genericNonSharedOakleyIntel.settings'));
                else
                    clusterProfile = 'genericNonSharedOakleyIntel';
                end
            end

            % Here the user will import job dependencies into their scripts directory,
            % and a cell array of filenames of job dependencies will be created for saving in the job's
            % environment file.

            explanation = msgbox('You will now be asked to select job dependencies to attach to your job.  Press "OK" to continue');
            waitfor(explanation);

            attachedFiles = {};

            [entryFunctionName, entryFunctionFilePath, filterIndex] = uigetfile('*.m', 'Please select an entry function for your job:');

            while filterIndex == 0
                error = msgbox('You must select an entry function for your job', 'Error', 'error');
                waitfor(error);
                [entryFunctionName, entryFunctionFilePath, filterIndex] = uigetfile('*.m', 'Please select an entry function for your job:');
            end

            % Combine variables to get full absolute path to script, then copy it to
            % the script directory

            entryFunctionFilePath = fullfile(entryFunctionFilePath, entryFunctionName);
            copyfile(entryFunctionFilePath, absConfigDir);

            % Reset the location of the entry function to the new location in the
            % config directory.

            entryFunctionFilePath = fullfile(absConfigDir, entryFunctionName);

            % Remove the ".m" extension from the entryFunctionName

            entry = strsplit(entryFunctionName, '.');
            entryFunctionName = entry{1};

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
            end

            % Continue attaching job dependencies.  Job dependent files other than the
            % entry function will be copied to the job script directory.  

            button = questdlg('Would you like to add another dependency to your job?', '', 'Yes', 'No', 'Yes');
            waitfor(button);

            array_index = 1;

            while strcmp(button, 'Yes')
                [fileToAttach, filePath, ~] = uigetfile('All Files', 'Select a file to attach to your job:');

                % Combine variables to get full absolute path to script, then copy it to
                % the script directory
                filePath = fullfile(filePath, fileToAttach);
                copyfile(filePath, absScriptDir);

                % Add files located in the script directory to attachedFiles
                attachedFiles{array_index} = fullfile(absScriptDir, fileToAttach);
                array_index = array_index + 1;

                button = questdlg('Would you like to add another dependency to your job?', '', 'Yes', 'No', 'Yes');
                waitfor(button);
            end   

            % Get the local and remote job storage locations for this particular job's
            % output log files, which will be generated by MATLAB at execution time.  

            localJobStoragePath = uigetdir(pctConfigRoot, 'Select a local directory for job log output');
            waitfor(localJobStoragePath);

            msg1 = 'Your job also needs a remote storage location on the remote host (Oakley).  If you need to create a new directory for this purpose, please log on to OSC systems and create it before continuing.';
            warning = msgbox(msg1, '', 'warn');
            waitfor(warning);

            msg2 = 'Remote Job Storage Path: ';
            remoteJobStoragePath = inputdlg(msg2);
            waitfor(remoteJobStoragePath);

            % Extract remoteJobStoragePath from the cell array

            remoteJobStoragePath = remoteJobStoragePath{1};

            % Organize strings for inserting into configuration files

            jobNameCopy = jobName;

            nameArg = cellstr(sprintf('-N %s', jobName));
            walltime = cellstr(sprintf('-l walltime=%s', walltime));
            logArg = cellstr(sprintf('-j %s', logs));

            if ~strcmp(mail, '')
                mailArg = cellstr(sprintf('-M %s', mail));
            end

            if ~strcmp(filespace, '')
                filespaceArg = cellstr(sprintf('-l file=%s', filespace));
            end

            % Prepare to modify job-specific configuration files

            cd(absConfigDir);

            % Create a submit arguments string, and handle any additional submit
            % arguments that may have been specified

            C = cell(1, 3);
            C = [ nameArg, walltime, logArg ];
            submitArgs = strjoin(C);

            additionalArgs = '';

            if (exist('mailArg', 'var') == 1)
                additionalArgs = mailArg;
            end

            if (exist('filespaceArg', 'var') == 1)
                additionalArgs = cellstr(additionalArgs);
                C = cell(1, 2);
                C = [ additionalArgs, filespaceArg ];
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
            message = msgbox(msg);
            waitfor(message);

            msg = sprintf('Would you like to launch your job now, or save it for later?');
            message = questdlg(msg, 'Launch Job?', 'Launch now', 'Save for later', 'Save for later');
            waitfor(message);

            if strcmp(message,'Launch now')
               msg = sprintf('Choose a number of MATLAB workers for your job (Max: 32)');
               workers = inputdlg(msg);
               waitfor(workers);
               launchJob(jobName, workers);
            end

            % Save environment for later use
            
            % If the default job name was used, increment the default job number for
            % the next default job
            if strcmp(jobNameCopy, sprintf('Job%d', defaultJobNum))
                defaultJobNum = defaultJobNum + 1;
            end
            
            jobsToDate(length(jobsToDate) + 1) = cellstr(jobNameCopy);
            save(fullfile(configRoot, 'global_environment'), 'pctConfigRoot', 'archiveRoot', 'jobRoot', 'scriptRoot', 'logRoot', 'configRoot', 'cpRoot', 'clusterProfile', 'logoData', 'logoMap', 'defaultJobNum', 'jobsToDate');
            save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)), 'absConfigDir', 'absJobDir', 'absLogDir', 'absScriptDir','entryFunctionName', 'entryFunctionFilePath', 'attachedFiles', 'localJobStoragePath', 'remoteJobStoragePath', 'isFunction');

            if isFunction
                save(fullfile(absConfigDir, sprintf('%s_environment', jobNameCopy)),'functionInputs', 'functionOutputs', '-append');
            end

            exit_code = 0;

        end
        
        
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

                    batchCmd = sprintf('%s', 'batch(newCluster, entryFunctionName, functionOutputs, functionInputs, ''Matlabpool'', totalWorkers - 1, ''AdditionalPaths'', sprintf(''%s'', absScriptDir), ''AttachedFiles'', attachedFiles)');
                else
                    % However, if entryFunctionName refers to a script, we need to change
                    % the syntax of the batch command slightly

                    batchCmd = sprintf('%s', 'batch(newCluster, entryFunctionName, ''Matlabpool'', totalWorkers - 1, ''Workspace'', workspace, ''AdditionalPaths'', sprintf(''%s'', absScriptDir), ''AttachedFiles'', attachedFiles)');
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
        end
        
        
        function [ exit_code ] = cleanupJob( jobName )
            % GUI version
            
            exit_code = -1;

            % Load global_environment.mat

            if ~exist('pctConfigRoot', 'var')
                load (fullfile(pwd, 'config', 'global_environment.mat'));
            end
            
            % Load the job specific environment file, if deleting one
            % specific job
            
            if ~strcmp(jobName, 'all') && ~exist('absConfigDir', 'var')
                load(fullfile(configRoot, jobName, sprintf('%s_environment.mat', jobName)));
            end

            % Get confirmation from user that they want to permanently
            % delete the job(s)

            if strcmp(jobName, 'all')
                prompt = sprintf('Are you sure you want to delete all jobs?');
            else
                prompt = sprintf('Are you sure you want to delete job "%s"?', jobName);
            end
            
            button = questdlg(prompt, '', 'Yes', 'No', 'No');

            if strcmp(button, 'Yes')
                % First get rid of all configurations/logs/scripts
                % associated with the job(s) to delete
                
                if strcmp(jobName, 'all')
                    dirsToRemove = [strsplit(ls(configRoot)), strsplit(ls(logRoot)), strsplit(ls(scriptRoot))];
                    for count = 1:length(dirsToRemove)
                        rmdir(dirsToRemove(count), 's');
                    end
                else
                    rmdir(absConfigDir, 's');
                    rmdir(absLogDir, 's');
                    rmdir(absScriptDir, 's');
                end
                    
                
                % Then archive job results files
                
                pastJobs = strsplit(ls(jobRoot));
                
                if isempty(pastJobs)
                    disp('The "jobs" folder is empty... nothing to archive')
                    return;
                else
                    foundMatch = false;

                    for count = 1:length(pastJobs)
                        if strcmp(jobName, 'all')
                            % Archive the results files
                            files = sprintf('%s/*', pastJobs(count));
                            zipfile = sprintf('%s.zip', pastJobs(count));
                            disp(sprintf('Archiving job %s into %s...', pastJobs(count), archiveRoot));
                            zip(zipfile, files);
                            movefile(fullfile(jobRoot, pastJobs(count), zipfile), fullfile(archiveRoot));
                            
                            % Remove all associated job directories
                            rmdir(pastJobs(count), 's');
                        else
                            match = regexp(pastJobs(count), sprintf('%s*', jobName), 'match');
                            if ~isempty(match)
                                % Archive the results files
                                foundMatch = true;
                                files = sprintf('%s/*', pastJobs(count));
                                zipfile = sprintf('%s.zip', pastJobs(count))
                                disp(sprintf('Archiving job %s into %s...', pastJobs(count), archiveRoot));
                                zip(zipfile, files);
                                movefile(fullfile(jobRoot, pastJobs(count), zipfile), fullfile(archiveRoot));
                                
                                % Remove all associated job directories
                                rmdir(pastJobs(count), 's');
                            end
                        end
                    end
                    
                    if ~foundMatch && ~strcmp(jobName, 'all')
                        disp('No job by that name was found... nothing to archive')
                        return;
                    end
                end
            end
            
           exit_code = 0; 
        end
    end     
end

