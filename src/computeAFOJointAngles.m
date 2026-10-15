function [angleTable, calibration] = computeAFOJointAngles(bagPath, functionalTimeRange)
% COMPUTEAFOJOINTANGLES  AFO .bag 하나에서 좌우 고관절/무릎/발목 sagittal 각도(트라이얼
% 전체, IMU 원 샘플레이트)를 계산한다.
%
%   센서별로 global zero(holder) 대비 회전을 구하고, 그 회전을 holder의 x축(내외측
%   방향, sagittal 평면의 법선) 둘레 회전각으로 환산한 뒤, 인접한 두 센서의 각도를
%   뺀다. 두 센서의 상대 quaternion은 쓰지 않는다.
%
%   센서 배치: IMU_0=골반/몸통, IMU_1=왼허벅지, IMU_2=왼정강이, IMU_3=왼발,
%   IMU_4=오른허벅지, IMU_5=오른정강이, IMU_6=오른발.
%   /afo_sensor/imu 데이터는 [내부 카운터, IMU_0..IMU_6 각 9개(roll,pitch,yaw,
%   gx,gy,gz,ax,ay,az)] 순서로 들어오므로 1번째 열(카운터)을 떼고 get_IMU_fromBag에
%   넘긴다.
%
%   계산 순서:
%     1) /afo_gui/kinematics_zero 메시지 두 개 중 첫 번째가 global zeroing(센서를
%        holder에 고정한 상태), 마지막이 stand zeroing(직립 상태)이다.
%        cal_Angle_IMU로 각 IMU의 global zero 대비 회전 D_i(t) = inv(Q_i0)*Q_i(t)를
%        구한다(qRelative).
%     2) D_i(t) = [w x y z]의 holder x축 둘레 회전각:
%            theta_i(t) = 2*atan2(x, w)  (w>=0로 정규화, unwrap)
%        로봇이 holder에서 정한 yz 평면 안에서만 움직인다는 전제에서, 이 값이 그
%        센서가 평면 안에서 회전한 각도이다. 평면 밖 성분(y,z)은 버린다.
%     3) 관절각 = signMultiplier * (theta_distal - theta_proximal), 그리고 stand zeroing
%        시점의 값을 빼서 직립 자세 기준 변화량으로 만든다.
%          hip  = IMU_0(골반) -> IMU_1/IMU_4(허벅지),  flexion이 양수 (-1)
%          knee = IMU_1/4(허벅지) -> IMU_2/5(정강이),  flexion이 양수 (+1)
%          ankle= IMU_2/5(정강이) -> IMU_3/6(발),      plantarflexion이 양수 (+1)
%        부호는 중력 기반 독립 추정과 28개 trial에서 비교해 검증했고, 모든 trial에서
%        같은 부호가 나왔다.
%
%   센서 간 정렬(holder에서의 상대 자세)을 쓰지 않으므로, 센서 사이에 heading/twist
%   오차가 있어도 영향이 없다. 이전 방식(센서 pair의 상대 quaternion을 투영, src/legacy/
%   computeAFOJointAnglesPairSagittal.m)은 trial에 따라 20~65도의 센서 간 정렬 오차로
%   파형이 최대 10~19도 어긋났다.
%
%   functionalTimeRange는 이전 방식과 같은 인터페이스를 유지하기 위해 받아서
%   calibration에 기록만 한다(이 방식은 축을 데이터로 추정하지 않는다).
%   반환 테이블 컬럼: AFOTime(절대 epoch초), left_hip_angle, left_knee_angle,
%   left_ankle_angle, right_hip_angle, right_knee_angle, right_ankle_angle (모두 deg)

if nargin < 2
    functionalTimeRange = [];
end

pairs = [0 1; 1 2; 2 3; 0 4; 4 5; 5 6];  % [근위 원위]
jointNames = {'left_hip_angle', 'left_knee_angle', 'left_ankle_angle', ...
    'right_hip_angle', 'right_knee_angle', 'right_ankle_angle'};
