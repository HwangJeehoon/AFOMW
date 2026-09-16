function step01_process_emg()
% STEP01_PROCESS_EMG  raw/emg와 sync_data를 읽어 processed/emg_steps를 만든다.
% 실행 전 입력 파일이 모두 준비됐는지 확인한다.

clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(scriptDir, 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);

for i = 1:numel(targets)
    target = targets(i);
    processSubjectDate(target.subject, target.dateStr, target.gaitPct, ...
        cfg.sensorNames, cfg.muscleNames, cfg.rootDir, cfg.trials);
end

fprintf('\n=== EMG processing complete ===\n');
end
