function [out] = swt(IM, light_on_dark)
    % TODO:
    %   * Thresholding connected components
    %   * Try both light on dark, dark on light, and pick best

    % Assume light on dark text unless otherwise specified
    if nargin < 2 || isempty(light_on_dark)
        light_on_dark = 1
    end

    % start workers if necessary
    if matlabpool('size') == 0
        matlabpool open 4
    end

    %% Configuration
    edge_fn = @(img) edge(img, 'canny');

    %% CANNY EDGE DETECTION
    E = edge_fn(IM);
    [h,w] = size(E);
    [R,C] = find(E); % Edge locations

    %% SWT
    [FX,FY] = gradient(IM);
    if ~light_on_dark
        FX = -FX;
        FY = -FY;
    end

    stroke_widths = 255*ones(h,w);
    MSW = floor(sqrt(h^2+w^2));
    vectors_seen = cell(1,h*w);

    % TODO: can this be parallelized?
    v = 1;
    for i=1:length(R)
        % Start at some edge pixel, get its coordinates
        curr_r = R(i);
        curr_c = C(i);

        % Find the gradient vector components at this point
        grad_x = FX(curr_r, curr_c);
        grad_y = FY(curr_r, curr_c);

        % Normalize the gradient vector to length 1
        hyp2 = (grad_x)^2 + (grad_y)^2;
        if (hyp2 == 0) continue; end
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

    stroke_widths(stroke_widths > 150) = 0;

    % Connected components analysis
    'Creating connected graph'
    rows = [];
    cols = [];
    parfor c=1:w
        for r=1:h
            neighbors = [[r+1, c]; [r, c+1]; [r+1, c+1]];
            for nbr_idx = 1:size(neighbors, 1)
                neighbor = neighbors(nbr_idx, :);
                rr = neighbors(1); cc = neighbor(2);

                if (rr > h || cc > w) continue ; end

                val1 = stroke_widths(rr, cc);
                val2 = stroke_widths(r, c);
                if (((val1 / val2) <= 3 && (val2 / val1) <= 3) ...
                    || (val1 == 0 && val2 == 0))
                    idx1 = r + c * h; idx2 = rr + cc * h;
                    rows = [rows (r + (c-1)*h)];
                    cols = [cols (rr + (cc-1)*h)];

                    rows = [rows (rr + (cc-1)*h)];
                    cols = [cols (r + (c-1)*h)];
                end
            end
        end
    end
    vals = ones(1, size(rows, 2));

    'Calculating connected components'
    graph_mat = sparse(rows, cols, vals, h*w, h*w);
    [num_ccs, cc_labels] = graphconncomp(graph_mat);

    counts = histc(cc_labels, 1:num_ccs);
    [~, top_components] = sort(counts, 'descend');
    nr_comp = size(top_components, 2);

    components = zeros(1, h * w);
    colors = jet(nr_comp);
    for i=1:h*w
        components(i) = cc_labels(i);
    end

    figure;
    imagesc(stroke_widths)
    figure;
    imagesc(reshape(components, h, w))
    out = stroke_widths;
end
