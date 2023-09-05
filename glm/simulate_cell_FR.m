function [lambda, cell_params] = simulate_cell_FR(behav_state)
    % Inputs:
    % behav_state - n x 3 vector of current behavioural state,
    % in the format of [ place_bin, hd_bin, view_bin ]
    %
    % Outputs:
    % lambda - simulated firing rate (in Hz) of the cell
    
    
    %%% Specify cell parameters here %%%
    
    % Available cell types:
    % 'place', 'headdirection', 'spatialview', 'ph', 'pv', 'hv', 'phv' 
    cell_type = 'pv';
    active_firing_rate = 5;
    background_firing_rate = 0.5;
    
    % place
    place_centers = [820]; % bin number
    place_widths = [4]; % in terms of number of bins
    place_contribution = 1; % contribution coefficient for mixed selective response
        
    % headdirection
    hd_centers = [1]; % bin number
    hd_widths = [2]; % in terms of number of bins
    hd_contribution = 1; % contribution coefficient for mixed selective response
    
    % view
    view_centers = [5050, 4898]; % bin number
    view_widths = [2, 2]; % in terms of number of bins
    view_contribution = 1; % contribution coefficient for mixed selective response
    
       
    %%% Cell simulation %%%
    
    % Format of params:
    % params(1) - A, active firing rate
    % params(2) - B, background firing rate
    % params(3) - center_bin, bin number of field center
    % params(4) - s, gaussian width of field (in bins)
    
    % pack cell params
    place_params = { active_firing_rate, background_firing_rate, place_centers, place_widths };
    hd_params = { active_firing_rate, background_firing_rate, hd_centers, hd_widths };
    view_params = { active_firing_rate, background_firing_rate, view_centers, view_widths };
    
    % unpack behavioural state
    place_bin = behav_state(:,1); hd_bin = behav_state(:,2); view_bin = behav_state(:,3);
    n = size(behav_state, 1);
    
    % simulate firing rate
    lambda = zeros(n,1);
    for i = 1:n
        switch cell_type
            case 'place'
                lambda(i) = place_firing_rate(place_bin(i), place_params);

            case 'headdirection'
                lambda(i) = hd_firing_rate(hd_bin(i), hd_params);

            case 'spatialview'
                lambda(i) = view_firing_rate(view_bin(i), view_params);

            case 'ph'
                lambda(i) = place_contribution * place_firing_rate(place_bin(i), place_params)...
                    + hd_contribution * hd_firing_rate(hd_bin(i), hd_params);

            case 'pv'
                lambda(i) = place_contribution * place_firing_rate(place_bin(i), place_params)...
                    + view_contribution * view_firing_rate(view_bin(i), view_params);

            case 'hv'
                lambda(i) = hd_contribution * hd_firing_rate(hd_bin(i), hd_params)...
                    + view_contribution * view_firing_rate(view_bin(i), view_params);

            case 'phv'
                lambda(i) = place_contribution * place_firing_rate(place_bin(i), place_params)...
                    + hd_contribution * hd_firing_rate(hd_bin(i), hd_params)...
                    + view_contribution * view_firing_rate(view_bin(i), view_params); 
        end
    end
    
    cell_params = struct;
    
    cell_params.cell_type = cell_type;
    cell_params.var_contributions = [place_contribution, hd_contribution, view_contribution];
    
    cell_params.place_params = place_params;
    cell_params.hd_params = hd_params;
    cell_params.view_params = view_params;
    
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Helper functions for cell firing rate simulation %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Place %%%
function lambda = place_firing_rate(bin_num, params)
    % Parameters of the simulated place field
    A = params{1}; % active firing rate
    B = params{2}; % background firing rate
    center_bins = params{3}; % centre of place field (in bins)
    widths = params{4}; % gaussian width of place field (in bins)
    
    % Return background firing rate if invalid bin number
    if (isnan(bin_num) || bin_num < 1 || bin_num > 1600)
        lambda = B;
        return
    end
    
    [x, y] = place_bin_to_coords(bin_num);
    r_s_ratios = nan(length(center_bins), 1);
    for i = 1:length(center_bins)
        center_bin = center_bins(i); s = widths(i);
        % Convert bin numbers to x, y coords, and calculate distance from field
        % center
        [x0, y0] = place_bin_to_coords(center_bin);
        r = sqrt((x - x0)^2 + (y - y0)^2);
        s = s * 0.625;
        r_s_ratios(i) = r / s;
    end
    
    % Compute firing rate
    r_s = nanmin(r_s_ratios);
    if isnan(r_s)
        lambda = B;
    else
        lambda = (A - B) * exp(-0.5 * r_s^2) + B;
    end
