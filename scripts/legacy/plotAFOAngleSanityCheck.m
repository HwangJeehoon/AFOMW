function plotAFOAngleSanityCheck(subject, dateStr, stepNum, rootDir)
% PLOTAFOANGLESANITYCHECK  bare/p1/p2/p3의 특정 걸음(step) hip/knee/ankle
% 관절각을 한 화면(2x3, L/R x hip/knee/ankle)에 겹쳐 그려서 IMU 각도 추정
% 알고리즘 결과를 빠르게 육안 확인하는 sanity check용 스크립트.
%   EMG_AFO_merged에 저장된 결과가 아니라, bag에서 매번 computeAFOJointAngles를
%   새로 돌려서 현재 src 코드의 최신 알고리즘 결과를 바로 보여준다.
%
%   사용 예:
%     plotAFOAngleSanityCheck('SAH01', '260706')       % step 10(기본값)
%     plotAFOAngleSanityCheck('SAH03', '260630', 5)    % step 5
%
%   subject : 'SAH01' | 'SAH03' 등 (gaitPct에 등록된 subject만 지원)
%   dateStr : 'YYMMDD' (예: '260630')
%   stepNum : 확인할 gait cycle(걸음) 번호, 기본값 10
%             (해당 트라이얼의 step 개수보다 크면 마지막 step으로 대체하고 경고)
%   rootDir : 데이터 루트, 기본값은 이 스크립트 기준 프로젝트 루트

if nargin < 3 || isempty(stepNum)
    stepNum = 10;
end
if nargin < 4 || isempty(rootDir)
    rootDir = fullfile(fileparts(mfilename('fullpath')), '..');
end
addpath(fullfile(rootDir, 'src'));

% subject별 gait cycle % 경계 [start mid end] (run_AFO_processing.m과 동일해야 함)
gaitPct.SAH01 = [0, 70, 100];
gaitPct.SAH03 = [-10, 60, 90];
if ~isfield(gaitPct, subject)
    error('plotAFOAngleSanityCheck:unknownSubject', ...
        '"%s"의 gait cycle %% 경계가 정의돼 있지 않습니다. 이 파일의 gaitPct에 추가하세요.', subject);
end
pct = gaitPct.(subject);

syncPath = fullfile(rootDir, subject, ['sync_' subject], ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

bagDir = fullfile(rootDir, subject, dateStr, 'AFO');
emgDir = fullfile(rootDir, subject, dateStr, 'EMG');
gaitDir = fullfile(rootDir, subject, ['sync_' subject]);

trials = struct( ...
    'key',        {'bare', 'p1', 'p2', 'p3'}, ...
    'bagFile',    {'bare.bag', 'p1.bag', 'p2.bag', 'p3.bag'}, ...
    'emgFile',    {'bare.csv', 'P1.csv', 'P2.csv', 'P3.csv'}, ...
    'gaitSuffix', {'BARE', 'p1', 'p2', 'p3'}, ...
    'label',      {'bare', 'P1', 'P2', 'P3'}, ...
    'color',      {[0.45 0.45 0.45], [0 0.45 0.74], [0.85 0.33 0.10], [0.47 0.67 0.19]});

jointNames  = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
jointTitles = {'Left Hip', 'Left Knee', 'Left Ankle', ...
    'Right Hip', 'Right Knee', 'Right Ankle'};

fig = figure('Name', sprintf('%s %s - step %d sanity check', subject, dateStr, stepNum), ...
    'Position', [100 100 1400 800]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax = gobjects(1, numel(jointNames));
for j = 1:numel(jointNames)
    ax(j) = nexttile(tl);
    hold(ax(j), 'on');
    grid(ax(j), 'on');
    title(ax(j), jointTitles{j}, 'Interpreter', 'none');
    xlabel(ax(j), 'Gait cycle (%)');
    ylabel(ax(j), 'Angle (deg)');
    yline(ax(j), 0, ':', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
end

legendHandle = gobjects(1, numel(trials));
legendOk = false(1, numel(trials));

for i = 1:numel(trials)
    tr = trials(i);
    try
        bagPath  = fullfile(bagDir, tr.bagFile);
        emgPath  = fullfile(emgDir, tr.emgFile);
        gaitPath = fullfile(gaitDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
        trigger  = syncMap(tr.key);

        hdr = parseEMGHeader(emgPath);
        windows = extractCycleWindows(gaitPath, trigger, pct, hdr.collectionLength);
        if isempty(windows)
            warning('plotAFOAngleSanityCheck:noWindow', '%s: 유효한 gait cycle이 없습니다. 건너뜀.', tr.key);
            continue
        end
        functionalTimeRange = [windows(1).startRel, windows(end).endRel] + trigger;

        angleTable = computeAFOJointAngles(bagPath, functionalTimeRange);
        cycleTables = cutAngleCycles(angleTable, gaitPath, trigger, pct, hdr.collectionLength);

        useStep = stepNum;
        if useStep > numel(cycleTables)
            warning('plotAFOAngleSanityCheck:stepOutOfRange', ...
                '%s: step %d 없음(총 %d step). step %d로 대체합니다.', ...
                tr.key, stepNum, numel(cycleTables), numel(cycleTables));
            useStep = numel(cycleTables);
        end
        stepTable = cycleTables{useStep};

        for j = 1:numel(jointNames)
            h = plot(ax(j), stepTable.GaitCycle, stepTable.(jointNames{j}), ...
                'Color', tr.color, 'LineWidth', 1.6, 'DisplayName', tr.label);
        end
        legendHandle(i) = h; %#ok<AGROW>  % 마지막 joint(=오른발목) 라인 핸들이면 충분(범례용)
        legendOk(i) = true;
    catch ME
        warning('plotAFOAngleSanityCheck:trialFailed', '%s 처리 중 오류: %s', tr.key, ME.message);
    end
end

if any(legendOk)
    legend(ax(1), legendHandle(legendOk), 'Location', 'best');
end
title(tl, sprintf('%s / %s - step %d (실제 계산 있는 마지막 step으로 자동 대체될 수 있음)', ...
    subject, dateStr, stepNum), 'Interpreter', 'none');

end
