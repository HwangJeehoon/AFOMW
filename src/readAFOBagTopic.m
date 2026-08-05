function dataStruct = readAFOBagTopic(bagPath, topicName)
% READAFOBAGTOPIC  AFO .bag(rosbag)에서 Float32MultiArray/Int16MultiArray 토픽
% 하나를 읽어 시간/데이터 행렬로 반환한다. ref/get_rosbag.m과 로직은 같지만,
% 시간을 t0(첫 /rosout 메시지) 기준 상대시간으로 바꾸지 않고 rosbag 절대
% epoch초 그대로 반환한다 (EMG_processed의 AFOTime과 같은 시계를 쓰기 위함).
%   dataStruct.Time : [N x 1] 절대 epoch 시각(초)
%   dataStruct.Data : [N x M] 각 메시지의 Data 필드를 행으로 쌓은 행렬

bag = rosbag(bagPath);
topicSel = select(bag, 'Topic', topicName);
if isempty(topicSel.MessageList)
    error('readAFOBagTopic:topicNotFound', '"%s"에 메시지가 없습니다: %s', topicName, bagPath);
end

rawMsgs = readMessages(topicSel, 'DataFormat', 'struct');

sample = rawMsgs{1}.Data;
dataMat = zeros(numel(rawMsgs), numel(sample));
for k = 1:numel(rawMsgs)
    dataMat(k, :) = rawMsgs{k}.Data;
end

dataStruct.Time = topicSel.MessageList.Time;
dataStruct.Data = dataMat;
end