end

function [x, y] = place_bin_to_coords(bin_num)
    h = mod(bin_num - 1, 40); v = floor((bin_num - 1) / 40);
    x = -12.1875 + 0.625 * h; y = -12.1875 + 0.625 * v;
end



%%% Head direction %%%
function lambda = hd_firing_rate(bin_num, params)
    % Parameters of the simulated headdirection field
    A = params{1}; % active firing rate
    B = params{2}; % background firing rate
    center_bins = params{3}; % centre of hd field (in bins)
    widths = params{4}; % gaussian width of hd field (in bins)
    
    % Return background firing rate if invalid bin number
    if (isnan(bin_num) || bin_num < 1 || bin_num > 60)
        lambda = B;
        return
    end
    
    r_s_ratios = nan(length(center_bins), 1);
    for i = 1:length(center_bins)
        center_bin = center_bins(i); s = widths(i);
        % Calculate distance (with wraparound) from field center
        r_abs = abs(bin_num - center_bin);
        r = min(r_abs, 60 - r_abs);
        r_s_ratios(i) = r / s;
    end
    
    % Compute firing rate
    r_s = nanmin(r_s_ratios);
    if isnan(r_s)
        lambda = B;
    else
        lambda = (A - B) * exp(-0.5 * r_s^2) + B;
    end
end



%%% View %%%
function lambda = view_firing_rate(bin_num, params)
    % Parameters of the simulated view field
    A = params{1}; % active firing rate
    B = params{2}; % background firing rate
    center_bins = params{3}; % centre of view field (in bins)
    widths = params{4}; % gaussian width of view field (in bins)
    
    % Return background firing rate if invalid bin number
    if (isnan(bin_num) || bin_num < 3 || bin_num > 5122)
        lambda = B;
        return
    end
    
    [x, y, z] = view_bin_to_coords(bin_num);
    r_s_ratios = nan(length(center_bins), 1);
    for i = 1:length(center_bins)
        center_bin = center_bins(i); s = widths(i);
        % Convert bin numbers to x, y, z coords
        [x0, y0, z0] = view_bin_to_coords(center_bin);
        s = s * 0.625; % using place field bin size
    
        % Calculate distance from field center
        % check if bin is on same surface or adjacent surface to field center
        num_surfaces_betw = view_surface_adjacency(bin_num, center_bin);
        if (num_surfaces_betw == 0)
            % same surface, so just use 3d euclidean distance
            r = sqrt((x - x0)^2 + (y - y0)^2 + (z - z0)^2);
        elseif (num_surfaces_betw == 1)
            % adjacent surface, so calculate 3d euclidean distance and project onto surfaces
            r_euclidean = [(x - x0), (y - y0), (z - z0)];
            norm1 = get_surface_norm(bin_num); norm2 = get_surface_norm(center_bin);
            r_proj1 = r_euclidean - dot(r_euclidean, norm1) * norm1; % no need to divide by squared norm of the surface
            r_proj2 = r_euclidean - dot(r_euclidean, norm2) * norm2; % normal vector since it is already a unit vector
            r = (norm(r_proj1) + norm(r_proj2)) / 2;
        else
            % neither, so set to NaN
            r = NaN;
        end
        r_s_ratios(i) = r / s;
    end
    
    % Compute firing rate
    r_s = nanmin(r_s_ratios);
    if isnan(r_s)
        lambda = B;
    else
        lambda = (A - B) * exp(-0.5 * r_s^2) + B;
    end
end


