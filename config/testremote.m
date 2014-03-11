
intelCluster = parcluster('genericNonSharedOakleyIntel');

job_intel = batch(intelCluster, @colsum, 1, {}, 'CurrentFolder', '/nfs/14/samsi', ...
    'matlabpool', 11, 'CaptureDiary', true);

disp('job submitted');

wait(job_intel)
