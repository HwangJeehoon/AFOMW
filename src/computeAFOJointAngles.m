function angleTable = computeAFOJointAngles(bagPath)
% COMPUTEAFOJOINTANGLES  AFO .bag 하나에서 좌우 무릎/발목 상대각(트라이얼 전체,
% IMU 원 샘플레이트)을 계산한다.
%   /afo_sensor/imu 데이터는 [내부 카운터, IMU_0..IMU_6 각 9개(roll,pitch,yaw,
%   gx,gy,gz,ax,ay,az)] 순서로 들어오므로 1번째 열(카운터)을 떼고 get_IMU_fromBag에
%   넘긴다. IMU_1=왼허벅지, IMU_2=왼정강이, IMU_3=왼발, IMU_4=오른허벅지,
%   IMU_5=오른정강이, IMU_6=오른발 (IMU_0는 미사용).
%   상대각은 pairs=[1 2;2 3;4 5;5 6](왼무릎,왼발목,오른무릎,오른발목)로 계산한다.
%   /afo_gui/kinematics_zero 메시지는 두 개가 오는데, 첫 번째가 global(센서 자체)
%   zeroing 시각, 마지막이 직립 자세(정지 자세) zeroing 시각이다. 센서 프레임
%   정렬(cal_Angle_IMU의 IMU별 쿼터니언 영점)은 첫 번째 시각을, 관절각 자체의
%   영점(직립 자세 기준)은 마지막 시각을 기준으로 맞춘다. [roll,pitch,yaw] 중
%   roll(1번째 컬럼)만 관절각으로 쓴다(ref/AFO_MW_param_sweep.m의
%   Knee_L/Ankle_L/Knee_R/Ankle_R 관례와 동일).
%   반환 테이블 컬럼: AFOTime(절대 epoch초), left_knee_angle, left_ankle_angle,
%   right_knee_angle, right_ankle_angle (모두 deg)

pairs = [1 2; 2 3; 4 5; 5 6];
jointNames = {'left_knee_angle', 'left_ankle_angle', 'right_knee_angle', 'right_ankle_angle'};

imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
imuData.Time = imuRaw.Time;
imuData.Data = imuRaw.Data(:, 2:end);  % 1번째 열은 IMU 보드 내부 카운터라 제외
imuStruct = get_IMU_fromBag(imuData);

zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
zeroingTimeGlobal = zeroRaw.Time(1);   % 첫번째: global(센서 자체) zeroing -> 센서 프레임 정렬 기준
zeroingTimeStand = zeroRaw.Time(end); % 마지막: 직립 상태 zeroing -> 관절각 영점 기준

angles_rad = cal_Angle_IMU(imuStruct, zeroingTimeGlobal, pairs);

afoTime = imuRaw.Time;  % 모든 IMU가 같은 /afo_sensor/imu 메시지에서 나오므로 시간축 공유
[~, idxZero] = min(abs(afoTime - zeroingTimeStand));

angleCols = zeros(numel(afoTime), numel(jointNames));
for k = 1:size(pairs, 1)
    key = sprintf('IMU_%d_%d', pairs(k, 1), pairs(k, 2));
    deg = rad2deg(angles_rad.(key));   % [N x 3] roll pitch yaw
    deg = deg - deg(idxZero, :);        % groundTimeStand(직립 자세) 기준 영점
    angleCols(:, k) = deg(:, 1);        % roll만 사용
end

angleTable = array2table([afoTime, angleCols], 'VariableNames', [{'AFOTime'}, jointNames]);
end
