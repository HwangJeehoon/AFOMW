function [sensorNames, muscleNames] = muscleSensorMap()
% MUSCLESENSORMAP  센서 슬롯 이름과 근육 이름의 고정 대응 관계.
%   sensorNames{i}와 muscleNames{i}가 서로 짝을 이루며,
%   muscleNames 순서가 곧 출력 csv의 컬럼 순서가 된다.

sensorNames = {'Avanti Sensor 1', 'Avanti Sensor 2', 'Mini Sensor 5', 'Mini Sensor 6', ...
               'Avanti Sensor 3', 'Avanti Sensor 4', 'Mini Sensor 7', 'Mini Sensor 8'};
muscleNames = {'L_TA', 'L_GM', 'L_RF', 'L_VL', 'R_TA', 'R_GM', 'R_RF', 'R_VL'};
end
