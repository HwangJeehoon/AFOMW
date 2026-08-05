% inspect_kinematics_zero.m
% 모든 subject/날짜/trial의 AFO/*.bag에서 /afo_gui/kinematics_zero가 몇 번,
% 언제(트라이얼 시작 후 몇 초) 찍혔는지 확인한다.

clear; clc;

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

subjects = struct( ...
    'subject', {'SAH01', 'SAH01', 'SAH03', 'SAH03'}, ...
    'dateStr', {'260706', '260713', '260623', '260630'});
trials = {'bare', 'p1', 'p2', 'p3'};

for i = 1:numel(subjects)
    subject = subjects(i).subject;
    dateStr = subjects(i).dateStr;
    for j = 1:numel(trials)
        bagPath = fullfile(rootDir, subject, dateStr, 'AFO', [trials{j} '.bag']);
        if ~exist(bagPath, 'file')
            fprintf('%s/%s/%s: (bag 없음)\n', subject, dateStr, trials{j});
            continue
        end

        bag = rosbag(bagPath);
        sel = select(bag, 'Topic', '/afo_gui/kinematics_zero');
        n = sel.NumMessages;
        tRel = sel.MessageList.Time - bag.StartTime;

        fprintf('%s/%s/%s: kinematics_zero count=%d, t(+s)=%s\n', ...
            subject, dateStr, trials{j}, n, mat2str(tRel', 4));
    end
end
