function step02_process_afo_merge()
% STEP02_PROCESS_AFO_MERGE  raw/afo와 processed/emg_steps를 결합해
% processed/emg_afo_steps를 만든다. 반드시 01_process_emg 이후 실행한다.

clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(scriptDir, 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);

for i = 1:numel(targets)
    target = targets(i);
    processSubjectDateAFO(target.subject, target.dateStr, target.gaitPct, cfg.rootDir, cfg.trials);
end

fprintf('\n=== AFO merge processing complete ===\n');
end
