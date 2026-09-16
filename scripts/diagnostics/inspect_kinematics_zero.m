function inspect_kinematics_zero()
% INSPECT_KINEMATICS_ZERO  모든 활성 target의 AFO bag에서
% /afo_gui/kinematics_zero 토픽 발생 횟수와 시점을 확인한다.

clc;
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(scriptDir));
addpath(fullfile(rootDir, 'src'));
addpath(fullfile(fileparts(scriptDir), 'config'));

cfg = pipeline_config();
targets = cfg.targets([cfg.targets.enabled]);

for i = 1:numel(targets)
    target = targets(i);
    paths = getSubjectDatePaths(cfg.rootDir, target.subject, target.dateStr);
    for j = 1:numel(cfg.trials)
        trial = cfg.trials(j);
        bagPath = fullfile(paths.afoRawDir, trial.bagFile);
        if ~isfile(bagPath)
            fprintf('%s/%s/%s: (bag 없음)\n', ...
                target.subject, target.dateStr, trial.label);
            continue
        end

        bag = rosbag(bagPath);
        selection = select(bag, 'Topic', '/afo_gui/kinematics_zero');
        timeFromStart = selection.MessageList.Time - bag.StartTime;
        fprintf('%s/%s/%s: kinematics_zero count=%d, t(+s)=%s\n', ...
            target.subject, target.dateStr, trial.label, selection.NumMessages, ...
            mat2str(timeFromStart', 4));
    end
end
end
