clear all 
clc

% 定義電器數據
appliances = [
    struct('name', 'Laundry drier', 'start', 9, 'end', 12, 'duration', 2, 'power', 1.26, 'fixed', false);
    struct('name', 'Laundry drier', 'start', 18.5, 'end', 23, 'duration', 1.5, 'power', 1.26, 'fixed', false);
    struct('name', 'Electric kettle', 'start', 6, 'end', 8.5, 'duration', 0.5, 'power', 1.5, 'fixed', false);
    struct('name', 'Electric kettle', 'start', 18, 'end', 20, 'duration', 0.5, 'power', 1.5, 'fixed', false);
    struct('name', 'Electric kettle', 'start', 20, 'end', 23, 'duration', 0.5, 'power', 1.5, 'fixed', false);
    struct('name', 'Air conditioner', 'start', 0, 'end', 8, 'duration', 3, 'power', 1, 'fixed', false);
    struct('name', 'Air conditioner', 'start', 16, 'end', 24, 'duration', 4, 'power', 1.2, 'fixed', false);
    struct('name', 'Electric radiator', 'start', 12, 'end', 17, 'duration', 2.5, 'power', 2, 'fixed', false);
    struct('name', 'Water pump', 'start', 9, 'end', 22, 'duration', 4, 'power', 1.8, 'fixed', false);
    struct('name', 'Electric oven', 'start', 14, 'end', 20, 'duration', 2, 'power', 1.1, 'fixed', false);
    struct('name', 'PHEV', 'start', 0, 'end', 9, 'duration', 3.5, 'power', 1.8, 'fixed', false);
    struct('name', 'Dish washer', 'start', 9, 'end', 18, 'duration', 1.5, 'power', 0.73, 'fixed', false);
    struct('name', 'Dish washer', 'start', 20, 'end', 23, 'duration', 1.5, 'power', 0.73, 'fixed', false);
    struct('name', 'Rice cooker', 'start', 6, 'end', 8, 'duration', 1, 'power', 0.8, 'fixed', false);
    struct('name', 'Rice cooker', 'start', 18, 'end', 20, 'duration', 1, 'power', 0.8, 'fixed', false);
    struct('name', 'Washing machine', 'start', 8, 'end', 15, 'duration', 2, 'power', 0.38, 'fixed', false);
    struct('name', 'Washing machine', 'start', 18, 'end', 22, 'duration', 2, 'power', 0.38, 'fixed', false);
    struct('name', 'Microwave', 'start', 11, 'end', 14, 'duration', 1, 'power', 0.9, 'fixed', false);
    struct('name', 'Toaster', 'start', 6, 'end', 9, 'duration', 1, 'power', 0.8, 'fixed', false);
    struct('name', 'Light', 'start', 19, 'end', 24, 'duration', 5, 'power', 0.3, 'fixed', true);
    struct('name', 'Refrigerator', 'start', 0, 'end', 24, 'duration', 24, 'power', 0.03, 'fixed', true);
    struct('name', 'TV', 'start', 8, 'end', 24, 'duration', 16, 'power', 0.2, 'fixed', true);
    struct('name', 'Modem', 'start', 0, 'end', 24, 'duration', 24, 'power', 0.01, 'fixed', true);
];

% 電價信息（每半小時一個時段，共48時段）
TOU_prices = [1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 4.07, 4.07, 4.07, 4.07, 6.20, 6.20, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 4.07, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87, 1.87];

% 最高容許負載功率
max_power = 13.2; % kW

% FOX 演算法參數
num_solutions = 30; % 初始解的數量
max_iter = 200; % 最大迭代次數
a = 2; % 初始探索係數
c1 = 0.18; % 北東方向跳躍機率
c2 = 0.82; % 反北東方向跳躍機率
Sp_S = 343; % 聲速

% 初始化解的數量和結構
solutions = zeros(num_solutions, length(appliances), 48);
best_solution = [];
best_cost = Inf;

% 儲存每次迭代的最佳成本
cost_history = zeros(1, max_iter);

% 初始化隨機解
for i = 1:num_solutions
    for a = 1:length(appliances)
        if appliances(a).fixed
            start_idx = round(appliances(a).start * 2 + 1);
            end_idx = round(appliances(a).end * 2);
            solutions(i, a, start_idx:end_idx) = 1;
        else
            % 為每台電器隨機生成符合時間限制的開啟時段
            start_idx = round(appliances(a).start * 2 + 1);
            end_idx = round(appliances(a).end * 2);
            duration = round(appliances(a).duration * 2);
            if (end_idx - start_idx + 1 >= duration)
                start_time = randi([start_idx, end_idx - duration + 1]);
                solutions(i, a, start_time:(start_time + duration - 1)) = 1;
            end
        end
    end
