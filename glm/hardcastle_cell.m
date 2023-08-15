% Run this function from cell directory to classify the given cell.
% Outputs a txt file containing the classification of the given
% cell, as well as the p-values of all significance tests run for different
% models on the cell.

function hardcastle_cell(tbin_size, fc)
    % PARAMETERS:
    % tbin_size - size of time bin (in seconds) for binning of vmpv data.
    % fc - number of folds for cross-validation in glm_hardcastle.

   save_dir = [num2str(tbin_size*1000), 'ms_', num2str(fc), 'fold'];
   
   if exist([save_dir, '/glm_hardcastle_results.mat'], 'file')
       % Load pre-generated data file
       load([save_dir, '/glm_hardcastle_results.mat'], 'hc_results');
       if (hc_results.tbin_size ~= tbin_size) || (hc_results.num_folds ~= fc)
           % Regenerate data from vmpv object and run LNP model fitting
           vmpv_data = glm_vmpvData(tbin_size);
           hc_results = glm_hardcastle(vmpv_data, fc);
       end
   else
       % Generate data from vmpv object and run LNP model fitting
       vmpv_data = glm_vmpvData(tbin_size);
       hc_results = glm_hardcastle(vmpv_data, fc);
   end
   % Run model forward selection
   selected_model = select_best_model(hc_results);
   
   % Move results into a labelled directory
   if ~exist(save_dir, 'dir')
       mkdir(save_dir);
   end
   movefile('glm_hardcastle_results.mat', save_dir);

   % Cell classification and significance testing, saved as a txt file
   % in the labelled directory
   if exist('hardcastle_class.txt', 'file')
       % Overwrite old text file
       delete('hardcastle_class.txt')
   end
   diary('hardcastle_class.txt')
   disp(['Cell classification: ' selected_model]);
   disp(' ');
   hardcastle_testing(hc_results);
   diary off

   % Generate response plots for classified variables
   glm_hardcastle_plot(hc_results, selected_model);

end