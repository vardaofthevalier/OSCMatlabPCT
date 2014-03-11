Welcome to the OSC MATLAB PCT Job Configuration Tools!  Please read this file throroughly in order to familiarize yourself
with the functionality of this package.  

The OSC MATLAB PCT Job Configuration Tools package contains the following directories:
    - OSC_MATLAB_PCT: The top-level directory.  Contains the directories mentioned below, as well as the configuration, launch and cleanup scripts.  
    - clusterProfiles: contains the file "genericNonSharedOakleyIntel.settings".  This file should not be moved or edited manually in any way.
    - config: Contains necessary configuration files with default values. These files should not be moved or edited manually in any way.
        It will also contain individual configuration directories for each configured job.
    - jobs: Directory where job results will be stored.
    - logs: Directory where MATLAB log information will be stored. 
    - scripts: Directory where you will make copies of the scripts needed for your batch jobs.  If your scripts contain any references to other files, be sure to modify the file paths 
        to reflect their new locations in the scripts directory.  

In order to create a batch job using these configuration tools, there are three main steps:  configuring (configureJob.m), launching (launchJob.m), and cleaning up (cleanupJob.m).  
The configuration tool only needs to be run once per job.  The launch tool can be run as many times as necessary on an already configured job.  
The cleanup tool will delete all files and folders associated with the job you wish to delete.  Using the cleanup tool is an optional step.
  

To configure a job:

   Run the configureJob script.  
   Syntax: configureJob(jobName, walltime, logs, mail, filespace)

   configureJob takes the following string arguments:
    - jobName (required): a unique and descriptive name for your job
      Example: 'myJob'

    - walltime (optional): your walltime in the format hh:mm:ss.  The default walltime is "01:00:00".  
      Example: '01:30:00'

    - logs (optional): PBS logfile creation options.  Please refer to the OSC Batch Job Scripts documentation at 
      www.osc.edu/supercomputing/batch-processing-at-osc/batch-related-command-summary for a complete list of options.  The default is "oe".
      Example: 'oe' (This example will cause your PBS standard output and standard error files to be condensed into one file)

    - mail (optional): an email address for receiving information from the PBS batch system.  There is no default email argument.
      Example: 'my_email@emailservice.org'
 
    - filespace (optional): for specifying a filespace allocation.  There is no default filespace argument.  
     Example: '24gb'

   Examples: configureJob('jobName')
   	     configureJob('jobName', '02:00:00')
	     configureJob('jobName', '03:30:00', 'oe', 'my_email@emailservice.org', '24gb')

   configureJob will give you the option of running your job immediately at the end of the script.
   configureJob returns an exit code to the MATLAB workspace, indicating success (0) or failure (-1) of the configuration.

To launch a job:

   Run the launchJob script. This script uses the job configuration from the previous step to submit your batch job to the Oakley queue.  
   Syntax: launchJob(jobName, totalWorkers)

   launchJob takes the following required arguments:
    - jobName: The same jobName specified during job configuration, above. 
      Example: "myJob"
    - totalWorkers: The total number of workers/processes you'd like to use (an integer value).  Must be less than or equal to 32.  
      Example: 12

   Example: launchJob('jobName', 12)  

   launchJob returns an exit code to the MATLAB workspace, indicating success (0) or failure (-1) of the launch. 
   launchJob will also offload the results of your calculation from the remote host and store them in a .mat file in "jobs/[jobName]".

To cleanup a job:

   Run the cleanupJob script.  
   Syntax: cleanupJob(jobName)

   jobName, in this case, refers to a job that has already been created using the configureJob script and/or run using the launchJob script.

   Example:  cleanupJob('jobName')

   cleanupJob returns an exit code to the MATLAB workspace, indicating success (0) or failure (-1) of the cleanup.  


For additional information about the OSC MATLAB PCT Configuration Tools package, please contact OSC Help (oschelp@osc.edu) for assistance.   

 