% flexion(hip/knee)·plantarflexion(ankle)이 양수가 되도록 한 부호
signMultiplier = [-1, 1, 1, -1, 1, 1];

imuRaw = readAFOBagTopic(bagPath, '/afo_sensor/imu');
imuData.Time = imuRaw.Time;
imuData.Data = imuRaw.Data(:, 2:end);  % 1번째 열은 IMU 보드 내부 카운터라 제외
imuStruct = get_IMU_fromBag(imuData);

zeroRaw = readAFOBagTopic(bagPath, '/afo_gui/kinematics_zero');
if numel(zeroRaw.Time) < 2
    error('computeAFOJointAngles:missingZeroing', ...
        'Global and stand zeroing messages are both required: %s', bagPath);
end
zeroingTimeGlobal = zeroRaw.Time(1);   % 첫번째: global zeroing(센서를 holder에 고정) -> 센서별 회전의 기준
zeroingTimeStand = zeroRaw.Time(end);  % 마지막: 직립 상태 zeroing -> 관절각 영점 기준

[~, ~, qRelative, timeStruct] = cal_Angle_IMU(imuStruct, zeroingTimeGlobal, pairs);

afoTime = imuRaw.Time;  % 모든 IMU가 같은 /afo_sensor/imu 메시지에서 나오므로 시간축 공유
[~, idxZero] = min(abs(afoTime - zeroingTimeStand));

if isempty(functionalTimeRange)
    functionalTimeRange = [zeroingTimeStand, afoTime(end)];
else
    if numel(functionalTimeRange) ~= 2 || functionalTimeRange(1) >= functionalTimeRange(2)
        error('computeAFOJointAngles:invalidFunctionalWindow', ...
            'functionalTimeRange must be [startTime endTime] with startTime < endTime.');
    end
    functionalTimeRange = reshape(functionalTimeRange, 1, 2);
end

% 센서별 holder x축 둘레 회전각 [deg]
sensorIds = unique(pairs(:))';
theta = struct();
for id = sensorIds
    name = sprintf('IMU_%d', id);
    if numel(timeStruct.(name)) ~= numel(afoTime)
        error('computeAFOJointAngles:timeMismatch', '%s의 샘플 수가 /afo_sensor/imu와 다릅니다.', name);
    end
    theta.(name) = holderXRotation(qRelative.(name));
end

angleCols = zeros(numel(afoTime), numel(jointNames));
calibration = struct();
calibration.method = 'per_sensor_holder_x_rotation';
calibration.groundTime = zeroingTimeGlobal;
calibration.standTime = zeroingTimeStand;
calibration.functionalStartTime = functionalTimeRange(1);
calibration.functionalEndTime = functionalTimeRange(2);
calibration.joints = struct('name', {});

for k = 1:size(pairs, 1)
    nameProximal = sprintf('IMU_%d', pairs(k, 1));
    nameDistal = sprintf('IMU_%d', pairs(k, 2));
    jointDeg = theta.(nameDistal) - theta.(nameProximal);
    angleCols(:, k) = signMultiplier(k) * (jointDeg - jointDeg(idxZero));  % stand 시점 값을 offset으로 보정

    calibration.joints(k) = struct('name', jointNames{k});
end

angleTable = array2table([afoTime, angleCols], 'VariableNames', [{'AFOTime'}, jointNames]);
angleTable.Properties.UserData = calibration;
end

function thetaDeg = holderXRotation(q)
% q: [N x 4] (w x y z), global zero 대비 회전. x축 둘레 회전각(deg)을 반환한다.
% w<0이면 -q로 바꿔 같은 회전의 다른 표현을 통일한 뒤 2*atan2(x, w)를 unwrap한다.
neg = q(:, 1) < 0;
q(neg, :) = -q(neg, :);
thetaDeg = rad2deg(unwrap(2 * atan2(q(:, 2), q(:, 1))));
end
