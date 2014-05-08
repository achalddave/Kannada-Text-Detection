function [swt_im, ccomps] = swt(IM, light_on_dark)
    % TODO:
    %   * Thresholding connected components
    %   * Try both light on dark, dark on light, and pick best

    % Assume light on dark text unless otherwise specified
    if nargin < 2 || isempty(light_on_dark)
        light_on_dark = 1;
    end

    % start workers if necessary
    if matlabpool('size') == 0
        matlabpool open 8
    end

    %% Configuration
    edge_fn = @(img) edge(img, 'canny');
    IM = imfilter(IM, fspecial('gaussian', 5));

    %% CANNY EDGE DETECTION
    E = edge_fn(IM);
    figure;
    imshow(E);
    [h,w] = size(E);
    [R,C] = find(E); % Edge locations

    %% SWT
    [FX,FY] = gradient(IM);
    FX = imfilter(FX, fspecial('gaussian', 3));
    FY = imfilter(FY, fspecial('gaussian', 3));

    if ~light_on_dark
        FX = -FX;
        FY = -FY;
    end

    stroke_widths = -1.0*ones(h,w);
    MSW = floor(sqrt(h^2+w^2));
    vectors_seen = cell(1,h*w);

    % TODO: can this be parallelized?
    'Extracting raw stroke widths'
    v = 1;
    jump = 0.05;
    for i=1:length(R)
        % Start at some edge pixel, get its coordinates
        % *_round = round values
        start_r = R(i) + 0.5;
        start_c = C(i) + 0.5;

        curr_r = start_r;
        curr_c = start_c;
        curr_r_round = R(i);
        curr_c_round = C(i);

        % Find the gradient vector components at this point
        grad_x = FX(curr_r_round, curr_c_round);
        grad_y = FY(curr_r_round, curr_c_round);

        % Normalize the gradient vector to length 1
        hyp2 = (grad_x)^2 + (grad_y)^2;
        if (hyp2 == 0) ; continue; end
        c = sqrt(1/hyp2);
        grad_x = c*grad_x;
        grad_y = c*grad_y;

        % Walk in direction of gradient vector
        PV_R = zeros(1,MSW);
        PV_C = zeros(1,MSW);

        point_idx = 0;
        while(1)
            % Get next unit step along gradient
            curr_r = curr_r + jump*grad_y;
            curr_c = curr_c + jump*grad_x;

            % Round next point to integers to access pixel
            next_r_round = round(curr_r);
            next_c_round = round(curr_c);

            if (next_r_round == curr_r_round && ...
                next_c_round == curr_c_round)
                continue
            end

            curr_r_round = next_r_round;
            curr_c_round = next_c_round;

            % Check if next point is valid
            if (curr_r_round <= 0 || curr_r_round > h) || ...
                (curr_c_round <= 0 || curr_c_round > w)
                break;
            end

            % If the point is valid, increment stroke width
            point_idx = point_idx + 1;

            % Add next point to points visited
            PV_R(1,point_idx) = curr_r_round;
            PV_C(1,point_idx) = curr_c_round;

            if (E(curr_r_round, curr_c_round) > 0)
                % Get gradient at new point
                new_grad_x = FX(curr_r_round, curr_c_round);
                new_grad_y = FY(curr_r_round, curr_c_round);

                % Normalize
                hyp2 = (new_grad_x)^2 + (new_grad_y)^2;
                c = sqrt(1/hyp2);
                new_grad_x = new_grad_x * c;
                new_grad_y = new_grad_y * c;

                % End if gradient at new point is in opposite direction
                if(acos(grad_x*-new_grad_x + grad_y*-new_grad_y) < (pi/2))
                    break;
                end
            end
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
            if (old_stroke == -1) ; old_stroke = Inf ; end

            sw = sqrt((start_r - curr_r)^2 + (start_c - curr_c)^2);

            stroke_widths(PV_R(a),PV_C(a)) = min(old_stroke, sw);
        end
    end

    % Remove trailing empty cells
    vectors_seen = vectors_seen(~cellfun('isempty', vectors_seen));

    % Replace outlier values with median along vector
    'Replacing outliers with medians'
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

    % raw_idx(r, c) = r + (c - 1)*h
    %   i.e. column major index
    raw_idx = reshape(1:h*w, h, w);
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
                    rows = [rows raw_idx(r, c)];
                    cols = [cols raw_idx(rr, cc)];

                    rows = [rows raw_idx(rr, cc)];
                    cols = [cols raw_idx(r, c)];
                end
            end
        end
    end
    vals = ones(1, size(rows, 2));

    'Calculating connected components'
    graph_mat = sparse(rows, cols, vals, h*w, h*w);
    [num_ccs, cc_labels] = graphconncomp(graph_mat);

    component_vals = cell([1, num_ccs]);

    figure;
    imagesc(stroke_widths)

    ccomps = reshape(cc_labels, h, w);

    figure;
    imagesc(ccomps)

    swt_im = stroke_widths;
end
