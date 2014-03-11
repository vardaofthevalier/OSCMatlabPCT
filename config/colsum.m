function total_sum = colsum

if labindex == 1
    % Send magic square to other workers
    A = labBroadcast(1,magic(numlabs)) ;
    disp('lab 1 broadcasting');
else
    % Receive broadcast on other workers
    disp(['receiving on lab ' num2str(labindex)]);
    A = labBroadcast(1) ;
end

% Calculate sum of column identified by labindex for this worker
column_sum = sum(A(:,labindex));

% Calculate total sum by combining column sum from all workers
total_sum = gplus(column_sum);

disp(['MDCE_JOB_LOCATION : ' getenv('MDCE_JOB_LOCATION')]);
disp(['MDCE_STORAGE_LOCATION : ' getenv('MDCE_STORAGE_LOCATION')]);

spmd
    [~, b] = system('uname -n');
    fprintf('Lab %d on %s\n', labindex, b);
end

