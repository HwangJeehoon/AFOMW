function [angles, times, Q_rel, T] = cal_Angle_IMU(imuData_unpacked, ground_time, pairs, opts)
% imu_pairs_rpy
% - 각 IMU의 ground 대비 상대자세를 쿼터니안으로 계산
% - 지정한 IMU 쌍마다 상대자세를 구해 Euler RPY 각도로 반환

% 입력
%   imuData_unpacked : 구조체  예) imuData_unpacked.IMU_0.Angle [Nx3], .Time [Nx1]
%                      Angle는 [roll pitch yaw] in deg
%   ground_time      : 기준 시간 스칼라
%   IMU pairs        : Mx2 double  예) [1 2; 4 5]

% 출력
%   angles : 구조체  angles.IMU_1_2  [N x 3]  각 열은 [roll pitch yaw] in rad
%   times  : 구조체  times.IMU_1_2   [N x 1]  기준은 첫 번째 IMU의 시간축
%   Q_rel  : 각 IMU의 ground 대비 상대자세 쿼터니안 테이블  Q_rel.IMU_k [Nk x 4] (w x y z)
%   T      : 각 IMU의 시간 T.IMU_k [Nk x 1]

% 입력 각도 열 순서 옵션 지원  기본은 [roll pitch yaw]
% opts.angleOrder : 'rpy','ryp','pry','pyr','yrp','ypr' 중 하나 또는 [iR iP iY] 인덱스
%                   예) 'ypr' 이면 Angle(:,[yaw pitch roll]) 순서라는 뜻
%                   예) [3 2 1] 이면 Angle(:,1)=roll Angle(:,2)=pitch Angle(:,3)=yaw

    if nargin < 4 || isempty(opts); opts = struct(); end
    if ~isfield(opts,'angleOrder') || isempty(opts.angleOrder)
        angleOrder = 'rpy'; % 기본 입력은 [roll pitch yaw]
    else
        angleOrder = opts.angleOrder;
    end

    [idxR, idxP, idxY] = parse_angle_order(angleOrder);  % 입력 열에서 r p y의 위치
    seq = 'ZYX'; % 내부 회전 순서 고정

    % 필요한 IMU만 선계산
    needed = unique(pairs(:));
    needed_names = arrayfun(@(k) sprintf('IMU_%d', k), needed, 'UniformOutput', false);

    Q_rel = struct(); T = struct();
    for ii = 1:numel(needed_names)
        name = needed_names{ii};
        if ~isfield(imuData_unpacked, name)
            error('입력 구조체에 %s 가 없습니다.', name);
        end
        S = imuData_unpacked.(name);
        if ~isfield(S,'Angle') || ~isfield(S,'Time') || size(S.Angle,2) ~= 3
            error('%s.Angle [N x 3] 와 %s.Time [N x 1] 이 필요합니다.', name, name);
        end

        % ground 인덱스
        [~, idx0] = min(abs(S.Time - ground_time));

        % 입력 각도는 deg  열 순서는 옵션에 따라 r p y의 위치가 다름
        ang_in = deg2rad(S.Angle);         % [N x 3] in rad
        eul_rpy = ang_in(:, [idxR idxP idxY]);   % [r p y] 로 정렬
        eul_ypr = eul_rpy(:, [3 2 1]);           % [y p r] 로 변환

        % ground 쿼터니안
        q0 = eul2quat(eul_ypr(idx0,:), seq);     % [1 x 4] w x y z

        % 모든 시점 상대자세
        N = size(eul_ypr,1);
        q_rel_i = zeros(N,4);
        q0_inv = quatinv(q0);
        for j = 1:N
            qcur = eul2quat(eul_ypr(j,:), seq);
            q_rel_i(j,:) = quatmultiply(q0_inv, qcur);
        end
        q_rel_i = quatnormalize(q_rel_i);

        Q_rel.(name) = q_rel_i;
        T.(name)     = S.Time(:);
    end

    % 각 pair 처리
    angles = struct(); times = struct();
    for m = 1:size(pairs,1)
        a = pairs(m,1); b = pairs(m,2);
        nameA = sprintf('IMU_%d', a);
        nameB = sprintf('IMU_%d', b);

        qA = Q_rel.(nameA); tA = T.(nameA);
        qB = Q_rel.(nameB); tB = T.(nameB);

        % 시간 정렬  A 기준으로 B 매칭
        idxB = interp1(tB, 1:numel(tB), tA, 'nearest', 'extrap');

        % q_AB = inv(qA) * qB
        N = numel(tA);
        qAB = zeros(N,4);
        for k = 1:N
            qAB(k,:) = quatmultiply(quatinv(qA(k,:)), qB(idxB(k),:));
        end
        qAB = quatnormalize(qAB);

        % 마지막에 한 번만 Euler 변환  quat2eul ZYX -> [yaw pitch roll]
        eul_ypr = quat2eul(qAB, seq);
        eul_rpy = eul_ypr(:, [3 2 1]); % [roll pitch yaw] rad

        key = sprintf('IMU_%d_%d', a, b);
        angles.(key) = eul_rpy;
        times.(key)  = tA;
    end
end

% ----------------- 보조 함수 -----------------
function [iR, iP, iY] = parse_angle_order(orderSpec)
% orderSpec 이 문자열이면 각 열이 어떤 축인지 정의
% - 'rpy'  => Angle(:,1)=roll Angle(:,2)=pitch Angle(:,3)=yaw
% - 'ypr'  => Angle(:,1)=yaw  Angle(:,2)=pitch Angle(:,3)=roll
% orderSpec 이 [iR iP iY]이면 r p y가 각각 몇 번째 열인지 직접 지정
    if isnumeric(orderSpec)
        if numel(orderSpec) ~= 3
            error('angleOrder 인덱스는 [iR iP iY] 형식이어야 합니다.');
        end
        iR = orderSpec(1); iP = orderSpec(2); iY = orderSpec(3);
        validate_indices([iR iP iY]);
        return;
    end
    if ~ischar(orderSpec) && ~isstring(orderSpec)
        error('angleOrder 는 문자열 또는 [iR iP iY] 인덱스여야 합니다.');
    end
    s = lower(string(orderSpec));
    valid = ["rpy","ryp","pry","pyr","yrp","ypr"];
    if ~any(s == valid)
        error('angleOrder="%s" 는 지원되지 않습니다. 사용 가능: %s', s, strjoin(valid,", "));
    end
    % s에 따라 입력 열 1..3이 무엇인지 해석
    % 목표는 입력 행렬의 열에서 r p y의 위치 인덱스 iR iP iY 산출
    switch s
        case "rpy" % [roll pitch yaw]
            iR=1; iP=2; iY=3;
        case "ryp" % [roll yaw pitch]
            iR=1; iP=3; iY=2;
        case "pry" % [pitch roll yaw]
            iR=2; iP=1; iY=3;
        case "pyr" % [pitch yaw roll]
            iR=3; iP=1; iY=2;
        case "yrp" % [yaw roll pitch]
            iR=2; iP=3; iY=1;
        case "ypr" % [yaw pitch roll]
            iR=3; iP=2; iY=1;
    end
end

function validate_indices(v)
    mustBeInteger(v); mustBePositive(v);
    if numel(unique(v))~=3 || any(v<1) || any(v>3)
        error('angleOrder 인덱스는 1..3의 서로 다른 값이어야 합니다.');
    end
end
