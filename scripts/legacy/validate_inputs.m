% VALIDATE_INPUTS  새 표준 구조의 처리 입력 파일 존재 여부를 점검한다.
% 누락이 있으면 어떤 subject/date/trial 파일인지 보고하고 오류로 종료한다.

clear; clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(rootDir, 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);
missing = strings(0, 1);

for i = 1:numel(targets)
    target = targets(i);
    paths = getSubjectDatePaths(cfg.rootDir, target.subject, target.dateStr);
    prefix = sprintf('%s/%s', target.subject, target.dateStr);

    syncPath = fullfile(paths.syncDir, sprintf('syncEMG_%s_%s.csv', target.subject, target.dateStr));
    if ~isfile(syncPath)
        missing(end + 1, 1) = sprintf('%s: sync 파일 없음: %s', prefix, syncPath); %#ok<SAGROW>
    end

    for t = 1:numel(cfg.trials)
        trial = cfg.trials(t);
        required = { ...
            fullfile(paths.emgRawDir, trial.emgFile), ...
            fullfile(paths.afoRawDir, trial.bagFile), ...
            fullfile(paths.syncDir, sprintf('gaitCycle_%s_%s_%s.csv', ...
                target.subject, target.dateStr, trial.gaitSuffix))};
        labels = {'EMG', 'AFO bag', 'gait cycle'};
        for f = 1:numel(required)
            if ~isfile(required{f})
                missing(end + 1, 1) = sprintf('%s/%s: %s 파일 없음: %s', ...
                    prefix, trial.label, labels{f}, required{f}); %#ok<SAGROW>
            end
        end
    end

    fprintf('[checked] %s\n', prefix);
end

if isempty(missing)
    fprintf('\n=== 모든 처리 입력 파일이 준비되었습니다. ===\n');
else
    fprintf('\n=== 누락된 처리 입력 파일 ===\n');
    fprintf('%s\n', missing);
    error('validate_inputs:missingInputs', '%d개 입력 파일이 누락되었습니다.', numel(missing));
end
