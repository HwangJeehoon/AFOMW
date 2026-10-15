function processSubjectDateMW(subject, dateStr, pct, affectedSide, rootDir, trials)
% PROCESSSUBJECTDATEMW  한 subject/날짜의 bare/P1/P2/P3 MW 데이터를 gait cycle tick으로
% AFO 시계에 맞춘 뒤(syncMWToGaitCycle), 이미 만들어져 있는
% processed/emg_afo_steps/{bare,p1,p2,p3}/step{N}.csv 각 행의 AFOTime에 MW 값을 붙여
% processed/emg_afo_mw_steps/{bare,p1,p2,p3}/step{N}.csv에 저장한다.
% 반드시 processSubjectDateAFO 이후 실행한다.
%   기존 컬럼 GaitCycle은 GaitCycle_afo로 이름만 바꾸고, 다음 컬럼을 추가한다.
%     MWTime            : 가장 가까운 MW 샘플의 p_trainingSaveTime (mm:ss.s 그대로)
%     GaitCycle_MW_R/L  : 가장 가까운 MW 샘플의 p_right/leftCurrentGaitCycleRate 그대로
%                         (GaitCycle_afo와 비교하는 디버깅용)
%     L_GRF, R_GRF      : p_left/rightCurrentGRF (선형보간)
%     L_CoP, R_CoP      : 로드셀 앞쪽 비율 1D CoP, 0 = 뒤 ~ 1 = 앞 (선형보간)
%     BWS               : p_bwsCurrentSupport (선형보간)
%   MW 기록 범위 밖의 행은 MW 컬럼이 비어 있다.
%   trial별 싱크 진단값은 processed/emg_afo_mw_steps/MW_sync.csv에 저장한다.
%   pct          : [start mid end] gait cycle % 경계 (subject별로 다름)
%   affectedSide : 'L' 또는 'R' (gait cycle tick을 만든 환측)

if nargin < 5
    rootDir = pwd;
end

paths = getSubjectDatePaths(rootDir, subject, dateStr);
syncPath = fullfile(paths.syncDir, ...
    sprintf('syncEMG_%s_%s.csv', subject, dateStr));
syncTable = readtable(syncPath, 'TextType', 'string');
syncMap = containers.Map(cellstr(lower(strtrim(syncTable.Trial))), num2cell(syncTable.Time));

outDir = paths.emgAfoMwStepsDir;
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

mwNames = {'L_GRF', 'L_CoP', 'R_GRF', 'R_CoP', 'BWS'};
syncRows = struct('Trial', {}, 'MWFile', {}, 'TrainTicks', {}, 'MWEvents', {}, 'Matched', {}, ...
    'ShiftCycles', {}, 'EndGap_s', {}, 'ClockLag_s', {}, 'ResidualSD_s', {}, ...
    'Steps', {}, 'StepsMissingMW', {}, 'GaitCycleDiff_pct', {});