end

% 計算每個解的總電費，作為評估解的依據
function cost = calculate_cost(appliances, schedule, prices)
    cost = 0;
    for t = 1:48
        P_t = sum(schedule(:, t) .* [appliances.power]');
        cost = cost + P_t * 0.5 * prices(t);  % 每半小時的成本
    end
end

% 檢查解是否滿足限制條件
function is_valid = check_constraints(schedule, appliances, max_power)
    is_valid = true;
    % 檢查每個時段的總功率是否超過最大允許功率
    for t = 1:48
        total_power = sum(schedule(:, t) .* [appliances.power]');
        if total_power > max_power
            is_valid = false;
            fprintf('超過最大功率限制的時段: %d\n', t);
            return;
        end
    end
    % 檢查每個電器的運行時間是否在其可用時段內
    for a = 1:length(appliances)
        if ~appliances(a).fixed
            start_idx = round(appliances(a).start * 2 + 1);
            end_idx = round(appliances(a).end * 2);
            duration = round(appliances(a).duration * 2);
            run_time = sum(schedule(a, start_idx:end_idx));
            if run_time ~= duration
                is_valid = false;
                fprintf('%s 的運行時間不在其可用時段內或運行時間不符合: %d\n', appliances(a).name, run_time);
                return;
            end
        end
    end
end

% FOX 演算法主程序
for iter = 1:max_iter
    for i = 1:num_solutions
        % 計算解的成本
        current_cost = calculate_cost(appliances, squeeze(solutions(i, :, :)), TOU_prices);
        
        % 更新最佳解
        if current_cost < best_cost
            best_cost = current_cost;
            best_solution = squeeze(solutions(i, :, :));
        end
        
        % 生成新的解
        new_solution = zeros(size(best_solution));
        if rand() < c1
            % 北東方向跳躍
            for a = 1:length(appliances)
                if appliances(a).fixed
                    start_idx = round(appliances(a).start * 2 + 1);
                    end_idx = round(appliances(a).end * 2);
                    new_solution(a, start_idx:end_idx) = 1;
                else
                    start_idx = round(appliances(a).start * 2 + 1);
                    end_idx = round(appliances(a).end * 2);
                    duration = round(appliances(a).duration * 2);
                    if (end_idx - start_idx + 1 >= duration)
                        start_time = randi([start_idx, end_idx - duration + 1]);
                        new_solution(a, start_time:(start_time + duration - 1)) = 1;
                    end
                end
            end
        else
            % 反北東方向跳躍
            new_solution = squeeze(solutions(randi(num_solutions), :, :));
        end
        
        % 計算新解的成本
        new_cost = calculate_cost(appliances, new_solution, TOU_prices);
        
        % 更新解
        if new_cost < current_cost
            solutions(i, :, :) = reshape(new_solution, [1, size(new_solution)]);
        end
    end
    % 記錄當前迭代的最佳成本
    cost_history(iter) = best_cost;
end

% 繪製收斂圖
figure;
plot(1:max_iter, cost_history, 'LineWidth', 2);
xlabel('迭代次數');
ylabel('總電費');
title('FOX 演算法收斂圖');
grid on;

% 儲存最佳解的排程結果
best_schedule = squeeze(best_solution);

% 輸出格式化的最佳解排程
fprintf('最佳解的總電費:\n');
disp(best_cost);

fprintf('最佳解的排程:\n');
unique_appliances = unique({appliances.name});
for a = 1:length(unique_appliances)
    appliance_name = unique_appliances{a};
    fprintf('%s: ', appliance_name);
    schedule_str = '';
    for t = 1:48
        for i = 1:length(appliances)
            if strcmp(appliance_name, appliances(i).name) && best_schedule(i, t) == 1
                start_hour = floor((t-1) / 2);
                start_minute = mod((t-1), 2) * 30;
                end_hour = floor(t / 2);
                end_minute = mod(t, 2) * 30;
                schedule_str = [schedule_str, sprintf('%02d:%02d-%02d:%02d ', start_hour, start_minute, end_hour, end_minute)];
            end
        end
    end
    fprintf('%s\n', schedule_str);
end

% 檢查最佳解是否滿足限制條件
if check_constraints(best_schedule, appliances, max_power)
    disp('最佳解滿足所有限制條件');
else
    disp('最佳解不滿足某些限制條件');
end

% 視覺化最佳解
visualize_schedule(best_schedule, appliances);

% 視覺化結果
function visualize_schedule(schedule, appliances)
    figure;
    hold on;
    unique_appliances = unique({appliances.name});
    for a = 1:length(unique_appliances)
        appliance_name = unique_appliances{a};
        appliance_indices = find(strcmp({appliances.name}, appliance_name));
        y = a * ones(1, 48); % 使用不同的 y 值以確保圖形可視化的簡潔性
        for t = 1:48
            for i = appliance_indices
                if schedule(i, t) == 1
                    start_time = (t-1) * 0.5;
                    end_time = t * 0.5;
                    plot([start_time, end_time], [y(t), y(t)], 'LineWidth', 10);
                end
            end
        end
    end
    xlabel('時間 (小時)');
    ylabel('電器');
    yticks(1:length(unique_appliances));
    yticklabels(unique_appliances);
    title('最佳解的排程');
    grid on;
    hold off;
end

% 計算排程前後的功率消耗
power_before = zeros(1, 48);
power_after = zeros(1, 48);

% 排程前的數據 (根據您提供的表格)
pre_schedule = [
    struct('name', 'Laundry drier', 'start', [9, 21], 'end', [11, 22.5], 'power', 1.26);
    struct('name', 'Electric kettle', 'start', 6, 'end', 6.5, 'power', 1.5);
    struct('name', 'Air conditioner', 'start', [5, 17], 'end', [8, 21], 'power', 1.2);
    struct('name', 'Electric radiator', 'start', 12, 'end', 14.5, 'power', 2);
    struct('name', 'Water pump', 'start', 9, 'end', 13, 'power', 1.8);
    struct('name', 'Electric oven', 'start', 17, 'end', 19, 'power', 1.1);
    struct('name', 'PHEV', 'start', 0, 'end', 3.5, 'power', 1.8);
    struct('name', 'Dish washer', 'start', 21, 'end', 22.5, 'power', 0.73);
    struct('name', 'Rice cooker', 'start', [6, 18], 'end', [7, 19], 'power', 0.8);
    struct('name', 'Washing machine', 'start', 20, 'end', 22, 'power', 0.38);
    struct('name', 'Microwave', 'start', 13, 'end', 14, 'power', 0.9);
    struct('name', 'Toaster', 'start', 6, 'end', 7, 'power', 0.8);
    struct('name', 'Light', 'start', 19, 'end', 24, 'power', 0.3);
    struct('name', 'Refrigerator', 'start', 0, 'end', 24, 'power', 0.03);
    struct('name', 'TV', 'start', 8, 'end', 24, 'power', 0.2);
    struct('name', 'Modem', 'start', 0, 'end', 24, 'power', 0.01);
];

% 計算排程前的功率消耗
for i = 1:length(pre_schedule)
    for j = 1:length(pre_schedule(i).start)
        start_idx = round(pre_schedule(i).start(j) * 2 + 1);
        end_idx = round(pre_schedule(i).end(j) * 2);
        for t = start_idx:end_idx
            power_before(t) = power_before(t) + pre_schedule(i).power;
        end
    end
end

% 計算排程後的功率消耗
for a = 1:length(appliances)
    for t = 1:48
        power_after(t) = power_after(t) + (best_schedule(a, t) * appliances(a).power);
    end
end

% 將每半小時的功率消耗合併為每小時的功率消耗
power_before_hourly = zeros(1, 24);
power_after_hourly = zeros(1, 24);
for t = 1:24
    power_before_hourly(t) = power_before(2*t-1) + power_before(2*t);
    power_after_hourly(t) = power_after(2*t-1) + power_after(2*t);
end

% 繪製排程前的功率消耗圖
figure;
b = bar(0.5:1:23.5, power_before_hourly);
b.EdgeColor = 'none'; % 移除外框顏色
xlabel('Hour');
ylabel('kW');
title('每一時段功率消耗(排程前)');
grid on;

% 繪製排程後的功率消耗圖
figure;
b = bar(0.5:1:23.5, power_after_hourly);
b.EdgeColor = 'none'; % 移除外框顏色
xlabel('Hour');
ylabel('kW');
title('每一時段功率消耗(排程後)');
grid on;

% 計算總電費
total_cost_before = sum(power_before .* TOU_prices * 0.5);
total_cost_after = sum(power_after .* TOU_prices * 0.5);

% 顯示總電費
fprintf('排程前的總電費: %.2f 元\n', total_cost_before);
fprintf('排程後的總電費: %.2f 元\n', total_cost_after);