function dist = view_surface_adjacency(bin1, bin2)
    % Returns number of surfaces between two given view bins
    surf1 = get_view_surface(bin1); surf2 = get_view_surface(bin2);
    adjacency_list = { 3:22, 3:6, ...
        [1 2 4 6], [1 2 3 5], [1 2 4 6], [1 2 3 5], ...
        [1 8 10], [1 7 9], [1 8 10], [1 7 9], ...
        [1 12 14], [1 11 13], [1 12 14], [1 11 13], ...
        [1 16 18], [1 15 17], [1 16 18], [1 15 17], ...
        [1 20 22], [1 19 21], [1 20 22], [1 19 21]};
    if (surf1 == surf2)
        dist = 0;
    else
        dist = bfs(adjacency_list, surf1, surf2);   
    end
end


function norm = get_surface_norm(bin_num)
    surface_norm = [ 0 0 1; 0 0 -1; ...
        1 0 0; 0 -1 0; -1 0 0 ; 0 1 0; ...
        -1 0 0; 0 1 0; 1 0 0; 0 -1 0; ...
        -1 0 0; 0 1 0; 1 0 0; 0 -1 0; ...
        -1 0 0; 0 1 0; 1 0 0; 0 -1 0; ...
        -1 0 0; 0 1 0; 1 0 0; 0 -1 0 ];
    norm = surface_norm(get_view_surface(bin_num),:);
end


function surf_num = get_view_surface(bin_num)
    %%% Return format %%%
    % floor: 1, ceiling: 2
    % W wall: 3, N wall: 4, E wall: 5, S wall: 6
    % SE pillar, W face: 7, N face: 8, E face: 9, S face: 10
    % SW pillar, W face: 11, N face: 12, E face: 13, S face: 14
    % NE pillar, W face: 15, N face: 16, E face: 17, S face: 18
    % NW pillar, W face: 19, N face: 20, E face: 21, S face: 22

    % View bin ranges for floor/ceiling/walls/pillars
    % floor = 3:1602;
    % ceiling = 1603:3202;
    
    % walls = 3203:4482;
    wall_W = [3203:3242; 3363:3402; 3523:3562; 3683:3722; ...
              3843:3882; 4003:4042; 4163:4202; 4323:4362];
    wall_N = [3243:3282; 3403:3442; 3563:3602; 3723:3762; ...
              3883:3922; 4043:4082; 4203:4242; 4363:4402];
    wall_E = [3283:3322; 3443:3482; 3603:3642; 3763:3802; ...
              3923:3962; 4083:4122; 4243:4282; 4403:4442];
    wall_S = [3323:3362; 3483:3522; 3643:3682; 3803:3842; ...
              3963:4002; 4123:4162; 4283:4322; 4443:4482];
    walls = cat(3, wall_W, wall_N, wall_E, wall_S);
    
    % pillar_SE = 4483:4642;
    pillar_SE_w = [4483:4490; 4515:4522; 4547:4554; 4579:4586; 4611:4618];
    pillar_SE_n = [4491:4498; 4523:4530; 4555:4562; 4587:4594; 4619:4626];
    pillar_SE_e = [4499:4506; 4531:4538; 4563:4570; 4595:4602; 4627:4634];
    pillar_SE_s = [4507:4514; 4539:4546; 4571:4578; 4603:4610; 4635:4642];
    pillar_SE = cat(3, pillar_SE_w, pillar_SE_n, pillar_SE_e, pillar_SE_s);
    
    % pillar_SW = 4643:4802;
    pillar_SW_w = [4643:4650; 4675:4682; 4707:4714; 4739:4746; 4771:4778];
    pillar_SW_n = [4651:4658; 4683:4690; 4715:4722; 4747:4754; 4779:4786];
    pillar_SW_e = [4659:4666; 4691:4698; 4723:4730; 4755:4762; 4787:4794];
    pillar_SW_s = [4667:4674; 4699:4706; 4731:4738; 4763:4770; 4795:4802];
    pillar_SW = cat(3, pillar_SW_w, pillar_SW_n, pillar_SW_e, pillar_SW_s);
    
    % pillar_NE = 4803:4962
    pillar_NE_w = [4803:4810; 4835:4842; 4867:4874; 4899:4906; 4931:4938];
    pillar_NE_n = [4811:4818; 4843:4850; 4875:4882; 4907:4914; 4939:4946];
    pillar_NE_e = [4819:4826; 4851:4858; 4883:4890; 4915:4922; 4947:4954];
    pillar_NE_s = [4827:4834; 4859:4866; 4891:4898; 4923:4930; 4955:4962];
    pillar_NE = cat(3, pillar_NE_w, pillar_NE_n, pillar_NE_e, pillar_NE_s);
    
    % pillar_NW = 4963:5122;
    pillar_NW_w = [4963:4970; 4995:5002; 5027:5034; 5059:5066; 5091:5098];
    pillar_NW_n = [4971:4978; 5003:5010; 5035:5042; 5067:5074; 5099:5106];
    pillar_NW_e = [4979:4986; 5011:5018; 5043:5050; 5075:5082; 5107:5114];
    pillar_NW_s = [4987:4994; 5019:5026; 5051:5058; 5083:5090; 5115:5122];
    pillar_NW = cat(3, pillar_NW_w, pillar_NW_n, pillar_NW_e, pillar_NW_s);
    
    % check if the bin is floor, ceiling, wall or pillar
    if (bin_num < 3 || bin_num > 5122) % out of range
        surf_num = NaN;
    
    elseif (bin_num < 1603) % floor
        surf_num = 1;
        
    elseif (bin_num < 3203) % ceiling
        surf_num = 2;
        
    elseif (bin_num < 4483) % walls
        [h, l, wall_num] = ind2sub(size(walls), find(walls == bin_num));
        surf_num = wall_num + 2;
        
    else % pillars
        if (bin_num < 4643) % SE pillar
            pillar = pillar_SE;
            pillar_faces = 7:10;
        elseif (bin_num < 4803) % SW pillar
            pillar = pillar_SW;
            pillar_faces = 11:14;
        elseif (bin_num < 4963) % NE pillar
            pillar = pillar_NE;
            pillar_faces = 15:18;
        else % NW pillar
            pillar = pillar_NW;
            pillar_faces = 19:22;
        end
        [h, l, face_num] = ind2sub(size(pillar), find(pillar == bin_num));
        surf_num = pillar_faces(face_num);
    end
