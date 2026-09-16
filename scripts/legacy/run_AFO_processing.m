% run_AFO_processing.m
% AFO/*.bag(rosbag)에서 좌우 무릎/발목 IMU 상대각을 계산해 EMG와 같은 gait cycle
% 경계로 자른 뒤, Subject/날짜/EMG_processed/{bare,p1,p2,p3}/의 step csv에 AFOTime
% 기준으로 관절각 컬럼을 이어붙여 Subject/날짜/EMG_AFO_merged/{bare,p1,p2,p3}/에
% 저장한다. (대응하는 EMG_processed 결과가 이미 있는 subject/날짜 조합만 처리)

clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

%% ── 설정 ──────────────────────────────────────────────────────────
% subject별 gait cycle % 경계 [start mid end] (run_EMG_processing.m과 동일해야 함)
gaitPct.SAH01 = [0, 70, 100];
gaitPct.SAH03 = [-10, 60, 90];
gaitPct.SAH04 = [-10, 60, 90];

% 처리할 subject/날짜 조합 (대응하는 AFO/*.bag, EMG_processed 결과가 있는 것만)
% targets = struct( ...
%     'subject', {'SAH01', 'SAH01', 'SAH03', 'SAH03'}, ...
%     'dateStr', {'260706', '260713', '260623', '260630'});

targets = struct( ...
    'subject', {'SAH01', 'SAH01', 'SAH03'}, ...
    'dateStr', {'260706', '260713', '260623'});

% targets = struct( ...
%     'subject', {'SAH03'}, ...
%     'dateStr', {'260630'});

%% ── 실행 ──────────────────────────────────────────────────────────
for i = 1:numel(targets)
    pct = gaitPct.(targets(i).subject);
    processSubjectDateAFO(targets(i).subject, targets(i).dateStr, pct, rootDir);
end

fprintf('\n=== All subject/date AFO processing complete ===\n');
