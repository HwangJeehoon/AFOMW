function step02b_process_mw_merge()
% STEP02B_PROCESS_MW_MERGE  raw/MW를 gait cycle tick으로 AFO 시계에 맞춰
% processed/emg_afo_steps에 MW 컬럼을 더한 processed/emg_afo_mw_steps를 만든다.
% 반드시 step02_process_afo_merge 이후 실행한다.

clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(scriptDir, 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);

for i = 1:numel(targets)
    target = targets(i);
    processSubjectDateMW(target.subject, target.dateStr, target.gaitPct, target.affectedSide, ...
        cfg.rootDir, cfg.trials);
end

fprintf('\n=== MW merge processing complete ===\n');
end