end


function [x, y, z] = view_bin_to_coords(bin_num)
    % View bin ranges for floor/ceiling/walls/pillars
    % floor = 3:1602;
    % ceiling = 1603:3202;
    
    % walls = 3203:4482;
    wall_W = [3203:3242; 3363:3402; 3523:3562; 3683:3722; ...
              3843:3882; 4003:4042; 4163:4202; 4323:4362];
    wall_N = [3243:3282; 3403:3442; 3563:3602; 3723:3762; ...
              3883:3922; 4043:4082; 4203:4242; 4363:4402];
    wall_E = [3283:3322; 3443:3482; 3603:3642; 3763:3802; ...
              3923:3962; 4083:4122; 4243:4282; 4403:4442];
    wall_S = [3323:3362; 3483:3522; 3643:3682; 3803:3842; ...
              3963:4002; 4123:4162; 4283:4322; 4443:4482];
    walls = cat(3, wall_W, wall_N, wall_E, wall_S);
    
    % pillar_SE = 4483:4642;
    pillar_SE_w = [4483:4490; 4515:4522; 4547:4554; 4579:4586; 4611:4618];
    pillar_SE_n = [4491:4498; 4523:4530; 4555:4562; 4587:4594; 4619:4626];
    pillar_SE_e = [4499:4506; 4531:4538; 4563:4570; 4595:4602; 4627:4634];
    pillar_SE_s = [4507:4514; 4539:4546; 4571:4578; 4603:4610; 4635:4642];
    pillar_SE = cat(3, pillar_SE_w, pillar_SE_n, pillar_SE_e, pillar_SE_s);
    
    % pillar_SW = 4643:4802;
    pillar_SW_w = [4643:4650; 4675:4682; 4707:4714; 4739:4746; 4771:4778];
    pillar_SW_n = [4651:4658; 4683:4690; 4715:4722; 4747:4754; 4779:4786];
    pillar_SW_e = [4659:4666; 4691:4698; 4723:4730; 4755:4762; 4787:4794];
    pillar_SW_s = [4667:4674; 4699:4706; 4731:4738; 4763:4770; 4795:4802];
    pillar_SW = cat(3, pillar_SW_w, pillar_SW_n, pillar_SW_e, pillar_SW_s);
    
    % pillar_NE = 4803:4962
    pillar_NE_w = [4803:4810; 4835:4842; 4867:4874; 4899:4906; 4931:4938];
    pillar_NE_n = [4811:4818; 4843:4850; 4875:4882; 4907:4914; 4939:4946];
    pillar_NE_e = [4819:4826; 4851:4858; 4883:4890; 4915:4922; 4947:4954];
    pillar_NE_s = [4827:4834; 4859:4866; 4891:4898; 4923:4930; 4955:4962];
    pillar_NE = cat(3, pillar_NE_w, pillar_NE_n, pillar_NE_e, pillar_NE_s);
    
    % pillar_NW = 4963:5122;
    pillar_NW_w = [4963:4970; 4995:5002; 5027:5034; 5059:5066; 5091:5098];
    pillar_NW_n = [4971:4978; 5003:5010; 5035:5042; 5067:5074; 5099:5106];
    pillar_NW_e = [4979:4986; 5011:5018; 5043:5050; 5075:5082; 5107:5114];
    pillar_NW_s = [4987:4994; 5019:5026; 5051:5058; 5083:5090; 5115:5122];
    pillar_NW = cat(3, pillar_NW_w, pillar_NW_n, pillar_NW_e, pillar_NW_s);
    
    % check if the bin is floor, ceiling, wall or pillar
    if (bin_num < 3 || bin_num > 5122) % out of range
        x = NaN; y = NaN; z = NaN;
        
    elseif (bin_num < 1603) % floor
        [x, y] = place_bin_to_coords(bin_num - 2);
        z = 0;
        
    elseif (bin_num < 3203) % ceiling
        [x, y] = place_bin_to_coords(bin_num - 1602);
        z = 8;
        
    elseif (bin_num < 4483) % walls
        [h, l, wall_num] = ind2sub(size(walls), find(walls == bin_num));
        switch wall_num
            case 1 % W wall
                x = -12.5;
                y = -12.1875 + 0.625 * (l - 1);
            case 2 % N wall
                x = -12.1875 + 0.625 * (l - 1);
                y = 12.5;
            case 3 % E wall
                x = 12.5;
                y = 12.1875 - 0.625 * (l - 1);
            case 4 % S wall
                x = 12.1875 - 0.625 * (l - 1);
                y = -12.5;
        end
        z = h - 0.5;
        
    else % pillars
        if (bin_num < 4643) % SE pillar
            pillar = pillar_SE;
            x0 = 2.5; y0 = -7.5;
        elseif (bin_num < 4803) % SW pillar
            pillar = pillar_SW;
            x0 = -7.5; y0 = -7.5;
        elseif (bin_num < 4963) % NE pillar
            pillar = pillar_NE;
            x0 = 2.5; y0 = 2.5;
        else % NW pillar
            pillar = pillar_NW;
            x0 = -7.5; y0 = 2.5;
        end
        
        [h, l, face_num] = ind2sub(size(pillar), find(pillar == bin_num));
        switch face_num
            case 1 % W face
                x = x0;
                y = y0 + 0.625 * (l - 0.5);
            case 2 % N face
                x = x0 + 0.625 * (l - 0.5);
                y = y0 + 5;
            case 3 % E face
                x = x0 + 5;
                y = y0 + 5 - 0.625 * (l - 0.5);
            case 4 % S face
                x = x0 + 5 - 0.625 * (l - 0.5);
                y = y0;
        end
        z = h - 0.5;
 
    end
end
