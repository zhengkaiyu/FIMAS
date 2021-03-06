function [ roiinfo ] = femtonics_scanline( info )
%FEMTONICS_SCANLINE Summary of this function goes here
%   point scan works
%   spiral scan
%   line scan
%   square scan
%   composite scan

if strcmp(info.HeightName,'t')
    % check height is time
    switch info.HeightUnit
        case 's'
            timescaler=1;
        case 'ms'
            timescaler=1e-3;
        case 'us'
            timescaler=1e-6;
        otherwise
            errordlg(sprintf('add time unit %s to function',info.HeightUnit));
    end
    % info_Protocol->protocol structure->inputcurve
    
    %info.LineSeq->x,y
    %info.Linfo->find correct lines
    % info.ScanLine-> composite type->ODDArray
    ntimepts=info.Height;
    pixeltime=info.DwellTime;
    dt=info.HeightStep;
    Zpos=info.DevicePosition.ObjectiveArm;
    pixeldt=info.LineSeq.x;
    pixel=info.LineSeq.y;
    patternorder=info.LineSeq.y(2,:);
    npattern=numel(patternorder)-1;
    % loop through patterns, last pattern the reset
    for patternidx=1:npattern
        
        switch info.ScanLine.Type
            case 'composite'
                % get scanline info fro oddarray
                scandata=info.ScanLine.ODDarray(patternidx);
                % get lineID so we can look into Linfo
                lineid=scandata.lineID;
                
                lineinfo=info.info_Linfo.lines(lineid);
                % line1 set point, line2 upsampled points
                % line1 can have multiple lines
                lineseqnum=info.ScanLine.Data1(patternidx);
                linepixelnum=info.ScanLine.Data2(patternidx);%pixel start num
                linedelaynum=info.ScanLine.roi(patternidx);%roi deelay
                linetype=lineinfo.type;
                pixeltime=lineinfo.Tpixwidth*timescaler;
                totalduration=pixeltime*lineinfo.pixnum;
                lineduration=pixeltime*lineinfo.Tpixnum;
                framenum=lineinfo.pixnum/lineinfo.Tpixnum;
                
                dx=lineinfo.pixwidth;
                dt=lineinfo.apptime*timescaler;
                % number of dwell pixel to image pixel
                nptaverage=lineinfo.scanspeed;
                pattern_startpixel=info.ScanLine.Data2(patternidx)+1;
                pattern_endpixel=info.ScanLine.Data2(patternidx+1);
                pattern_startpixel=ceil(pattern_startpixel/nptaverage);
                pattern_endpixel=ceil(pattern_endpixel/nptaverage);
                
                scan_Tsize=size(scandata.Data2,2)-1;
                scan_Lsize=floor(size(scandata.Data1,2)/nptaverage);
                % roi within scanline
                roipixgroup=lineinfo.line2RoI;
                roipixpos=lineinfo.line1;
                nROI=numel(roipixpos);
                % roi time per line repeat
                roitimeinterval=pixeldt(2)*roipixgroup*timescaler;
                roistarttime=mean(roitimeinterval);
                % pixel group per line
                roixbound=[ceil(roipixgroup(1,:)/nptaverage);floor(roipixgroup(2,:)/nptaverage)];
                [i,j]=ind2sub([scan_Lsize,scan_Tsize],[pattern_startpixel:1:pattern_endpixel]);
                for roiidx=1:nROI
                    % roi{k}.frame
                    % roi{k}.frame(
                    % size(lineinfo.line1{roiidx})
                    roixinterval=roixbound(1,roiidx):1:roixbound(2,roiidx);
                    
                    roipos=roixinterval*dx;
                    roitime=roistarttime(roiidx)*dt;
                    % pass back argument assigned
                    roiinfo.roixint{patternidx,roiidx}=roixinterval;
                    roiinfo.roipos{patternidx,roiidx}=roipos;
                    roiinfo.roitint{patternidx,roiidx}=roitimeinterval(:,roiidx);
                    roiinfo.roitime{patternidx,roiidx}=roitime;
                    roiinfo.roitime{patternidx,roiidx}=[pattern_startpixel,pattern_endpixel];
                end
            case 'square'
                ntimepts=info.Height;
                % get scanline info
                scandata=info.ScanLine;
                % get lineID so we can look into Linfo
                if isfield(scandata,'lineID')
                    lineid=scandata.lineID;
                else
                    lineid=patternorder(patternidx);
                end
                lineinfo=info.info_Linfo.lines(lineid);
                % pixel grouping, lineinfo.line2RoI and scandata.roi same
                roipixgroup=lineinfo.line2RoI;
                % number of dwell pixel to image pixel
                nptaverage=lineinfo.scanspeed;
                % pixel group per line in real data
                roixbound=[ceil(roipixgroup(1,:)/nptaverage);floor(roipixgroup(2,:)/nptaverage)];
                % scan pixel position to each roi
                roipixpos=lineinfo.line1;
                % roi time per line repeat
                dt=lineinfo.apptime*timescaler;
                % work out dwell time in each ROI
                roitimeinterval=pixeldt(2)*roipixgroup*timescaler;
                % take ROI start time as the average of ROI dwell time
                roistarttime=mean(roitimeinterval);
                % get ROI end time with correct dt
                roiendtime=(ntimepts-1)*dt+roistarttime;
                % number of ROI in this pattern
                nROI=numel(roipixpos);
                for roiidx=1:nROI
                    % get roi pixel interval for xy pos
                    roixinterval=roixbound(1,roiidx):1:roixbound(2,roiidx);
                    switch lineinfo.type
                        % square scan
                        
                        case 'Raster'
                            
                        case 'Line'
                            % line/point/spiral scan
                            % get roi position vector
                            switch size(roipixpos{roiidx},2)
                                case 1
                                    % point scan use point dwell time
                                    pixeltime=info.DwellTime;
                                    roipos=linspace(0,pixeltime*(numel(roixinterval)-1),numel(roixinterval));
                                case 2
                                    
                                    
                                otherwise
                                    roipos=roipixpos{roiidx};
                            end
                        case 'Square'
                            
                    end
                    % guess the shape of the roi
                    divpos=diff(roipos,2,2);
                    if isempty(divpos)
                        % vector of 3xn where n<3
                        roiinfo.roitype{patternidx,roiidx}='square';
                    elseif sum(sign(divpos(2,:)))==0
                        roiinfo.roitype{patternidx,roiidx}='spiral';
                    else
                        roiinfo.roitype{patternidx,roiidx}='square';
                    end
                    % get roi time vector
                    roitime=roistarttime(roiidx):dt:roiendtime(roiidx);
                    % get roi time interval
                    roitinterval=1:1:numel(roitime);
                    % pass back argument assigned
                    roiinfo.roixint{patternidx,roiidx}=roixinterval;
                    roiinfo.roipos{patternidx,roiidx}=roipos;
                    roiinfo.roitint{patternidx,roiidx}=roitinterval;
                    roiinfo.roitime{patternidx,roiidx}=roitime;
                end
        end
    end
else
    errordlg(sprintf('Height is in %s not in time',info.HeightName));
end