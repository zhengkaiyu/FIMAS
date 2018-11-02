function [ status, message ] = data_export( obj, index, filename )
%DATA_EXPORT export selected data from a session
%  only export selected data for future import

%% function complete

status=false;
try
    if isempty(filename)
        [filename,pathname]=uiputfile({'*.edf','exported data file (*.edf)';...
            '*.tiff','TIFF file (*.tiff)';...
            '*.mat','Matlab matrix file (*.mat)'},...
            'Select Exported Data Analysis File',obj.path.export);
        filename=cat(2,pathname,filename);
    end
    [pathname,~,extension]=fileparts(filename);
    if pathname~=0     %if files selected
        switch extension(2:end)
            case 'mat'
                dataitem={obj.data(index).dataval}; %#ok<NASGU>
                s=whos('dataitem');
                if s.bytes<2e9
                    save(filename,'dataitem','-mat','-v6');
                else
                    %to cope with large file size
                    save(filename,'dataitem','-mat','-v7.3');
                end
                %update saved path
                obj.path.export=pathname;
                message=sprintf('data item values %g exported\n',index);
                status=true;
            case 'edf'
                dataitem=obj.data(index);
                % clear handles
                for dataidx=1:numel(dataitem)
                    dataitem(dataidx).datainfo.panel=[];
                    for roiidx=2:numel(dataitem(dataidx).roi)
                        dataitem(dataidx).roi(roiidx).panel=[];
                        dataitem(dataidx).roi(roiidx).handle=[];
                    end
                end
                %to cope with large file size
                save(filename,'dataitem','-mat','-v7.3');
                %update saved path
                obj.path.export=pathname;
                message=sprintf('data item %g exported\n',index);
                status=true;
            case {'tiff','tif','TIFF','TIF'}
                databit=16;
                for dataidx=index
                    dataitem=obj.data(dataidx);
                    dataval=dataitem.dataval;
                    maxval=max(dataval(:));
                    dataval=uint16(dataval/maxval*2^databit);
                    dataval=permute(dataval,[2,3,1,4,5]);
                    nch=size(dataval,3);
                    nslice=size(dataval,4);
                    nframe=size(dataval,5);
                    nimg=nch*nslice*nframe;
                    % construct tiff file
                    tifobj = Tiff(regexprep(filename,'\.',cat(2,'_',num2str(dataidx),'.')),'w');
                    tagstruct.ImageLength=size(dataval,1);
                    tagstruct.ImageWidth=size(dataval,2);
                    tagstruct.ResolutionUnit=Tiff.ResolutionUnit.Centimeter;
                    if ~isempty(dataitem.datainfo.dX)
                        tagstruct.XResolution=1/(dataitem.datainfo.dX*1e-4);
                    end
                    if ~isempty(dataitem.datainfo.dY)
                        tagstruct.YResolution=1/(dataitem.datainfo.dY*1e-4);
                    end
                    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;%value=1
                    tagstruct.Compression=Tiff.Compression.None;
                    tagstruct.BitsPerSample = databit;
                    tagstruct.SamplesPerPixel = 1;
                    tagstruct.SubFileType=Tiff.SubFileType.ReducedImage;
                    tagstruct.SampleFormat=Tiff.SampleFormat.UInt;
                    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                    tagstruct.RowsPerStrip = ceil(8*1024/(tagstruct.ImageWidth*(tagstruct.BitsPerSample/8)*nimg));
                    tagstruct.Orientation=Tiff.Orientation.TopLeft;
                    tagstruct.Software = 'MATLAB';
                    tagstruct.Copyright = 'FIMAS';
                    tagstruct.ImageDescription=sprintf('%s\nimages=%g\nchannels=%g\nslices=%g\nframes=%g\nhyperstack=%s\nmode=%s\nloop=%s\nmin=%g\nmax=%g\n',...
                        dataitem.datainfo.note,...
                        nimg,nch,nslice,nframe,...
                        'true','grayscale','false',...
                        0,maxval);
                    %xyczt default hyperstack in imagej
                    for frameidx=1:nframe
                        for sliceidx=1:nslice
                            for chidx=1:nch
                                tifobj.setTag(tagstruct);
                                tifobj.write(dataval(:,:,chidx,sliceidx,frameidx));
                                if (chidx*sliceidx*frameidx) ~= nimg
                                    tifobj.writeDirectory();
                                end
                            end
                        end
                    end
                    % close tiff file construct
                    tifobj.close();
                end
                % update saved path
                obj.path.export=pathname;
                message=sprintf('data item %g exported\n',index);
                status=true;
        end
    else
        %action cancelled
        message=sprintf('%s\n','file export action cancelled');
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end