% run_EMG_processing.m
% EMG 데이터를 sync 정보로 0초를 맞추고, gait cycle 정보로 step 단위로 잘라
% rectify + 같은 날짜 RMS normalize를 적용해 Subject/날짜/EMG_processed/에 저장한다.
% (대응하는 sync/gaitCycle 파일이 있는 subject/날짜 조합만 처리)

clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

rootDir = fullfile(fileparts(mfilename('fullpath')), '..');

%% ── 설정 ──────────────────────────────────────────────────────────
% 센서 슬롯 <-> 근육 이름 (muscleNames{m}가 sensorNames{m}에 대응, 순서가 출력 csv 컬럼 순서)
sensorNames = {'Avanti Sensor 1', 'Avanti Sensor 2', 'Mini Sensor 5', 'Mini Sensor 6', ...
               'Avanti Sensor 3', 'Avanti Sensor 4', 'Mini Sensor 7', 'Mini Sensor 8'};
muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};

% subject별 gait cycle % 경계 [start mid end] (start=low 시작, mid=high 시작, end=다음 step 시작)
gaitPct.SAH01 = [0, 70, 100];
gaitPct.SAH03 = [-10, 60, 90];

% 처리할 subject/날짜 조합 (대응하는 sync/gaitCycle 파일이 있는 것만)
targets = struct( ...
    'subject', {'SAH01', 'SAH01', 'SAH03', 'SAH03'}, ...
    'dateStr', {'260706', '260713', '260623', '260630'});

targets = struct( ...
    'subject', {'SAH03'}, ...
    'dateStr', {'260630'});
%% ── 실행 ──────────────────────────────────────────────────────────
for i = 1:numel(targets)
    pct = gaitPct.(targets(i).subject);
    processSubjectDate(targets(i).subject, targets(i).dateStr, pct, sensorNames, muscleNames, rootDir);
end

fprintf('\n=== All subject/date processing complete ===\n');
