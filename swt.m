%% READ IMAGE
IM = im2double(rgb2gray(imread('text.png')));

%% CANNY EDGE DETECTION
E = edge(IM,'canny');

%% SWT
% Assume light text on dark background

[FX,FY] = gradient(IM);
subplot(1,2,1), imagesc(FX);
subplot(1,2,2), imagesc(FY);

[h,w] = size(E);
[R,C] = find(E);
stroke_widths = 255*ones(h,w);
MSW = floor(sqrt(h^2+w^2));
vectors_seen = cell(1,h*w);

v = 1;
for i=1:length(R)
    % Start at some edge pixel, get its coordinates
    curr_r = R(i);
    curr_c = C(i);
    next_r = curr_r;
    next_c = curr_c;

    % Find the gradient vector components at this point
    grad_x = FX(curr_r, curr_c);
    grad_y = FY(curr_r, curr_c);

    % Normalize the gradient vector to length 1
    hyp2 = (grad_x)^2 + (grad_y)^2;
    c = sqrt(1/hyp2);
    grad_x = c*grad_x;
    grad_y = c*grad_y;

    % Walk in direction of gradient vector
    PV_R = zeros(1,MSW);
    PV_C = zeros(1,MSW);

    sw = 0;
    while(1)
        % Get next unit step along gradient
        next_r = curr_r + grad_y;
        next_c = curr_c + grad_x;

        % Round next point to integers to access pixel
        next_r_round = round(next_r);
        next_c_round = round(next_c);

        % Check if next point is valid
        if (next_r_round <= 0 || next_r_round > h) || ...
            (next_c_round <= 0 || next_c_round > w)
            break;
        end

        % If the point is valid, increment stroke width
        sw = sw + 1;

        % Add next point to points visited
        PV_R(1,sw) = next_r_round;
        PV_C(1,sw) = next_c_round;

        % Get gradient at new point
        new_grad_x = FX(next_r_round, next_c_round);
        new_grad_y = FY(next_r_round, next_c_round);

        % Normalize
        hyp2 = (new_grad_x)^2 + (new_grad_y)^2;
        c = sqrt(1/hyp2);
        new_grad_x = new_grad_x * c;
        new_grad_y = new_grad_y * c;

        % End if gradient at new point is in opposite direction
        if(acos(grad_x*-new_grad_x + grad_y*-new_grad_y) < (pi/2))
            break;
        end

        % Set variables for next iteration
        curr_r = next_r;
        curr_c = next_c;
    end

    % Delete trailing zeros from preallocated arrays
    i1 = find(PV_R, 1, 'first');
    i2 = find(PV_R, 1, 'last');
    PV_R = PV_R(i1:i2);
    PV_C = PV_C(i1:i2);

    % Add vector seen to list
    vectors_seen(v) = {{PV_R,PV_C}};
    v = v+1;

    % So now PV_R and PV_C contain all points visited along a gradient
    % We need to replace all these points with the stroke width.

    for a=1:length(PV_R)
        old_stroke = stroke_widths(PV_R(a), PV_C(a));
        stroke_widths(PV_R(a),PV_C(a)) = min(old_stroke, sw);
    end
end

% Remove trailing empty cells
vectors_seen = vectors_seen(~cellfun('isempty', vectors_seen));

% Replace outlier values with median along vector
for j=1:length(vectors_seen)
    % Access vectors visited from cell array
    rows = vectors_seen{j}{1};
    cols = vectors_seen{j}{2};

    % Create array of stroke widths at vector points
    widths = zeros(1,length(rows));
    for k=1:length(rows)
        widths(k) = stroke_widths(rows(k),cols(k));
    end

    % Find median along vector
    med = median(widths);

    % Replace entries larger than median with median
    for k=1:length(rows)
        if(widths(k) > med)
            stroke_widths(rows(k),cols(k)) = med;
        end
    end
end

stroke_widths(stroke_widths > 50) = 0;
figure;
imagesc(stroke_widths)
