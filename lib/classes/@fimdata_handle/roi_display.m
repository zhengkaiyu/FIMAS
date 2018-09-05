function [ status, message ] = roi_display( obj, parameter, fig_handle  )
%plot what parameter from which data to where panel

%% function check
status=false;message='';

try
    current_data=obj.current_data(1);
    data=obj.data(current_data).dataval;
    if ~isempty(data)
        % initialise figure handles if not specified
        if isempty(fig_handle)
            fig_handle=figure(997); % high enough to avoid existing figures
            fig_handle.PANEL_DATA_dt=subplot(4,4,[1,2]);
            fig_handle.PANEL_DATA_gT=subplot(4,4,[13,14]);
            fig_handle.PANEL_DATA_MAP=subplot(4,4,[5,6,9,10]);
            fig_handle.PANEL_RESULT_parameter=subplot(4,4,[3,4]);
            fig_handle.PANEL_RESULT_map=subplot(4,4,[7,8,11,12]);
            fig_handle.PANEL_RESULT_gT=subplot(4,4,[15,16]);
            %notify=false; % reset notify as there will be no suitable output
        end
        
        % get roi
        current_roi=obj.data(current_data).current_roi;
        roi_name=sprintf('%s\n',obj.data(current_data).roi(current_roi).name);
        data_size=obj.data(current_data).datainfo.data_dim;
        
        switch parameter
            case 'display'
                [plotdata,success,message]=obj.roi_calc(current_roi,'trace');
                if success
                    switch obj.data(current_data).datatype
                        case {'DATA_SPC','DATA_IMAGE'}    %nD image data
                            % dt plot
                            if ndims(plotdata{1,1})>2
                                %set T/Z slice options
                                %selected_slice=get(fig_handle.MENU_DATA_Z,'Value');
                                selected_page=get(fig_handle.MENU_DATA_T,'Value');
                                display_data(plotdata{1,1}(:,:,selected_page),fig_handle.PANEL_DATA_dt,'line',plotdata{1,2},plotdata{1,3},[data_size(4)>1,data_size(5)>1],current_roi*current_data);
                                set(fig_handle.PANEL_DATA_dt,'UserData',plotdata{1,1});
                            else
                                display_data(plotdata{1,1},fig_handle.PANEL_DATA_dt,'line',plotdata{1,2},plotdata{1,3},[data_size(4)>1,data_size(5)>1],current_roi);
                            end
                            % gT plot
                            if ndims(plotdata{2,1})>2
                                %set T/Z slice options
                                selected_slice=get(fig_handle.MENU_DATA_Z,'Value');
                                %selected_page=get(fig_handle.MENU_DATA_T,'Value');
                                display_data(plotdata{2,1}(:,selected_slice,:),fig_handle.PANEL_DATA_gT,'line',plotdata{2,2},plotdata{2,3},[data_size(4)>1,data_size(5)>1],current_roi);
                                set(fig_handle.PANEL_DATA_gT,'UserData',plotdata{2,1});
                            else
                                display_data(plotdata{2,1},fig_handle.PANEL_DATA_gT,'line',plotdata{2,2},plotdata{2,3},[data_size(4)>1,data_size(5)>1],current_roi);
                            end
                        case 'RESULT_IMAGE'
                            % dt plot
                            if ndims(plotdata{1,1})>2
                                %set T/Z slice options
                                selected_page=get(fig_handle.MENU_RESULT_T,'Value');
                                display_data(plotdata{1,1}(:,:,selected_page),fig_handle.PANEL_RESULT_param,'line',plotdata{1,2},plotdata{1,3},[data_size(4)>1,data_size(5)>1],current_roi*current_data);
                                set(fig_handle.PANEL_RESULT_param,'UserData',plotdata{1,1});
                            else
                                display_data(plotdata{1,1},fig_handle.PANEL_RESULT_param,'line',plotdata{1,2},plotdata{1,3},[data_size(4)>1,data_size(5)>1],current_roi);
                            end
                            % gT plot
                            if ndims(plotdata{2,1})>2
                                %set T/Z slice options
                                selected_slice=get(fig_handle.MENU_RESULT_Z,'Value');
                                display_data(plotdata{2,1}(:,selected_slice,:),fig_handle.PANEL_RESULT_gT,'line',plotdata{2,2},plotdata{2,3},[data_size(4)>1,data_size(5)>1],current_roi);
                                set(fig_handle.PANEL_RESULT_gT,'UserData',plotdata{2,1});
                            else
                                display_data(plotdata{2,1},fig_handle.PANEL_RESULT_gT,'line',plotdata{2,2},plotdata{2,3},[data_size(4)>1,data_size(5)>1],current_roi);
                            end
                        case 'RESULT_PHASOR_MAP'
                            
                    end
                    message=sprintf('%s trace plotted\n',roi_name);
                    status=true;
                end
            case 'histogram'
                [plotdata,success,message]=obj.roi_calc(current_roi,'histogram');
                if success
                    switch obj.data(current_data).datatype
                        case 'DATA_IMAGE'    %nD image data
                            if numel(plotdata)>2
                                display_data(plotdata{3}, fig_handle.PANEL_aux, 'histmap', {plotdata{1},plotdata{2}}, {'Photon#',plotdata{4}}, [false,false],[]);
                            else
                                display_data(plotdata{2}, fig_handle.PANEL_aux, 'hist', {plotdata{1},[]}, {'Photon#','freq'}, [false,false],current_roi);
                            end
                        case 'DATA_TRACE'
                            display_data(plotdata{2}, fig_handle.PANEL_aux, 'hist', {plotdata{1},[]}, {'Photon#','freq'}, [false,false],current_roi);
                        case 'RESULT_IMAGE'    %nD PARAMTER MAP
                            if numel(plotdata)>2
                                display_data(plotdata{3}, fig_handle.PANEL_aux, 'histmap', {plotdata{1},plotdata{2}}, {'Photon#',plotdata{4}}, [false,false],[]);
                            else
                                display_data(plotdata{2}, fig_handle.PANEL_aux, 'hist', {plotdata{1},[]}, {'Photon#','freq'}, [false,false],current_roi);
                            end
                        case 'RESULT_TRACE'
                            display_data(plotdata{2}, fig_handle.PANEL_aux, 'hist', {plotdata{1},[]}, {'Photon#','freq'}, [false,false],current_roi);
                    end
                    message=sprintf('%s histogram plotted\n',roi_name);
                    status=true;
                end
        end
    else
        message=sprintf('no data to display\n');
    end
catch exception
    % error handling
    message=[exception.message,data2clip(exception.stack)];
    errordlg(sprintf('%s\n',message));
end