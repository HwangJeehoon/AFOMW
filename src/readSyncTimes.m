function syncMap = readSyncTimes(csvPath)
% READSYNCTIMES  syncEMG_Subject_날짜.csv를 읽어 trial -> trigger epoch time(s) 맵을 만든다.
%   키는 소문자로 정규화된다 (예: 'bare', 'p1', 'p2', 'p3').

T = readtable(csvPath, 'TextType', 'string');
keysList = cellstr(lower(strtrim(T.Trial)));
syncMap = containers.Map(keysList, num2cell(T.Time));
end
