function imuStruct = get_IMU_fromBag(imuData)
% imuData : get_rosbag 함수의 반환값(imuData.Time, imuData.Data 포함)
% IMU 데이터는 각도 + 각속도 + 가속도, 총 9개 데이터가 이 순서대로 들어온다고 가정함
%
% 반환되는 imuStruct 형식
%   imuStruct.IMU_0.Time   : N×1 상대시간 벡터
%   imuStruct.IMU_0.Angle  : N×3 [roll pitch yaw]
%   imuStruct.IMU_0.Gyro   : N×3 [gx gy gz]
%   imuStruct.IMU_0.Accel  : N×3 [ax ay az]
%   …
%
% IMU_0, IMU_1, … 는 데이터 열 순서대로 붙음

    t = imuData.Time;
    D = imuData.Data;

    [N, nCols] = size(D);
    if mod(nCols, 9) ~= 0
        error("IMU 데이터 열 수가 9의 배수가 아닙니다.");
    end
    nIMU = nCols / 9;

    imuStruct = struct();      % 동적 필드 생성용 빈 구조체
    for k = 1:nIMU
        base = (k-1) * 9;
        idx  = base + (1:9);   % 현재 IMU에 해당하는 열 인덱스

        this.Angle = D(:, idx(1:3));   % roll pitch yaw
        this.Gyro  = D(:, idx(4:6));   % gx gy gz
        this.Accel = D(:, idx(7:9));   % ax ay az
        this.Time  = t;                % 동일 시간 벡터 공유

        fieldName = sprintf("IMU_%d", k-1);
        imuStruct.(fieldName) = this;
    end
end
