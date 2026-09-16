function T = readProcessedEMGCsv(csvPath)
% READPROCESSEDEMGCSV  processSubjectDate가 저장한 processed/emg_steps csv를 읽는다.
%   파일 앞부분은 'endheader' 줄까지가 메타데이터(예: emg_lpf_hz = 8)이고, 그
%   다음 줄이 실제 컬럼 이름, 이후가 데이터다. 메타데이터 줄 수를 세어 그만큼
%   건너뛰고 readtable로 읽는다(메타데이터 줄이 늘어나도 그대로 동작).

fid = fopen(csvPath, 'r');
if fid == -1
    error('readProcessedEMGCsv:fileNotFound', 'Cannot open %s', csvPath);
end

nHeaderLines = 0;
while true
    line = fgetl(fid);
    if ~ischar(line)
        fclose(fid);
        error('readProcessedEMGCsv:noEndHeader', ...
            '"endheader" line not found in %s', csvPath);
    end
    nHeaderLines = nHeaderLines + 1;
    if strcmp(strtrim(line), 'endheader')
        break;
    end
end
fclose(fid);

T = readtable(csvPath, 'NumHeaderLines', nHeaderLines);
end