for i = 1:numel(trials)
    tr = trials(i);
    fprintf('  [%s/%s] merging MW for trial %s ...\n', subject, dateStr, tr.label);
    mw = readMWCsv(fullfile(paths.mwRawDir, tr.mwFile));
    gaitPath = fullfile(paths.syncDir, sprintf('gaitCycle_%s_%s_%s.csv', subject, dateStr, tr.gaitSuffix));
    [mwAFOTime, info] = syncMWToGaitCycle(mw, gaitPath, pct, affectedSide, syncMap(tr.key));

    % ----- 로드셀 1D CoP (1,2번이 왼쪽 앞, 5,6번이 오른쪽 앞; 0 = 뒤, 1 = 앞) -----
    epsv = 1;
    Lsum = mw.p_leftCell1 + mw.p_leftCell2 + mw.p_leftCell3 + mw.p_leftCell4;
    Rsum = mw.p_rightCell5 + mw.p_rightCell6 + mw.p_rightCell7 + mw.p_rightCell8;
    LCoP = min(max((mw.p_leftCell1 + mw.p_leftCell2) ./ max(Lsum, epsv), 0), 1);
    RCoP = min(max((mw.p_rightCell5 + mw.p_rightCell6) ./ max(Rsum, epsv), 0), 1);
    mwVals = [mw.p_leftCurrentGRF, LCoP, mw.p_rightCurrentGRF, RCoP, mw.p_bwsCurrentSupport];

    if strcmp(affectedSide, 'L')
        affectedRate = mw.p_leftCurrentGaitCycleRate;
    else
        affectedRate = mw.p_rightCurrentGaitCycleRate;
    end

    trialDir = fullfile(outDir, tr.key);
    if ~exist(trialDir, 'dir')
        mkdir(trialDir);
    end
    inDir = fullfile(paths.emgAfoStepsDir, tr.key);
    nSteps = numel(dir(fullfile(inDir, 'step*.csv')));
    stepOpts = detectImportOptions(fullfile(inDir, 'step1.csv'));
    nMissing = 0;
    stepDiff = nan(nSteps, 1);
    for c = 1:nSteps
        T = readtable(fullfile(inDir, sprintf('step%d.csv', c)), stepOpts);
        nearIdx = interp1(mwAFOTime, (1:height(mw))', T.AFOTime, 'nearest');  % MW 범위 밖은 NaN
        has = ~isnan(nearIdx);
        nearIdx = nearIdx(has);

        mwTime = strings(height(T), 1);
        mwTime(has) = mw.p_trainingSaveTime(nearIdx);
        gcR = nan(height(T), 1);
        gcR(has) = mw.p_rightCurrentGaitCycleRate(nearIdx);
        gcL = nan(height(T), 1);
        gcL(has) = mw.p_leftCurrentGaitCycleRate(nearIdx);

        T = renamevars(T, 'GaitCycle', 'GaitCycle_afo');
        T = addvars(T, mwTime, 'After', 'AFOTime', 'NewVariableNames', 'MWTime');
        T = addvars(T, gcR, gcL, 'After', 'GaitCycle_afo', ...
            'NewVariableNames', {'GaitCycle_MW_R', 'GaitCycle_MW_L'});
        T = [T, array2table(interp1(mwAFOTime, mwVals, T.AFOTime, 'linear'), ...
            'VariableNames', mwNames)];
        writetable(T, fullfile(trialDir, sprintf('step%d.csv', c)));

        nMissing = nMissing + any(~has);
        d = mod(affectedRate(nearIdx) - T.GaitCycle_afo(has) + 50, 100) - 50;  % 순환 차이
        stepDiff(c) = median(abs(d));
    end

    syncRows(end + 1) = struct( ...
        'Trial', tr.label, 'MWFile', tr.mwFile, 'TrainTicks', info.TrainTicks, ...
        'MWEvents', info.MWEvents, 'Matched', info.Matched, 'ShiftCycles', info.ShiftCycles, ...
        'EndGap_s', info.EndGap, 'ClockLag_s', info.ClockLag, 'ResidualSD_s', info.ResidualSD, ...
        'Steps', nSteps, 'StepsMissingMW', nMissing, ...
        'GaitCycleDiff_pct', median(stepDiff, 'omitnan')); %#ok<AGROW>
    fprintf(['    -> shift %d cycle, endGap %+.2f s, clockLag %+.2f s, matched %d/%d ticks, ' ...
        '%d/%d steps missing MW, |GaitCycle_MW - GaitCycle_afo| median %.2f%%\n'], ...
        info.ShiftCycles, info.EndGap, info.ClockLag, info.Matched, info.TrainTicks, ...
        nMissing, nSteps, syncRows(end).GaitCycleDiff_pct);
end

S = struct2table(syncRows);
writetable(S, fullfile(outDir, 'MW_sync.csv'));

% 같은 날 두 PC의 시계 차이는 천천히만 변하므로, 한 trial만 크게 벗어나면 cycle 짝짓기를 의심한다.
lagOff = abs(S.ClockLag_s - median(S.ClockLag_s)) > 1.5;
if any(lagOff) || any(abs(S.EndGap_s) > 1.5)
    warning('processSubjectDateMW:suspectSync', ...
        '[%s/%s] check MW_sync.csv: clockLag outlier in %s, |endGap| > 1.5 s in %s', ...
        subject, dateStr, strjoin(S.Trial(lagOff), ','), strjoin(S.Trial(abs(S.EndGap_s) > 1.5), ','));
end

fprintf('  [%s/%s] MW merge done.\n', subject, dateStr);
end

function mw = readMWCsv(csvPath)
% MW CSV를 읽는다. SAH01/03 파일 끝의 빈 행(Excel 저장 잔재)은 버리고,
% p_trainingSaveTime은 mm:ss.s 문자열 그대로 둔다.
opts = detectImportOptions(csvPath, 'Encoding', 'UTF-8');
opts = setvartype(opts, 'p_trainingSaveTime', 'char');
mw = readtable(csvPath, opts);
mw = mw(~isnan(mw.p_rowid), :);
end
