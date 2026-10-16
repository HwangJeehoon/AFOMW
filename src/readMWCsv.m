function mw = readMWCsv(csvPath)
% READMWCSV  MW CSV를 읽는다. SAH01/03 파일 끝의 빈 행(Excel 저장 잔재)은 버리고,
% p_trainingSaveTime은 mm:ss.s 문자열 그대로 둔다.
opts = detectImportOptions(csvPath, 'Encoding', 'UTF-8');
opts = setvartype(opts, 'p_trainingSaveTime', 'char');
mw = readtable(csvPath, opts);
mw = mw(~isnan(mw.p_rowid), :);
end
