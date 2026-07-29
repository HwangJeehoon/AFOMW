function plotValidPeakTable(subject, dateStr, validCounts, totalSteps, trialNames, muscleNames, sideNames, muscleFullNames, outDir, affectedSide)
% PLOTVALIDPEAKTABLE  plotRawEMGAll이 근육x trial마다 계산해 둔 '유효 봉우리'
%   step 수(validCounts)/전체 step 수(totalSteps)를, 환측(affectedSide) 근육만
%   골라 x축=trial(bare/P1/P2/P3), y축=근육인 표(heatmap)로 그린다.
%   validCounts(m,t)/totalSteps(t) : muscleNames{m}, trialNames{t}의 유효 봉우리
%   step 수 / 전체 step 수 (plotRawEMGAll.m 출력)
%   affectedSide : 'L' 또는 'R' — 이 side의 근육 행만 표에 남긴다
%
%   날짜(subject/dateStr)당 png 1장 -> outDir/ValidPeakTable.png

isAffected = strncmp(muscleNames, affectedSide, 1);
affectedNames = muscleNames(isAffected);

rowLabels = cell(1, numel(affectedNames));
for i = 1:numel(affectedNames)
    parts = strsplit(affectedNames{i}, '_');
    rowLabels{i} = muscleFullNames.(parts{2});
end

pct = validCounts(isAffected, :) ./ totalSteps * 100;

f = figure('Color', 'w', 'Position', [0 0 900 700]);
h = heatmap(trialNames, rowLabels, pct);
h.Title = sprintf('%s(%s) - Valid Peak %% by Muscle x Trial', subject, dateStr);
h.XLabel = 'Trial';
h.YLabel = sprintf('Affected Side (%s) Muscle', sideNames.(affectedSide));
h.CellLabelFormat = '%.0f%%';
h.ColorLimits = [0 100];
h.FontSize = 16;

saveas(f, fullfile(outDir, 'ValidPeakTable.png'));
end
